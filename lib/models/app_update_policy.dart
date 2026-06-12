class AppUpdatePolicy {
  final int minBuildNumber;
  final String minVersionName;
  final String messageAr;
  final String androidStoreUrl;
  final String iosStoreUrl;

  const AppUpdatePolicy({
    required this.minBuildNumber,
    required this.minVersionName,
    required this.messageAr,
    required this.androidStoreUrl,
    required this.iosStoreUrl,
  });

  factory AppUpdatePolicy.fromMap(Map<String, dynamic> map) {
    return AppUpdatePolicy(
      minBuildNumber: (map['minBuildNumber'] as num?)?.toInt() ??
          (map['min_build_number'] as num?)?.toInt() ??
          1,
      minVersionName: map['minVersionName']?.toString() ??
          map['min_version_name']?.toString() ??
          '',
      messageAr: map['messageAr']?.toString() ??
          map['message_ar']?.toString() ??
          'يجب تحديث التطبيق للمتابعة.',
      androidStoreUrl: map['androidStoreUrl']?.toString() ??
          map['android_store_url']?.toString() ??
          '',
      iosStoreUrl: map['iosStoreUrl']?.toString() ??
          map['ios_store_url']?.toString() ??
          '',
    );
  }
}
