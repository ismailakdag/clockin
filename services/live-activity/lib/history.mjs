// Rolling aggregate history for the panel. Counts only, never tokens, activity
// ids or content: the same thing the policy says application logs may contain.
// One blob is rewritten each minute, so retention costs a fixed ~20 KB.
export const FIELDS = ['active', 'stopped', 'pending', 'expired', 'delivered', 'failed', 'sandbox', 'production'];
export const MINUTES = 120;        // two hours at one minute
export const BUCKET = 300;         // five minutes
export const BUCKETS = 288;        // twenty four hours

const count = value => {
  const number = Math.trunc(Number(value));
  return Number.isSafeInteger(number) && number >= 0 ? number : 0;
};
const row = (at, counts) => [Math.floor(at), ...FIELDS.map(field => count(counts?.[field]))];
const readable = entry => Array.isArray(entry) && entry.length === FIELDS.length + 1
  && entry.every(value => Number.isSafeInteger(value) && value >= 0);

export const empty = () => ({ minutes: [], buckets: [] });

export function append(history, counts, at) {
  if (!Number.isFinite(at) || at <= 0) return history && sanitise(history) || empty();
  const previous = sanitise(history);
  const minutes = previous.minutes.filter(entry => entry[0] < at).concat([row(at, counts)]).slice(-MINUTES);
  const start = Math.floor(at / BUCKET) * BUCKET;
  const buckets = previous.buckets.filter(entry => entry[0] < start).concat([row(start, counts)]).slice(-BUCKETS);
  return { minutes, buckets };
}

// The panel must never receive raw store content, so rows are rebuilt from
// validated integers and anything malformed is dropped rather than repaired.
export function sanitise(history) {
  const series = key => {
    const entries = Array.isArray(history?.[key]) ? history[key].filter(readable) : [];
    return entries.sort((a, b) => a[0] - b[0]).slice(key === 'minutes' ? -MINUTES : -BUCKETS);
  };
  return { minutes: series('minutes'), buckets: series('buckets') };
}
