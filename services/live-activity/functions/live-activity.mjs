import { getStore } from '@netlify/blobs';
import { send, isConfigured } from '../lib/apns.mjs';
import { handle } from '../lib/relay.mjs';

export default async request => {
  if (request.method === 'GET') return Response.json({
    service: 'clockin-live-activity', protocol: 2, pushConfigured: isConfigured(), intervalSeconds: 60,
  }, { headers: { 'Cache-Control': 'no-store' } });
  try {
    return await handle(request, { store: getStore({ name: 'clockin-live-activity', consistency: 'strong' }), send });
  } catch {
    // No tokens, financial values, private keys, or request bodies in logs.
    console.error('Live Activity registration unavailable');
    return new Response(null, { status: 503, headers: { 'Cache-Control': 'no-store' } });
  }
};

export const config = { path: '/api/v1/live-activity',
  rateLimit: { windowLimit: 30, windowSize: 60, aggregateBy: ['ip', 'domain'] } };
