import { createHash } from 'node:crypto';

export const APPLE_EPOCH = 978307200;
export const LIFETIME = 8 * 3600;
const number = (value, min, max) => typeof value === 'number' && Number.isFinite(value) && value >= min && value <= max;

// The unguessable, per-activity APNs token is the capability for this resource.
// Never put it in a public URL or return it in responses/logs. APNs must accept
// it for our fixed app topic before we store any registration.
export function tokenFrom(request) {
  const match = /^Bearer ([a-f0-9]{64,1024})$/.exec(request.headers.get('authorization') ?? '');
  return match && match[1].length % 2 === 0 ? match[1] : null;
}

export const storageKey = token => createHash('sha256').update(token).digest('hex');

export function registration(body, now) {
  if (!body || body.protocol !== 2 || !['sandbox', 'production'].includes(body.environment)
      || Object.keys(body).some(key => !['protocol', 'environment', 'expiresAt'].includes(key))
      || !number(body.expiresAt, now + 1, now + LIFETIME + 5)) throw new Error('Invalid activity');
  // A clock tick is sufficient: all earnings calculations stay on the device.
  return { protocol: 2, environment: body.environment, expiresAt: body.expiresAt };
}

export function payload(record, now) {
  if (record.protocol !== 2 || now >= record.expiresAt || record.stopped) return null;
  return { aps: {
    timestamp: Math.floor(now), event: 'update', 'stale-date': Math.floor(now + 90),
    'content-state': { remoteTick: true, updatedAt: now - APPLE_EPOCH },
  } };
}
