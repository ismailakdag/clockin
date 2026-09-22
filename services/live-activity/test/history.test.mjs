import assert from 'node:assert/strict';
import test from 'node:test';
import { append, BUCKET, BUCKETS, empty, FIELDS, MINUTES, sanitise } from '../lib/history.mjs';

const at = 1_800_000_000;
const counts = (active, extra = {}) => ({ active, stopped: 1, pending: 0, expired: 2,
  delivered: active, failed: 0, sandbox: active, production: 0, ...extra });
const activeOf = row => row[1];

test('a sample records every field in a fixed order', () => {
  const history = append(empty(), counts(7), at);
  assert.equal(history.minutes.length, 1);
  assert.deepEqual(history.minutes[0], [at, 7, 1, 0, 2, 7, 0, 7, 0]);
  assert.equal(history.minutes[0].length, FIELDS.length + 1);
  // The bucket row is stamped with the start of its five minute window.
  assert.equal(history.buckets[0][0], Math.floor(at / BUCKET) * BUCKET);
});

test('minutes keep every tick, buckets keep the last sample of each window', () => {
  let history = empty();
  for (let i = 0; i < 12; i++) history = append(history, counts(i), at + i * 60);
  assert.equal(history.minutes.length, 12);
  assert.deepEqual(history.minutes.map(activeOf), [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]);
  // Twelve minutes span three five-minute windows, and each shows its latest value.
  assert.equal(history.buckets.length, 3);
  assert.deepEqual(history.buckets.map(activeOf), [4, 9, 11]);
});

test('both series stay bounded so the blob cannot grow without limit', () => {
  let history = empty();
  for (let i = 0; i < MINUTES + 40; i++) history = append(history, counts(i), at + i * 60);
  assert.equal(history.minutes.length, MINUTES);
  assert.equal(activeOf(history.minutes[history.minutes.length - 1]), MINUTES + 39);
  let long = empty();
  for (let i = 0; i < BUCKETS + 10; i++) long = append(long, counts(i), at + i * BUCKET);
  assert.equal(long.buckets.length, BUCKETS);
  assert.equal(activeOf(long.buckets[long.buckets.length - 1]), BUCKETS + 9);
});

test('a repeated or out of order timestamp cannot duplicate a point', () => {
  let history = append(append(empty(), counts(3), at), counts(9), at);
  assert.equal(history.minutes.length, 1);
  assert.equal(activeOf(history.minutes[0]), 9, 'the later write wins');
  history = append(history, counts(4), at - 120);
  assert.equal(history.minutes.length, 1, 'an older timestamp replaces rather than appends behind');
  assert.equal(activeOf(history.minutes[0]), 4);
});

test('an unusable timestamp leaves the existing series untouched', () => {
  const history = append(empty(), counts(5), at);
  for (const bad of [NaN, Infinity, 0, -1, undefined]) {
    assert.deepEqual(append(history, counts(9), bad), history);
  }
});

test('missing and malformed counts become zero rather than reaching the page', () => {
  const row = append(empty(), { active: -4, stopped: 1.7, pending: 'x', expired: null,
    delivered: Number.MAX_SAFE_INTEGER + 10 }, at).minutes[0];
  assert.deepEqual(row, [at, 0, 1, 0, 0, 0, 0, 0, 0]);
});

test('sanitise drops anything that is not a row of counts', () => {
  const clean = sanitise({ minutes: [[at, 1, 1, 1, 1, 1, 1, 1, 1], [at + 60, 1, 1], 'nope',
    [at + 120, 1, 1, 1, 1, 1, 1, 1, -1], { token: 'secret' }, null],
    buckets: 'not an array', extra: 'ignored' });
  assert.deepEqual(clean.minutes, [[at, 1, 1, 1, 1, 1, 1, 1, 1]]);
  assert.deepEqual(clean.buckets, []);
  assert.deepEqual(Object.keys(clean), ['minutes', 'buckets']);
});

test('sanitise sorts by time and recovers from a missing or broken blob', () => {
  const clean = sanitise({ minutes: [[at + 60, 2, 0, 0, 0, 0, 0, 0, 0], [at, 1, 0, 0, 0, 0, 0, 0, 0]] });
  assert.deepEqual(clean.minutes.map(activeOf), [1, 2]);
  for (const broken of [null, undefined, 'text', 42, []]) {
    assert.deepEqual(sanitise(broken), empty());
  }
});

test('append repairs a broken blob instead of writing on top of it', () => {
  const history = append({ minutes: [['bad']], buckets: null }, counts(6), at);
  assert.deepEqual(history.minutes.map(activeOf), [6]);
  assert.equal(history.buckets.length, 1);
});
