import test from 'node:test';
import assert from 'node:assert/strict';
import { APPLE_EPOCH, payload, registration, storageKey } from '../lib/activity.mjs';
import { handle, tick } from '../lib/relay.mjs';

const now = 1790000000;
const token = 'a'.repeat(128);
const body = () => ({ protocol: 2, environment: 'production', expiresAt: now + 8 * 3600 });
function memory() {
  const data = new Map(); const versions = new Map(); let version = 0;
  return { data,
    async get(k) { return data.has(k) ? structuredClone(data.get(k)) : null; },
    async setJSON(k, v, options = {}) {
      if (options.onlyIfNew && data.has(k)) return { modified: false };
      if (options.onlyIfMatch && versions.get(k) !== options.onlyIfMatch) return { modified: false };
      data.set(k, structuredClone(v)); const etag = String(++version); versions.set(k, etag);
      return { modified: true, etag };
    },
    async set(k, v) { data.set(k, v); },
    async delete(k) { data.delete(k); },
    async list() { return { blobs: [...data.keys()].filter(k => k.startsWith('activities/')).map(key => ({ key })) }; },
  };
}
const request = (method = 'PUT', value = body(), credential = token) => new Request('https://example.test/api/v1/live-activity', {
  method, headers: { authorization: `Bearer ${credential}` }, body: method === 'PUT' ? JSON.stringify(value) : undefined,
});

test('minute pushes contain only time; registration cannot retain session content', () => {
  const record = registration(body(), now);
  assert.deepEqual(record, body());
  assert.deepEqual(payload(record, now + 60), { aps: {
    timestamp: now + 60, event: 'update', 'stale-date': now + 150,
    'content-state': { remoteTick: true, updatedAt: now + 60 - APPLE_EPOCH },
  } });
  assert.equal(payload(record, now + 8 * 3600), null);
  assert.equal(payload({ ...record, stopped: true }, now), null);
  for (const extra of [{ state: { hourlyRate: 25, note: 'private' } },
    { hourlyRate: 25 }, { note: 'private' }, { theme: 'Carbon' }, { userId: 'name' }]) {
    assert.throws(() => registration({ ...body(), ...extra }, now));
  }
});

test('legacy, missing-consent-protocol and invalid lifetimes are rejected', () => {
  for (const change of [{ protocol: 1 }, { protocol: undefined }, { environment: 'unknown' },
    { expiresAt: now }, { expiresAt: now + 8 * 3600 + 6 }, { expiresAt: Infinity }]) {
    assert.throws(() => registration({ ...body(), ...change }, now));
  }
});

test('only a valid APNs capability can create a record', async () => {
  const store = memory(); let calls = 0;
  const deps = { store, now, send: async () => { calls++; return { status: 400, reason: 'BadDeviceToken' }; } };
  assert.equal((await handle(request('PUT', body(), 'wrong'), deps)).status, 401);
  assert.equal(calls, 0);
  assert.equal((await handle(request(), deps)).status, 422);
  const pending = store.data.get(`activities/${storageKey(token)}`);
  assert.deepEqual(pending, { pending: true, expiresAt: now }); // no token or session data
  await tick({ store, send: deps.send, now: () => now + 1 });
  assert.equal(store.data.size, 1); // only the non-sensitive round-robin cursor remains
  assert.equal((await handle(request('DELETE'), deps)).status, 204);
  assert.equal((await store.list()).blobs.length, 0); // random DELETEs cannot fill storage
});

test('accepted registration is immutable; relaunch does not extend retention', async () => {
  const store = memory(); let calls = 0;
  const deps = { store, now, send: async () => { calls++; return { status: 200 }; } };
  assert.equal((await handle(request(), deps)).status, 204);
  assert.equal((await handle(request('PUT', { ...body(), expiresAt: body().expiresAt + 1 }), deps)).status, 204);
  assert.equal(calls, 1);
  assert.equal((await handle(request('PUT', { ...body(), environment: 'sandbox' }), deps)).status, 409);
  const saved = store.data.get(`activities/${storageKey(token)}`);
  assert.deepEqual(Object.keys(saved).sort(), ['environment', 'expiresAt', 'protocol', 'token']);
  assert.equal(saved.expiresAt, body().expiresAt);
});

test('stop survives delayed registration and scheduler does not send paused work', async () => {
  const store = memory(); let calls = 0;
  const send = async () => { calls++; return { status: 200 }; };
  const deps = { store, now, send };
  await handle(request(), deps);
  await handle(request('DELETE'), deps);
  assert.equal((await handle(request(), deps)).status, 410);
  const counts = await tick({ store, send, now: () => now + 60 });
  assert.equal(counts.delivered, 0);
  assert.equal(calls, 1);
});

test('scheduler sends time without app traffic, then removes invalid tokens', async () => {
  const store = memory(); const sent = [];
  await handle(request(), { store, now, send: async () => ({ status: 200 }) });
  const first = await tick({ store, now: () => now + 60,
    send: async (t, env, p) => { sent.push({ t, env, p }); return { status: 200 }; } });
  assert.equal(first.delivered, 1);
  assert.deepEqual(sent[0].p.aps['content-state'], { remoteTick: true, updatedAt: now + 60 - APPLE_EPOCH });
  assert.equal(sent[0].env, 'production');
  await tick({ store, now: () => now + 120, send: async () => ({ status: 410, reason: 'Unregistered' }) });
  assert.equal(store.data.get(`activities/${storageKey(token)}`).stopped, true);
  await tick({ store, now: () => now + 8 * 3600, send: async () => assert.fail('Expired token sent') });
  assert.equal(store.data.has(`activities/${storageKey(token)}`), false);
});

test('APNs outage retains the calculation for next minute', async () => {
  const store = memory();
  await handle(request(), { store, now, send: async () => ({ status: 200 }) });
  const result = await tick({ store, now: () => now + 60, send: async () => { throw new Error('offline'); } });
  assert.equal(result.failed, 1);
  assert.equal(store.data.get(`activities/${storageKey(token)}`).stopped, undefined);
});

test('request size and method are bounded before APNs', async () => {
  const deps = { store: memory(), now, send: async () => assert.fail('No push expected') };
  assert.equal((await handle(new Request('https://example.test'), deps)).status, 405);
  const large = { ...body(), note: 'x'.repeat(4096) };
  assert.equal((await handle(request('PUT', large), deps)).status, 413);
});

test('legacy financial records are scrubbed without sending their content', async () => {
  const store = memory();
  store.data.set('activities/legacy', { expiresAt: now + 100, token, state: { note: 'private', hourlyRate: 25 } });
  await tick({ store, now: () => now, send: async () => assert.fail('Legacy content must not be sent') });
  assert.deepEqual(store.data.get('activities/legacy'), { stopped: true, expiresAt: now + 100 });
});

test('withdrawal during registration cannot be undone by the in-flight APNs response', async () => {
  const store = memory(); let started; let finish;
  const sending = new Promise(resolve => { started = resolve; });
  const upload = handle(request(), { store, now, send: async () => {
    started(); return await new Promise(resolve => { finish = resolve; });
  } });
  await sending;
  assert.equal((await handle(request('DELETE'), { store, now })).status, 204);
  finish({ status: 200 });
  assert.equal((await upload).status, 409);
  assert.equal(store.data.get(`activities/${storageKey(token)}`).stopped, true);
});
