class MaintenancePolicy {
  final bool enabled;
  final String messageAr;
  final String messageEn;
  final bool allowAdminBypass;

  const MaintenancePolicy({
    required this.enabled,
    required this.messageAr,
    required this.messageEn,
    required this.allowAdminBypass,
  });

  factory MaintenancePolicy.fromMap(Map<String, dynamic> map) {
    final enabledRaw = map['enabled'];
    final bypassRaw = map['allowAdminBypass'] ?? map['allow_admin_bypass'];

    return MaintenancePolicy(
      enabled: enabledRaw == true ||
          enabledRaw == 1 ||
          enabledRaw == 'true' ||
          enabledRaw == '1',
      messageAr: map['messageAr']?.toString() ??
          map['message_ar']?.toString() ??
          'المنصة قيد الصيانة حالياً. نعمل على تحسين الخدمة ونعود قريباً.',
      messageEn: map['messageEn']?.toString() ??
          map['message_en']?.toString() ??
          'The platform is under maintenance.',
      allowAdminBypass: bypassRaw != false &&
          bypassRaw != 0 &&
          bypassRaw != 'false' &&
          bypassRaw != '0',
    );
  }
}
