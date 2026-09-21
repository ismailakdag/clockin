import { createPrivateKey, sign } from 'node:crypto';
import { connect } from 'node:http2';

let cachedJWT;
let signedAt = 0;
export const isConfigured = () => Boolean(process.env.CLOCKIN_APNS_KEY_ID
  && process.env.CLOCKIN_APNS_TEAM_ID && process.env.CLOCKIN_APNS_PRIVATE_KEY);
function jwt(now) {
  if (cachedJWT && now - signedAt < 1200) return cachedJWT;
  const { CLOCKIN_APNS_KEY_ID: kid, CLOCKIN_APNS_TEAM_ID: iss, CLOCKIN_APNS_PRIVATE_KEY: pem } = process.env;
  if (!kid || !iss || !pem) throw new Error('APNs is not configured');
  const encode = value => Buffer.from(JSON.stringify(value)).toString('base64url');
  const input = `${encode({ alg: 'ES256', kid })}.${encode({ iss, iat: Math.floor(now) })}`;
  const signature = sign('sha256', Buffer.from(input), {
    key: createPrivateKey(pem), dsaEncoding: 'ieee-p1363',
  }).toString('base64url');
  signedAt = now;
  cachedJWT = `${input}.${signature}`;
  return cachedJWT;
}

export function send(token, environment, body, now = Date.now() / 1000) {
  const authorization = `bearer ${jwt(now)}`;
  return new Promise((resolve, reject) => {
    const session = connect(environment === 'sandbox' ? 'https://api.sandbox.push.apple.com' : 'https://api.push.apple.com');
    let settled = false;
    const finish = (error, result) => {
      if (settled) return;
      settled = true;
      clearTimeout(timeout);
      session.destroy();
      error ? reject(error) : resolve(result);
    };
    const timeout = setTimeout(() => finish(new Error('APNs timeout')), 5000);
    session.on('error', () => finish(new Error('APNs transport error')));
    const stream = session.request({
      ':method': 'POST', ':path': `/3/device/${token}`, authorization,
      'apns-topic': 'com.erdmncdr.clockin.push-type.liveactivity',
      // Earnings are requested on a one-minute cadence. Priority 5 can batch
      // updates indefinitely after the app backgrounds; ask for prompt delivery.
      // Priority 10 counts toward Apple's budget; frequent updates are enabled
      // in the app, but device settings and APNs still control actual delivery.
      'apns-push-type': 'liveactivity', 'apns-priority': '10',
      'apns-expiration': '0', 'apns-collapse-id': 'clockin-earnings',
      'content-type': 'application/json',
    });
    let status, response = '';
    stream.on('response', headers => { status = Number(headers[':status']); });
    stream.setEncoding('utf8');
    stream.on('data', chunk => { if (response.length < 2048) response += chunk; });
    stream.on('error', () => finish(new Error('APNs stream error')));
    stream.on('end', () => {
      let reason;
      try { reason = JSON.parse(response).reason; } catch { /* success has no body */ }
      finish(null, { status, reason });
    });
    stream.end(JSON.stringify(body));
  });
}
