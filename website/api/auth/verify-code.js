const {
  deleteAuthOtp,
  loadOtpRequest,
  normalizePhone,
  readJsonBody,
} = require('../_lib');

module.exports = async function verifyCode(req, res) {
  try {
    if (req.method !== 'POST') {
      res.setHeader('Allow', 'POST');
      return res.status(405).json({ success: false, message: 'Method not allowed.' });
    }

    const body = await readJsonBody(req);
    const phone = normalizePhone(body?.phone);
    const code = String(body?.code || '').trim();

    if (!phone || !code) {
      return res
        .status(400)
        .json({ success: false, message: 'Phone number and code are required.' });
    }

    const otpEntry = await loadOtpRequest(phone);

    if (!otpEntry) {
      return res
        .status(400)
        .json({ success: false, message: 'Verification code expired. Please resend it.' });
    }

    if (otpEntry.expires_at && Number(otpEntry.expires_at) <= Date.now()) {
      await deleteAuthOtp(phone);
      return res
        .status(400)
        .json({ success: false, message: 'Verification code expired. Please resend it.' });
    }

    if (String(otpEntry.code) !== code) {
      return res.status(400).json({ success: false, message: 'Invalid verification code.' });
    }

    await deleteAuthOtp(phone);
    return res.status(200).json({ success: true });
  } catch (error) {
    console.error('verify-code error:', error);
    return res.status(500).json({
      success: false,
      message: error?.message || 'Failed to verify code.',
    });
  }
};
