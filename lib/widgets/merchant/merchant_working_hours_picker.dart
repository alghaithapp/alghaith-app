import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../utils/merchant_profile_fields.dart';

/// اختيار وقت الافتتاح (صباحاً) ووقت الإغلاق (مساءً) بشكل احترافي.
class MerchantWorkingHoursPicker extends StatelessWidget {
  const MerchantWorkingHoursPicker({
    super.key,
    required this.openTime,
    required this.closeTime,
    required this.onOpenTimeChanged,
    required this.onCloseTimeChanged,
  });

  final String openTime;
  final String closeTime;
  final ValueChanged<String> onOpenTimeChanged;
  final ValueChanged<String> onCloseTimeChanged;

  static const _brand = Color(0xFFF5A01D);

  Future<void> _pickTime(
    BuildContext context, {
    required bool isOpening,
  }) async {
    final initial = MerchantProfileFields.toTimeOfDay(
          isOpening ? openTime : closeTime,
        ) ??
        TimeOfDay(hour: isOpening ? 8 : 22, minute: 0);

    final picked = await _showArabicTimePickerSheet(
      context,
      initial: initial,
      title: isOpening ? 'وقت الافتتاح' : 'وقت الإغلاق',
      periodHint: isOpening ? 'صباحاً' : 'مساءً',
    );

    if (picked == null || !context.mounted) return;
    final stored = MerchantProfileFields.storageFromTimeOfDay(picked);
    if (isOpening) {
      onOpenTimeChanged(stored);
    } else {
      onCloseTimeChanged(stored);
    }
  }

  /// نافذة سفلية بارتفاع ثابت — تتجنب قص محتوى TimePicker في RTL.
  static Future<TimeOfDay?> _showArabicTimePickerSheet(
    BuildContext context, {
    required TimeOfDay initial,
    required String title,
    required String periodHint,
  }) {
    return showModalBottomSheet<TimeOfDay>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final bottomInset = MediaQuery.viewPaddingOf(sheetContext).bottom;
        final pickerHeight = (MediaQuery.sizeOf(sheetContext).height * 0.28)
            .clamp(200.0, 280.0);
        var selected = initial;
        final initialDateTime = DateTime(
          2020,
          1,
          1,
          initial.hour,
          initial.minute,
        );

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + bottomInset),
            child: Material(
              color: Colors.white,
              elevation: 12,
              shadowColor: Colors.black26,
              borderRadius: BorderRadius.circular(24),
              clipBehavior: Clip.antiAlias,
              child: StatefulBuilder(
                builder: (context, setSheetState) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
                        child: Row(
                          children: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(sheetContext),
                              child: const Text(
                                'إلغاء',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    title,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontFamily: 'Cairo',
                                      fontWeight: FontWeight.w900,
                                      fontSize: 17,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    periodHint,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            FilledButton(
                              onPressed: () =>
                                  Navigator.pop(sheetContext, selected),
                              style: AppButtonStyles.accentFilled(
                                borderRadius: BorderRadius.circular(12),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 10,
                                ),
                              ),
                              child: const Text(
                                'تأكيد',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      SizedBox(
                        height: pickerHeight,
                        width: double.infinity,
                        child: CupertinoTheme(
                          data: const CupertinoThemeData(
                            textTheme: CupertinoTextThemeData(
                              dateTimePickerTextStyle: TextStyle(
                                fontSize: 22,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ),
                          child: CupertinoDatePicker(
                            mode: CupertinoDatePickerMode.time,
                            use24hFormat: false,
                            initialDateTime: initialDateTime,
                            onDateTimeChanged: (dateTime) {
                              selected = TimeOfDay(
                                hour: dateTime.hour,
                                minute: dateTime.minute,
                              );
                              setSheetState(() {});
                            },
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                        child: Text(
                          MerchantProfileFields.formatArabic12h(
                            MerchantProfileFields.storageFromTimeOfDay(
                              selected,
                            ),
                          ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'أوقات العمل',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w900,
            fontSize: 15,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'حدد ساعة الافتتاح صباحاً وساعة الإغلاق مساءً — يظهر للزبائن بصيغة واضحة.',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 12,
            height: 1.45,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 12),
        _TimeSlotCard(
          icon: Icons.wb_sunny_rounded,
          iconColor: const Color(0xFFF57C00),
          iconBg: const Color(0xFFFFF3E0),
          title: 'وقت الافتتاح',
          periodHint: 'صباحاً',
          value: openTime,
          emptyHint: 'اضغط لاختيار ساعة الفتح',
          onTap: () => _pickTime(context, isOpening: true),
        ),
        const SizedBox(height: 10),
        _TimeSlotCard(
          icon: Icons.nights_stay_rounded,
          iconColor: const Color(0xFF5C6BC0),
          iconBg: const Color(0xFFE8EAF6),
          title: 'وقت الإغلاق',
          periodHint: 'مساءً',
          value: closeTime,
          emptyHint: 'اضغط لاختيار ساعة الإغلاق',
          onTap: () => _pickTime(context, isOpening: false),
        ),
      ],
    );
  }
}

class _TimeSlotCard extends StatelessWidget {
  const _TimeSlotCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.periodHint,
    required this.value,
    required this.emptyHint,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String periodHint;
  final String value;
  final String emptyHint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final display = MerchantProfileFields.formatArabic12h(value);
    final hasValue = display.isNotEmpty;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasValue
                  ? const Color(0xFFF5A01D).withValues(alpha: 0.25)
                  : Colors.grey.shade300,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: iconBg,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            periodHint,
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: iconColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasValue ? display : emptyHint,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: hasValue ? 18 : 13,
                        fontWeight:
                            hasValue ? FontWeight.w900 : FontWeight.w600,
                        color: hasValue
                            ? const Color(0xFF1A1A1A)
                            : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                CupertinoIcons.clock,
                color: hasValue ? const Color(0xFFF5A01D) : Colors.grey.shade400,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
