/// حقول ملف مندوب التوصيل — توحيد القراءة بين التطبيق والإدارة.
class CourierProfileFields {
  const CourierProfileFields._();

  static String name(Map<String, dynamic>? profile) =>
      profile?['name']?.toString().trim() ?? '';

  static String phone(Map<String, dynamic>? profile) =>
      profile?['phone']?.toString().trim() ?? '';

  static String homeAddress(Map<String, dynamic>? profile) {
    final raw = profile?['homeAddress'] ??
        profile?['address'] ??
        profile?['area'];
    return raw?.toString().trim() ?? '';
  }

  static String vehicleImage(Map<String, dynamic>? profile) {
    final raw = profile?['vehicleImage'] ?? profile?['bikeImage'];
    return raw?.toString().trim() ?? '';
  }

  static bool isTripleName(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
    return parts.length >= 3;
  }

  static bool isComplete(Map<String, dynamic>? profile) {
    return name(profile).isNotEmpty &&
        phone(profile).isNotEmpty &&
        homeAddress(profile).isNotEmpty &&
        vehicleImage(profile).isNotEmpty;
  }

  static bool isApproved(Map<String, dynamic>? profile) =>
      profile?['isApproved'] == true;

  static String approvalStatus(Map<String, dynamic>? profile) {
    if (isApproved(profile)) return 'approved';
    final status = profile?['approvalStatus']?.toString().trim();
    if (status == 'rejected') return 'rejected';
    return 'pending';
  }

  static bool isRejected(Map<String, dynamic>? profile) =>
      approvalStatus(profile) == 'rejected';

  static String rejectionMessage(Map<String, dynamic>? profile) =>
      profile?['rejectionMessageAr']?.toString().trim() ?? '';
}
