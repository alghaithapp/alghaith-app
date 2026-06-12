import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/phone_utils.dart';
import '../core/utils/western_digits_input_formatter.dart';
import '../providers/app_provider.dart';
import '../services/phone_auth_api.dart';
import '../utils/apple_review_auth.dart';
import '../utils/helpers.dart';
import '../widgets/app_logo.dart';
import '../widgets/whatsapp_icon.dart';

enum _LoginMethod { whatsapp, sms }

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _codeFocusNode = FocusNode();
  final PhoneAuthApi _authApi = PhoneAuthApi();
  final List<_LoginMethod> _fallbackOrder = const [
    _LoginMethod.whatsapp,
    _LoginMethod.sms,
  ];

  _LoginMethod _selectedMethod = _LoginMethod.whatsapp;
  bool _otpSent = false;
  bool _isSubmitting = false;
  String? _lastAutoSubmittedCode;

  @override
  void initState() {
    super.initState();
    _codeController.addListener(_maybeAutoVerify);
  }

  @override
  void dispose() {
    _codeController.removeListener(_maybeAutoVerify);
    _phoneController.dispose();
    _codeController.dispose();
    _codeFocusNode.dispose();
    super.dispose();
  }

  void _maybeAutoVerify() {
    final code = PhoneUtils.digitsOnly(_codeController.text);
    if (!_otpSent || _isSubmitting) {
      return;
    }
    if (code.length != 6) {
      _lastAutoSubmittedCode = null;
      return;
    }
    if (_lastAutoSubmittedCode == code) {
      return;
    }
    _lastAutoSubmittedCode = code;
    _verifyCode();
  }

  bool _isPhoneValid(String phone) {
    if (AppleReviewAuth.isDemoPhone(phone)) return true;
    final digitsOnly = AppleReviewAuth.digitsOnly(phone);
    return digitsOnly.length == 11;
  }

  String _toE164(String phone) => AppleReviewAuth.toE164(phone);

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Cairo')),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _channelFor(_LoginMethod method) {
    return switch (method) {
      _LoginMethod.sms => 'sms',
      _LoginMethod.whatsapp => 'whatsapp',
    };
  }

  String _fallbackLabel(_LoginMethod method) {
    return switch (method) {
      _LoginMethod.sms => 'SMS',
      _LoginMethod.whatsapp => 'واتساب',
    };
  }

  _LoginMethod? _nextFallback(_LoginMethod current) {
    final currentIndex = _fallbackOrder.indexOf(current);
    if (currentIndex == -1 || currentIndex >= _fallbackOrder.length - 1) {
      return null;
    }
    return _fallbackOrder[currentIndex + 1];
  }

  Future<void> _sendCode() async {
    final phone = AppleReviewAuth.canonicalizeInput(_phoneController.text);
    if (!_isPhoneValid(phone)) {
      _showSnack('أدخل رقم هاتف من 11 رقم');
      return;
    }

    try {
      setState(() => _isSubmitting = true);
      await _authApi.sendCode(
        _toE164(phone),
        channel: _channelFor(_selectedMethod),
      );
      if (!mounted) return;
      setState(() {
        _otpSent = true;
        _codeController.clear();
        _lastAutoSubmittedCode = null;
      });
      FocusScope.of(context).requestFocus(_codeFocusNode);
      _showSnack('تم إرسال رمز التحقق');
    } catch (e) {
      if (!mounted) return;
      final nextMethod = _nextFallback(_selectedMethod);
      if (nextMethod != null) {
        setState(() => _selectedMethod = nextMethod);
        _showSnack(
          '${e.toString().replaceFirst('Exception: ', '')}\nجرب ${_fallbackLabel(nextMethod)}.',
        );
      } else {
        _showSnack(e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _verifyCode() async {
    final phone = AppleReviewAuth.canonicalizeInput(_phoneController.text);
    final code = PhoneUtils.digitsOnly(_codeController.text);
    if (!_otpSent) {
      _showSnack('أرسل رمز التحقق أولاً');
      return;
    }
    if (code.length != 6 || !RegExp(r'^\d{6}$').hasMatch(code)) {
      _showSnack('أدخل رمز التحقق المكوّن من 6 أرقام');
      return;
    }

    try {
      setState(() => _isSubmitting = true);
      final session = await _authApi.verifyCode(_toE164(phone), code);
      if (!mounted) return;
      final provider = context.read<AppProvider>();
      await provider.setPhoneSession(
        session.phoneNumber,
        sessionToken: session.token,
      );
    } catch (e) {
      _lastAutoSubmittedCode = null;
      if (!mounted) return;
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRestoringAccount = context.watch<AppProvider>().isLoggingIn;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          const _LoginBackdrop(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bottomInset = MediaQuery.of(context).viewInsets.bottom;
                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(18, 10, 18, bottomInset + 16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 20,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: _LoginCard(
                          phoneController: _phoneController,
                          codeController: _codeController,
                          codeFocusNode: _codeFocusNode,
                          otpSent: _otpSent,
                          isSubmitting: _isSubmitting,
                          selectedMethod: _selectedMethod,
                          onSelectMethod: (method) {
                            setState(() => _selectedMethod = method);
                          },
                          onSendCode: _sendCode,
                          onVerifyCode: _verifyCode,
                          onSupportPressed: () => AppHelpers.launchWhatsApp(
                            AppHelpers.supportWhatsAppNumber,
                            'مرحباً، أحتاج مساعدة بخصوص تسجيل الدخول في تطبيق الغيث.',
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isSubmitting || isRestoringAccount)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.28),
                child: const Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CupertinoActivityIndicator(radius: 14),
                          SizedBox(height: 14),
                          Text(
                            'جارٍ تجهيز حسابك...',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LoginBackdrop extends StatelessWidget {
  const _LoginBackdrop();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF8FBFB), Color(0xFFEAF3F3), Color(0xFFDDEDED)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -90,
            left: -70,
            child: _BlurBlob(
              size: 240,
              colors: const [Color(0xFFFFE6BF), AppColors.accent],
            ),
          ),
          Positioned(
            bottom: -100,
            right: -80,
            child: _BlurBlob(
              size: 250,
              colors: const [Color(0xFFB9DEE0), AppColors.primary],
            ),
          ),
        ],
      ),
    );
  }
}

class _BlurBlob extends StatelessWidget {
  final double size;
  final List<Color> colors;

  const _BlurBlob({required this.size, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            colors.first.withValues(alpha: 0.42),
            colors.last.withValues(alpha: 0.08),
          ],
        ),
      ),
    );
  }
}

