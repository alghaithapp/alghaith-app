const {
  DEFAULT_TTL_MS,
  generateOtp,
  normalizePhone,
  normalizePhoneForDisplay,
  readJsonBody,
  saveOtpRequest,
  sendOtpViaOtpiq,
} = require('../_lib');

module.exports = async function sendCode(req, res) {
  try {
    if (req.method !== 'POST') {
      res.setHeader('Allow', 'POST');
      return res.status(405).json({ success: false, message: 'Method not allowed.' });
    }

    const body = await readJsonBody(req);
    const phone = normalizePhone(body?.phone);
    const channel = String(body?.channel || 'sms').trim().toLowerCase();

    if (!phone) {
      return res.status(400).json({ success: false, message: 'Phone number is required.' });
    }

    const ttlMs = Number.parseInt(process.env.OTP_TTL_MS || `${DEFAULT_TTL_MS}`, 10);
    const otpLength = Number.parseInt(process.env.OTP_LENGTH || '6', 10);
    const verificationCode = generateOtp(otpLength);
    const smsResult = await sendOtpViaOtpiq(phone, verificationCode, channel);

    await saveOtpRequest(
      phone,
      verificationCode,
      Date.now() + ttlMs,
      channel,
      smsResult?.smsId || null
    );

    return res.status(200).json({
      success: true,
      phoneNumber: normalizePhoneForDisplay(phone),
      smsId: smsResult?.smsId || null,
      channel,
      expiresInMs: ttlMs,
    });
  } catch (error) {
    console.error('send-code error:', error);
    return res.status(500).json({
      success: false,
      message: error?.message || 'Failed to send verification code.',
    });
  }
};
