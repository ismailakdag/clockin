import { payload, registration, storageKey, tokenFrom } from './activity.mjs';

const response = (status, error) => new Response(error ? JSON.stringify({ error }) : null,
  { status, headers: { 'Cache-Control': 'no-store', 'Content-Type': 'application/json' } });

export async function handle(request, { store, send, now = Date.now() / 1000 }) {
  if (!['PUT', 'DELETE'].includes(request.method)) return response(405, 'Method not allowed');
  const token = tokenFrom(request);
  if (!token) return response(401, 'Missing activity credential');
  const key = `activities/${storageKey(token)}`;
  if (request.method === 'DELETE') {
    // Keep a tombstone so a delayed registration cannot restart a stopped job.
    const previous = await store.get(key, { type: 'json' });
    if (previous) await store.setJSON(key, { stopped: true, expiresAt: previous.expiresAt });
    return response(204);
  }
  if (Number(request.headers.get('content-length') || 0) > 4096) return response(413, 'Activity is too large');
  let body, record;
  try {
    const reader = request.body?.getReader();
    if (!reader) return response(400, 'Missing activity');
    let bytes = 0; const chunks = [];
    while (true) {
      const { value, done } = await reader.read();
      if (done) break;
      bytes += value.byteLength;
      if (bytes > 4096) { await reader.cancel(); return response(413, 'Activity is too large'); }
      chunks.push(Buffer.from(value));
    }
    body = JSON.parse(Buffer.concat(chunks).toString('utf8'));
    record = registration(body, now);
  } catch { return response(400, 'Invalid activity'); }
  let previous = await store.get(key, { type: 'json' });
  if (previous?.pending && previous.expiresAt <= now) { await store.delete(key); previous = null; }
  if (previous?.pending) return response(503, 'Registration pending');
  if (previous?.stopped) return response(410, 'Activity ended');
  if (previous) {
    return previous.protocol === 2 && previous.environment === record.environment
      ? response(204) : response(409, 'Activity already registered');
  }

  // Reserve before the network call. DELETE changes its ETag, so an in-flight
  // registration cannot restore a token after consent is withdrawn.
  const lease = await store.setJSON(key, { pending: true, expiresAt: now + 60 }, { onlyIfNew: true });
  if (!lease.modified || !lease.etag) return response(409, 'Activity changed');
  let accepted;
  try { accepted = await send(token, record.environment, payload(record, now)); }
  catch { accepted = { status: 503 }; }
  if (accepted.status !== 200) {
    await store.setJSON(key, { pending: true, expiresAt: now }, { onlyIfMatch: lease.etag });
    return response(accepted.status === 400 || accepted.status === 410 ? 422 : 503, 'Push registration failed');
  }
  const result = await store.setJSON(key, { ...record, token }, { onlyIfMatch: lease.etag });
  if (!result.modified) return response(409, 'Activity changed');
  return response(204);
}

export async function tick({ store, send, now = () => Date.now() / 1000 }) {
  const started = now();
  const { blobs } = await store.list({ prefix: 'activities/' });
  const cursor = await store.get('cursor', { type: 'text' });
  const keys = blobs.map(b => b.key).sort();
  const start = cursor ? keys.findIndex(k => k > cursor) : 0;
  const offset = start < 0 ? 0 : start;
  const ordered = keys.slice(offset).concat(keys.slice(0, offset));
  let next = 0, processed = 0, delivered = 0, failed = 0, last;
  let active = 0, stopped = 0, pending = 0, expired = 0;
  await Promise.all(Array.from({ length: Math.min(8, ordered.length) }, async () => {
    while (next < ordered.length && now() - started < 22) {
      const key = ordered[next++]; last = key;
      const record = await store.get(key, { type: 'json' });
      if (!record) continue;
      processed++;
      if (now() >= record.expiresAt) { await store.delete(key); expired++; continue; }
      if (record.pending) { pending++; continue; }
      if (!record.stopped && record.protocol !== 2) {
        // Retire legacy financial payloads; old clients must update and opt in.
        await store.setJSON(key, { stopped: true, expiresAt: record.expiresAt });
        stopped++;
        continue;
      }
      if (record.stopped) stopped++;
      else active++;
      const body = payload(record, now());
      if (!body) continue;
      try {
        const result = await send(record.token, record.environment, body);
        if (result.status === 200) delivered++;
        else if (result.status === 410 || ['BadDeviceToken', 'Unregistered', 'DeviceTokenNotForTopic'].includes(result.reason)) {
          await store.setJSON(key, { stopped: true, expiresAt: record.expiresAt });
          active--; stopped++;
        } else failed++;
      } catch { failed++; }
    }
  }));
  if (last) await store.set('cursor', last);
  return { processed, delivered, failed, remaining: ordered.length - next,
    active, stopped, pending, expired };
}
