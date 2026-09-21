import { createHash, createHmac, randomBytes, timingSafeEqual } from 'node:crypto';
import { html, css, javascript } from './admin-page.mjs';

const cookieName = '__Host-clockin-admin';
const lifetime = 8 * 3600;
const headers = {
  'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff',
  'Referrer-Policy': 'no-referrer', 'X-Frame-Options': 'DENY',
  'X-Robots-Tag': 'noindex, nofollow',
  'Content-Security-Policy': "default-src 'none'; script-src 'self'; style-src 'self'; connect-src 'self'; img-src 'self'; base-uri 'none'; form-action 'self'; frame-ancestors 'none'",
};
const json = (data, status = 200, extra = {}) => Response.json(data, { status, headers: { ...headers, ...extra } });
const digest = text => createHash('sha256').update(text).digest('hex');
const equal = (a, b) => a.length === b.length && timingSafeEqual(Buffer.from(a), Buffer.from(b));
const mac = (text, secret, origin) => createHmac('sha256', secret).update(`${origin}\n${text}`).digest('hex');
const cookie = (value, age = lifetime) => `${cookieName}=${value}; Path=/; HttpOnly; Secure; SameSite=Strict; Max-Age=${age}`;

function sessionValid(request, secret, now, origin) {
  const value = (request.headers.get('cookie') || '').split(';').map(x => x.trim())
    .find(x => x.startsWith(`${cookieName}=`))?.slice(cookieName.length + 1) || '';
  const match = /^(\d{10})\.([a-f0-9]{32})\.([a-f0-9]{64})$/.exec(value);
  if (!match) return false;
  const expires = Number(match[1]);
  return expires > now && expires <= now + lifetime &&
    equal(match[3], mac(`${match[1]}.${match[2]}`, secret, origin));
}

async function readPassword(request) {
  if (!(request.headers.get('content-type') || '').startsWith('application/json')) return null;
  if (Number(request.headers.get('content-length')) > 1024) return null;
  const reader = request.body?.getReader();
  if (!reader) return null;
  let bytes = 0; const chunks = [];
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    bytes += value.byteLength;
    if (bytes > 1024) { await reader.cancel(); return null; }
    chunks.push(Buffer.from(value));
  }
  try {
    const body = JSON.parse(Buffer.concat(chunks).toString('utf8'));
    return typeof body.password === 'string' && body.password.length <= 256 ? body.password : null;
  } catch { return null; }
}

export async function admin(request, { store, passwordHash, sessionSecret, now = Math.floor(Date.now() / 1000) }) {
  const url = new URL(request.url), path = url.pathname;
  if (request.method === 'GET' && ['/admin', '/admin/', '/admin/style.css', '/admin/app.js'].includes(path)) {
    const asset = path.endsWith('.css') ? [css, 'text/css'] : path.endsWith('.js') ? [javascript, 'text/javascript'] : [html, 'text/html'];
    return new Response(asset[0], { headers: { ...headers, 'Content-Type': `${asset[1]}; charset=utf-8` } });
  }
  if (!['/api/admin/session', '/api/admin/status'].includes(path)) return json({ error: 'Not found' }, 404);
  if (!/^[a-f0-9]{64}$/.test(passwordHash || '') || (sessionSecret || '').length < 64) return json({ error: 'Panel henüz yapılandırılmadı.' }, 503);
  if (path === '/api/admin/session') {
    if (!['POST', 'DELETE'].includes(request.method)) return json({ error: 'Method not allowed' }, 405);
    // Prevent cross-origin login/logout even when third-party cookies are allowed.
    if (request.headers.get('origin') !== url.origin) return json({ error: 'Forbidden' }, 403);
    if (request.method === 'DELETE') return json({ ok: true }, 200, { 'Set-Cookie': cookie('', 0) });
    const password = await readPassword(request);
    if (password === null || !equal(digest(password), passwordHash)) return json({ error: 'Parola doğru değil.' }, 401);
    const value = `${now + lifetime}.${randomBytes(16).toString('hex')}`;
    return json({ ok: true }, 200, { 'Set-Cookie': cookie(`${value}.${mac(value, sessionSecret, url.origin)}`) });
  }
  if (request.method !== 'GET') return json({ error: 'Method not allowed' }, 405);
  if (!sessionValid(request, sessionSecret, now, url.origin)) return json({ error: 'Giriş yapman gerekiyor.' }, 401);
  const snapshot = await store.get('monitor/latest', { type: 'json' });
  if (!snapshot) return json({ checkedAt: null, status: 'waiting', stale: true });
  // Whitelist fields: never return raw store records, tokens or arbitrary metadata.
  const result = { checkedAt: Number.isFinite(snapshot.checkedAt) ? snapshot.checkedAt : null,
    status: ['ok', 'error', 'unconfigured'].includes(snapshot.status) ? snapshot.status : 'error' };
  result.stale = !result.checkedAt || now * 1000 - result.checkedAt > 180000;
  for (const key of ['active', 'stopped', 'pending', 'expired', 'processed', 'apnsAccepted', 'failed', 'remaining']) {
    result[key] = Number.isSafeInteger(snapshot[key]) && snapshot[key] >= 0 ? snapshot[key] : null;
  }
  return json(result);
}