class _LoginCard extends StatelessWidget {
  final TextEditingController phoneController;
  final TextEditingController codeController;
  final FocusNode codeFocusNode;
  final bool otpSent;
  final bool isSubmitting;
  final _LoginMethod selectedMethod;
  final ValueChanged<_LoginMethod> onSelectMethod;
  final VoidCallback onSendCode;
  final VoidCallback onVerifyCode;
  final VoidCallback onSupportPressed;

  const _LoginCard({
    required this.phoneController,
    required this.codeController,
    required this.codeFocusNode,
    required this.otpSent,
    required this.isSubmitting,
    required this.selectedMethod,
    required this.onSelectMethod,
    required this.onSendCode,
    required this.onVerifyCode,
    required this.onSupportPressed,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isCodeValid =
        PhoneUtils.digitsOnly(codeController.text).length == 6;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.12),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppLogo(size: 72),
          const SizedBox(height: 14),
          const Text(
            'أهلاً بك في الغيث',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              fontFamily: 'Cairo',
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'سجّل دخولك برقم الهاتف للوصول إلى خدماتك',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              fontFamily: 'Cairo',
              color: Color(0xFF5A6B6E),
            ),
          ),
          const SizedBox(height: 20),
          _PhoneField(controller: phoneController),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MethodCard(
                  title: 'واتساب',
                  icon: CupertinoIcons.chat_bubble_2_fill,
                  selected: selectedMethod == _LoginMethod.whatsapp,
                  onTap: () => onSelectMethod(_LoginMethod.whatsapp),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MethodCard(
                  title: 'SMS',
                  icon: CupertinoIcons.chat_bubble_text_fill,
                  selected: selectedMethod == _LoginMethod.sms,
                  onTap: () => onSelectMethod(_LoginMethod.sms),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: !otpSent
                ? _ActionButton(
                    text: 'إرسال رمز التحقق',
                    onPressed: isSubmitting ? null : onSendCode,
                    showLoading: isSubmitting,
                  )
                : Column(
                    children: [
                      _CodeField(controller: codeController, focusNode: codeFocusNode),
                      const SizedBox(height: 10),
                      _ActionButton(
                        text: 'تحقق والدخول',
                        onPressed: isSubmitting || !isCodeValid ? null : onVerifyCode,
                        showLoading: isSubmitting,
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 20),
          _SupportButton(onPressed: onSupportPressed),
          const SizedBox(height: 15),
          GestureDetector(
            onTap: () => context.read<AppProvider>().setGuestMode(),
            child: const Text(
              'الدخول كزائر للتطبيق',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhoneField extends StatefulWidget {
  final TextEditingController controller;

  const _PhoneField({required this.controller});

  @override
  State<_PhoneField> createState() => _PhoneFieldState();
}

class _PhoneFieldState extends State<_PhoneField> {
  static const _validColor = Color(0xFF16A34A);
  static const _invalidColor = Color(0xFFDC2626);
  static const _neutralBorderColor = Color(0xFFCDE3E5);
  static const _neutralTextColor = Color(0xFF1A1A1A);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onPhoneChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onPhoneChanged);
    super.dispose();
  }

  void _onPhoneChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final digitCount = PhoneUtils.digitsOnly(widget.controller.text).length;
    final isComplete = digitCount == 11;
    final hasInput = digitCount > 0;

    final textColor = isComplete
        ? _validColor
        : hasInput
            ? _invalidColor
            : _neutralTextColor;
    final borderColor = isComplete
        ? _validColor
        : hasInput
            ? _invalidColor
            : _neutralBorderColor;
    final iconColor = isComplete
        ? _validColor
        : hasInput
            ? _invalidColor
            : AppColors.accent;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: hasInput || isComplete ? 1.6 : 1),
      ),
      child: TextField(
        controller: widget.controller,
        keyboardType: TextInputType.phone,
        maxLength: 11,
        inputFormatters: const [
          WesternDigitsInputFormatter(maxLength: 11),
        ],
        style: TextStyle(
          fontFamily: 'Cairo',
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
        decoration: InputDecoration(
          hintText: 'رقم الهاتف (مثلاً 07701234567)',
          hintStyle: const TextStyle(
            fontFamily: 'Cairo',
            color: Color(0xFFBCA59C),
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: Icon(CupertinoIcons.phone_fill, color: iconColor),
          counterText: '',
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        ),
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _MethodCard({
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFF6E6) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? AppColors.accent : const Color(0xFFE2ECEC)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _CodeField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;

  const _CodeField({required this.controller, required this.focusNode});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              inputFormatters: const [
                WesternDigitsInputFormatter(maxLength: 6),
              ],
              autofillHints: const [AutofillHints.oneTimeCode], // تفعيل ميزة الاستيراد التلقائي من النظام
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 8),
              decoration: const InputDecoration(
                hintText: '------',
                counterText: '',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: TextButton.icon(
              onPressed: () async {
                final data = await Clipboard.getData('text/plain');
                final pasted =
                    PhoneUtils.digitsOnly(data?.text ?? '');
                if (pasted.isNotEmpty) {
                  controller.text = pasted.length > 6 ? pasted.substring(0, 6) : pasted;
                }
              },
              icon: const Icon(CupertinoIcons.doc_on_clipboard_fill, size: 16, color: AppColors.primary),
              label: const Text('لصق', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: AppColors.primary)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool showLoading;

  const _ActionButton({required this.text, required this.onPressed, required this.showLoading});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: showLoading 
          ? const CircularProgressIndicator(color: Colors.white) 
          : Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
      ),
    );
  }
}

class _SupportButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _SupportButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: const WhatsAppIcon(size: 20),
      label: const Text('الدعم والمساعدة', style: TextStyle(fontFamily: 'Cairo', color: Color(0xFF5A6B6E))),
    );
  }
}
