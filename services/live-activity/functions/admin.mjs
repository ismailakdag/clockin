import { getStore } from '@netlify/blobs';
import { admin } from '../lib/admin.mjs';

export default async request => {
  try {
    return await admin(request, {
      // Lazy access: unauthenticated requests do not read the database.
      store: { get: (...args) => getStore({ name: 'clockin-live-activity', consistency: 'strong' }).get(...args) },
      passwordHash: process.env.CLOCKIN_ADMIN_PASSWORD_HASH,
      sessionSecret: process.env.CLOCKIN_ADMIN_SESSION_SECRET,
    });
  } catch {
    return Response.json({ error: 'Panel verileri alınamadı. Tekrar dene.' }, {
      status: 503, headers: { 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' },
    });
  }
};

export const config = { path: ['/admin', '/admin/*', '/api/admin/*'],
  rateLimit: { windowLimit: 20, windowSize: 60, aggregateBy: ['ip', 'domain'] } };
