const STALE_AFTER_MS = 10 * 60 * 1000;
const compactNumber = new Intl.NumberFormat(undefined, {
  notation: 'compact',
  maximumFractionDigits: 1,
});

function cleanLabel(value) {
  return typeof value === 'string'
    ? value.replace(/[\u0000-\u001f\u007f]/g, '').replace(/\s+/g, ' ').trim()
    : '';
}

function usedFraction(limit) {
  const amount = limit?.amount;
  if (!amount || typeof amount !== 'object') return undefined;
  if (Number.isFinite(amount.usedFraction)) return amount.usedFraction;
  if (Number.isFinite(amount.used) && Number.isFinite(amount.limit) && amount.limit > 0) {
    return amount.used / amount.limit;
  }
  if (amount.unit === 'percent' && Number.isFinite(amount.used)) return amount.used / 100;
  if (Number.isFinite(amount.remainingFraction)) return Math.max(0, 1 - amount.remainingFraction);
  if (Number.isFinite(amount.remaining) && Number.isFinite(amount.limit) && amount.limit > 0) {
    return Math.max(0, 1 - amount.remaining / amount.limit);
  }
  return undefined;
}

function formatDuration(milliseconds) {
  const minutes = Math.max(1, Math.floor(milliseconds / 60_000));
  const days = Math.floor(minutes / (24 * 60));
  const hours = Math.floor((minutes % (24 * 60)) / 60);
  const remainingMinutes = minutes % 60;
  if (days) return `${days}d${hours}h`;
  if (hours) return `${hours}h${remainingMinutes}m`;
  return `${remainingMinutes}m`;
}

function formatLimit(limit, now) {
  const windowLabel = cleanLabel(limit.window?.label);
  const name = cleanLabel(limit.label) || cleanLabel(limit.id) || 'Limit';
  const title = windowLabel && windowLabel.toLowerCase() !== name.toLowerCase()
    ? `${name} · ${windowLabel}`
    : name;
  const fraction = usedFraction(limit);
  const amount = limit.amount || {};
  const remainingPercent = fraction === undefined
    ? Number.isFinite(amount.remainingFraction)
      ? Math.max(0, Math.min(100, amount.remainingFraction * 100))
      : undefined
    : Math.max(0, Math.min(100, (1 - fraction) * 100));
  const color = limit.status === 'exhausted' || remainingPercent !== undefined && remainingPercent < 20
    ? 'error'
    : limit.status === 'warning' || remainingPercent !== undefined && remainingPercent < 50
      ? 'warning'
      : remainingPercent !== undefined || limit.status === 'ok'
        ? 'success'
        : 'muted';
  const filled = remainingPercent === undefined ? 0 : Math.round(remainingPercent / 100 * 8);
  const gauge = remainingPercent === undefined
    ? ''
    : `${'█'.repeat(filled)}${'░'.repeat(8 - filled)} ${remainingPercent.toFixed(0)}% remaining`;
  let value = gauge;
  if (!value && limit.status === 'exhausted') value = 'exhausted';
  else if (!value && limit.status === 'warning') value = 'near limit';
  else if (!value && Number.isFinite(amount.used) && Number.isFinite(amount.limit)) {
    value = `${compactNumber.format(amount.used)}/${compactNumber.format(amount.limit)} ${cleanLabel(amount.unit)}`.trim();
  } else if (!value && Number.isFinite(amount.remaining)) {
    value = `${compactNumber.format(amount.remaining)} ${cleanLabel(amount.unit)} remaining`.trim();
  } else if (!value) value = 'usage unavailable';

  const resetsAt = limit.window?.resetsAt;
  if (Number.isFinite(resetsAt) && resetsAt > now) {
    const resetLabel = cleanLabel(limit.window?.resetLabel) || 'resets';
    value += ` · ${resetLabel} in ${formatDuration(resetsAt - now)}`;
  }
  return { text: `${title} ${value}`, fraction, status: color };
}

/** Formats normalized OMP UsageReports without provider-specific quota assumptions. */
export function formatProviderQuota(reports, provider, now = Date.now()) {
  if (!provider || !Array.isArray(reports)) return [];
  const matching = reports.filter((report) => report?.provider === provider);
  return matching.flatMap((report, index) => {
    const limits = Array.isArray(report.limits) ? report.limits : [];
    const formatted = limits.map((limit) => formatLimit(limit, now));
    const credits = report.resetCredits;
    if (Number.isFinite(credits?.availableCount) && credits.availableCount > 0) {
      const redeemable = Number.isFinite(credits.redeemableCount)
        ? ` (${credits.redeemableCount} redeemable)`
        : '';
      formatted.push({
        text: `${credits.availableCount} saved resets${redeemable}`,
        status: 'accent',
      });
    }
    if (formatted.length === 0) return [];

    const age = now - report.fetchedAt;
    const stale = !Number.isFinite(report.fetchedAt) || age < 0 || age > STALE_AFTER_MS;
    return [{
      segments: [
        { text: `account ${index + 1}:`, status: 'accent' },
        ...formatted,
        ...(stale ? [{ text: 'stale data', status: 'warning' }] : []),
      ],
    }];
  });
}
