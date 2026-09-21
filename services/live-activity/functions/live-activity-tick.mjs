import { getStore } from '@netlify/blobs';
import { send, isConfigured } from '../lib/apns.mjs';
import { tick } from '../lib/relay.mjs';

export default async () => {
  const store = getStore({ name: 'clockin-live-activity', consistency: 'strong' });
  if (!isConfigured()) {
    console.error('Live Activity APNs configuration missing');
    await store.setJSON('monitor/latest', { checkedAt: Date.now(), status: 'unconfigured' });
    return;
  }
  let counts;
  try { counts = await tick({ store, send }); }
  catch {
    await store.setJSON('monitor/latest', { checkedAt: Date.now(), status: 'error' });
    throw new Error('Live Activity tick failed');
  }
  // One aggregate snapshot, overwritten each minute. No activity IDs or tokens.
  // Monitoring failure must not change the completed push job's result.
  try {
    await store.setJSON('monitor/latest', { checkedAt: Date.now(), status: 'ok',
      active: counts.active, stopped: counts.stopped, pending: counts.pending,
      expired: counts.expired, processed: counts.processed, apnsAccepted: counts.delivered,
      failed: counts.failed, remaining: counts.remaining });
  } catch { console.error('Live Activity monitor snapshot unavailable'); }
  // APNs acceptance is not proof of delivery/rendering on the phone.
  // Log aggregate counters only; never tokens, content, rates or notes.
  console.info('Live Activity tick', {
    processed: counts.processed, apnsAccepted: counts.delivered,
    failed: counts.failed, remaining: counts.remaining,
  });
};

export const config = { schedule: '* * * * *' };
