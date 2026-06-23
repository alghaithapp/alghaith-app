function parseTimeToMinutes(raw) {
  const value = String(raw || '').trim();
  if (!value || value.toLowerCase() === 'null') return null;

  const hourOnly = /^(\d{1,2})$/.exec(value);
  if (hourOnly) {
    const hour = Number.parseInt(hourOnly[1], 10);
    if (hour >= 0 && hour <= 23) return hour * 60;
  }

  const match = value.match(/^(\d{1,2}):(\d{2})/);
  if (!match) return null;
  const hour = Number.parseInt(match[1], 10);
  const minute = Number.parseInt(match[2], 10);
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return hour * 60 + minute * 1;
}

function nowInBaghdad() {
  const now = new Date();
  const utcMs = now.getTime() + now.getTimezoneOffset() * 60000;
  return new Date(utcMs + 3 * 3600000);
}

function isWithinWorkingHours(openTime, closeTime, referenceDate = nowInBaghdad()) {
  const openMin = parseTimeToMinutes(openTime);
  const closeMin = parseTimeToMinutes(closeTime);
  if (openMin == null || closeMin == null) return true;
  if (openMin === closeMin) return true;

  const nowMin = referenceDate.getHours() * 60 + referenceDate.getMinutes();
  if (closeMin > openMin) {
    return nowMin >= openMin && nowMin < closeMin;
  }
  return nowMin >= openMin || nowMin < closeMin;
}

function workingHoursLabel(openTime, closeTime) {
  const open = String(openTime || '').trim().slice(0, 5);
  const close = String(closeTime || '').trim().slice(0, 5);
  if (!open && !close) return '';
  if (!open) return `حتى ${close}`;
  if (!close) return `من ${open}`;
  return `${open} — ${close}`;
}

function resolveMerchantHours(profile) {
  const info =
    profile?.professional_info && typeof profile.professional_info === 'object'
      ? profile.professional_info
      : {};
  return {
    openTime: String(profile?.open_time || profile?.openTime || info.openTime || '').trim(),
    closeTime: String(
      profile?.close_time || profile?.closeTime || info.closeTime || ''
    ).trim(),
  };
}

function merchantAcceptsCustomerCalls(profile, referenceDate = nowInBaghdad()) {
  if (!profile) {
    return { allowed: true, messageAr: '' };
  }

  if (profile.is_open === false) {
    return {
      allowed: false,
      messageAr: 'المتجر مغلق حالياً — الاتصال غير متاح.',
    };
  }

  const { openTime, closeTime } = resolveMerchantHours(profile);
  if (isWithinWorkingHours(openTime, closeTime, referenceDate)) {
    return { allowed: true, messageAr: '' };
  }

  const hours = workingHoursLabel(openTime, closeTime);
  return {
    allowed: false,
    messageAr: hours
      ? `انتهى وقت الدوام (${hours}). الاتصال متاح خلال ساعات العمل فقط.`
      : 'انتهى وقت الدوام. الاتصال متاح خلال ساعات العمل فقط.',
  };
}

module.exports = {
  parseTimeToMinutes,
  nowInBaghdad,
  isWithinWorkingHours,
  workingHoursLabel,
  merchantAcceptsCustomerCalls,
};
