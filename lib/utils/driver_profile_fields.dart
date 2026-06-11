/// حقول ملف سائق التكسي — توحيد القراءة بين التطبيق والإدارة.
class DriverProfileFields {
  const DriverProfileFields._();

  static String name(Map<String, dynamic>? profile) =>
      profile?['name']?.toString().trim() ?? '';

  static String phone(Map<String, dynamic>? profile) =>
      profile?['phone']?.toString().trim() ?? '';

  static String vehicle(Map<String, dynamic>? profile) =>
      profile?['vehicle']?.toString().trim() ?? '';

  static String plate(Map<String, dynamic>? profile) =>
      profile?['plate']?.toString().trim() ?? '';

  static String area(Map<String, dynamic>? profile) =>
      profile?['area']?.toString().trim() ?? '';

  static bool isComplete(Map<String, dynamic>? profile) {
    return name(profile).isNotEmpty &&
        phone(profile).isNotEmpty &&
        vehicle(profile).isNotEmpty &&
        plate(profile).isNotEmpty &&
        area(profile).isNotEmpty;
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
