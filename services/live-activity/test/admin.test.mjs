import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { admin } from '../lib/admin.mjs';
import { tick } from '../lib/relay.mjs';

const password = 'test-only-strong-password-not-used-in-production';
const now = 1790000000, origin = 'https://example.test';
const deps = { passwordHash: createHash('sha256').update(password).digest('hex'),
  sessionSecret: 'a'.repeat(64), now, store: { get: async () => null } };
function req(path = 'status', method = 'GET', options = {}) {
  return new Request(`${origin}/api/admin/${path}`, { method, ...options });
}
async function login() {
  return admin(req('session', 'POST', { headers: { origin, 'Content-Type': 'application/json' },
    body: JSON.stringify({ password }) }), deps);
}
test('unauthenticated and malformed cookies cannot read the store', async () => {
  const options = { ...deps, store: { get: () => assert.fail('private read') } };
  for (const cookie of ['', '__Host-clockin-admin=bad', '__Host-clockin-admin=' + 'x'.repeat(1000)]) {
    assert.equal((await admin(req('status', 'GET', { headers: { cookie } }), options)).status, 401);
  }
  assert.equal((await admin(req(), { ...options, passwordHash: undefined })).status, 503);
});
test('login checks origin and password, bounds payload, and secures cookie', async () => {
  for (const value of ['bad', 'x'.repeat(2048)]) {
    assert.equal((await admin(req('session', 'POST', { headers: { origin, 'Content-Type': 'application/json' },
      body: JSON.stringify({ password: value }) }), deps)).status, 401);
  }
  assert.equal((await admin(req('session', 'POST', { headers: { origin: 'https://attacker.test' }, body: '{}' }), deps)).status, 403);
  const response = await login(); assert.equal(response.status, 200);
  for (const flag of ['HttpOnly', 'Secure', 'SameSite=Strict', 'Path=/', 'Max-Age=28800']) assert.ok(response.headers.get('set-cookie').includes(flag));
});
test('valid session returns only aggregate fields; tampering, expiration and another host fail', async () => {
  const cookie = (await login()).headers.get('set-cookie').split(';')[0];
  const options = { ...deps, store: { get: async key => {
    assert.equal(key, 'monitor/latest');
    return { checkedAt: now * 1000, status: 'ok', active: 4, apnsAccepted: 4, token: 'private', email: 'private', note: 'private' };
  } } };
  const data = await (await admin(req('status', 'GET', { headers: { cookie } }), options)).json();
  assert.equal(data.active, 4); assert.equal(data.stale, false);
  for (const name of ['token', 'email', 'note']) assert.equal(Object.hasOwn(data, name), false);
  assert.equal((await admin(req('status', 'GET', { headers: { cookie } }), { ...options, now: now + 28801 })).status, 401);
  assert.equal((await admin(req('status', 'GET', { headers: { cookie: cookie.slice(0, -1) + (cookie.endsWith('0') ? '1' : '0') } }), options)).status, 401);
  assert.equal((await admin(new Request('https://other.test/api/admin/status', { headers: { cookie } }), options)).status, 401);
});
test('stale and missing snapshots are explicit; logout clears cookie and rejects cross origin', async () => {
  const cookie = (await login()).headers.get('set-cookie').split(';')[0];
  const request = req('status', 'GET', { headers: { cookie } });
  assert.equal((await (await admin(request, deps)).json()).status, 'waiting');
  const result = await admin(request, { ...deps, store: { get: async () => ({ checkedAt: (now - 181) * 1000, status: 'ok' }) } });
  assert.equal((await result.json()).stale, true);
  const logout = await admin(req('session', 'DELETE', { headers: { origin } }), deps);
  assert.ok(logout.headers.get('set-cookie').includes('Max-Age=0'));
  assert.equal((await admin(req('session', 'DELETE'), deps)).status, 403);
});
test('page and scripts have restrictive headers and no inline executable content', async () => {
  const page = await admin(new Request(origin + '/admin/'), deps);
  assert.ok(page.headers.get('content-security-policy').includes("frame-ancestors 'none'"));
  assert.ok(!page.headers.get('content-security-policy').includes('unsafe-inline'));
  assert.equal(page.headers.get('cache-control'), 'no-store');
  assert.match(await page.text(), /<html lang="tr">/);
});
test('scheduler counts active, invalid, pending, stopped and expired records without extra sends', async () => {
  const active = { protocol: 2, expiresAt: now + 100, environment: 'production' };
  const data = new Map(Object.entries({ 'activities/a': { ...active, token: 'valid' },
    'activities/b': { ...active, token: 'invalid' }, 'activities/c': { stopped: true, expiresAt: now + 100 },
    'activities/d': { pending: true, expiresAt: now + 100 }, 'activities/e': { ...active, expiresAt: now - 1 } }));
  const store = { list: async () => ({ blobs: [...data.keys()].map(key => ({ key })) }),
    get: async key => data.get(key), set: async (key, value) => data.set(key, value),
    setJSON: async (key, value) => data.set(key, value), delete: async key => data.delete(key) };
  let sends = 0;
  const result = await tick({ store, now: () => now, send: async token => { sends++; return { status: token === 'valid' ? 200 : 410 }; } });
  assert.equal(sends, 2); assert.equal(result.active, 1); assert.equal(result.stopped, 2);
  assert.equal(result.pending, 1); assert.equal(result.expired, 1); assert.equal(result.delivered, 1);
});
