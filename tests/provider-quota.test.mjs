import assert from 'node:assert/strict';
import test from 'node:test';
import { formatProviderQuota } from '../lib/programs/omp/provider-quota.mjs';

const now = 1_800_000_000_000;

function text(quota) {
  return quota.segments.map((segment) => segment.text).join(' ');
}

function limit(id, label, windowLabel, usedFraction, resetsInMs) {
  return {
    id,
    label,
    amount: { usedFraction, unit: 'percent' },
    window: { label: windowLabel, resetsAt: now + resetsInMs },
  };
}

test('formats the selected provider’s own quota windows and ignores other providers', () => {
  const reports = [
    {
      provider: 'github-copilot',
      fetchedAt: now,
      limits: [limit('premium', 'Premium interactions', 'Monthly', 0.01, 3_600_000)],
    },
    {
      provider: 'openai-codex',
      fetchedAt: now,
      limits: [
        limit('primary', 'Codex', '5 Hour', 0.02, 5_400_000),
        limit('secondary', 'Codex', '7 Day', 0.68, 86_400_000),
      ],
      resetCredits: { availableCount: 2, redeemableCount: 1 },
    },
  ];

  const copilot = formatProviderQuota(reports, 'github-copilot', now);
  assert.equal(copilot.length, 1);
  assert.match(text(copilot[0]), /Premium interactions · Monthly ████████ 99% remaining/);
  assert.match(text(copilot[0]), /resets in 1h0m/);
  assert.equal(copilot[0].segments[1].status, 'success');

  const codex = formatProviderQuota(reports, 'openai-codex', now);
  assert.equal(codex.length, 1);
  assert.match(text(codex[0]), /Codex · 5 Hour ████████ 98% remaining/);
  assert.match(text(codex[0]), /Codex · 7 Day ███░░░░░ 32% remaining/);
  assert.match(text(codex[0]), /2 saved resets \(1 redeemable\)/);
  assert.equal(codex[0].segments[2].status, 'warning');
});

test('uses normalized absolute amounts when no fraction is supplied', () => {
  const reports = [{
    provider: 'example',
    fetchedAt: now,
    limits: [{
      id: 'requests',
      label: 'Requests',
      amount: { used: 75, limit: 100, unit: 'requests' },
      window: { label: 'Daily' },
    }],
  }];

  const [quota] = formatProviderQuota(reports, 'example', now);
  assert.match(text(quota), /Requests · Daily ██░░░░░░ 25% remaining/);
  assert.equal(quota.segments[1].status, 'warning');
});

test('marks stale reports and omits providers without reported limits', () => {
  const reports = [{
    provider: 'stale-provider',
    fetchedAt: now - 11 * 60 * 1000,
    limits: [limit('quota', 'Quota', 'Weekly', 0.95, 60_000)],
  }];

  const [stale] = formatProviderQuota(reports, 'stale-provider', now);
  assert.match(text(stale), /stale data/);
  assert.equal(stale.segments.at(-1).status, 'warning');
  assert.deepEqual(formatProviderQuota(reports, 'unsupported-provider', now), []);
  assert.deepEqual(formatProviderQuota([{ provider: 'empty', fetchedAt: now, limits: [] }], 'empty', now), []);
});

test('preserves an exhausted status when a provider omits numeric usage', () => {
  const [quota] = formatProviderQuota([{
    provider: 'example',
    fetchedAt: now,
    limits: [{
      id: 'requests',
      label: 'Requests',
      amount: { unit: 'requests' },
      status: 'exhausted',
    }],
  }], 'example', now);

  assert.match(text(quota), /Requests exhausted/);
  assert.equal(quota.segments[1].status, 'error');
});

test('marks low remaining quota red below twenty percent', () => {
  const [quota] = formatProviderQuota([{
    provider: 'example',
    fetchedAt: now,
    limits: [limit('quota', 'Quota', 'Weekly', 0.81, 60_000)],
  }], 'example', now);

  assert.match(text(quota), /Quota · Weekly ██░░░░░░ 19% remaining/);
  assert.equal(quota.segments[1].status, 'error');
});
