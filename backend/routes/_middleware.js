/**
 * Shared middleware and utilities for route handlers.
 */

/**
 * Normalize an Iraqi phone number to international format (964...).
 */
function normalizePhone(phone) {
  const raw = String(phone || '').trim().replace(/[\s-]/g, '');
  if (!raw) return '';

  const digits = raw.replace(/\D/g, '');
  if (digits === '000000000') {
    return '9647000000000';
  }
  if (digits.startsWith('0')) {
    return `964${digits.slice(1)}`;
  }
  if (digits.startsWith('964')) {
    return digits;
  }
  return `964${digits}`;
}

/**
 * Extract a single string value from req.query, handling arrays.
 */
function parseQueryValue(value) {
  if (Array.isArray(value)) return value[0];
  return value;
}

/**
 * Read the requested phone number from the request (query for GET/DELETE, body otherwise).
 */
function readRequestedPhone(req) {
  if (req.method === 'GET' || req.method === 'DELETE') {
    return String(parseQueryValue(req.query.phone) || '').trim();
  }
  return String(req.body?.phone || '').trim();
}

/**
 * Middleware that verifies the requested phone matches the authenticated phone.
 * Returns the normalized phone or null (having already sent an error response).
 *
 * @param {import('express').Request} req
 * @param {import('express').Response} res
 * @param {{ allowMissing?: boolean }} [options]
 * @returns {string|null}
 */
function requireAuthorizedPhone(req, res, { allowMissing = false } = {}) {
  const requestedPhone = normalizePhone(readRequestedPhone(req));
  if (!requestedPhone) {
    if (allowMissing) {
      return req.authPhone;
    }
    res.status(400).json({ message: 'Phone number is required.' });
    return null;
  }

  if (requestedPhone !== req.authPhone) {
    res.status(403).json({ message: 'You are not allowed to access this phone number.' });
    return null;
  }

  return requestedPhone;
}

/**
 * Like requireAuthorizedPhone but allows missing phone (falls back to req.authPhone).
 */
function requireOptionalAuthorizedPhone(req, res) {
  return requireAuthorizedPhone(req, res, { allowMissing: true });
}

module.exports = {
  normalizePhone,
  parseQueryValue,
  readRequestedPhone,
  requireAuthorizedPhone,
  requireOptionalAuthorizedPhone,
};
