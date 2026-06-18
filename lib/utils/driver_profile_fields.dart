/// حقول ملف سائق التكسي — توحيد القراءة بين التطبيق والإدارة.
class DriverProfileFields {
  const DriverProfileFields._();

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

  static String vehicle(Map<String, dynamic>? profile) =>
      profile?['vehicle']?.toString().trim() ?? '';

  static String plate(Map<String, dynamic>? profile) =>
      profile?['plate']?.toString().trim() ?? '';

  static String vehicleType(Map<String, dynamic>? profile) =>
      profile?['vehicle']?.toString().trim() ?? '';

  static String area(Map<String, dynamic>? profile) {
    final raw = profile?['area'] ?? profile?['homeAddress'];
    return raw?.toString().trim() ?? '';
  }

  static String mukhtarName(Map<String, dynamic>? profile) =>
      profile?['mukhtarName']?.toString().trim() ?? '';

  static String profileImage(Map<String, dynamic>? profile) =>
      profile?['profileImage']?.toString().trim() ?? '';

  static String carImage(Map<String, dynamic>? profile) =>
      profile?['carImage']?.toString().trim() ?? '';

  static String idFrontImage(Map<String, dynamic>? profile) =>
      profile?['idFrontImage']?.toString().trim() ?? '';

  static String idBackImage(Map<String, dynamic>? profile) =>
      profile?['idBackImage']?.toString().trim() ?? '';

  static String residenceCardImage(Map<String, dynamic>? profile) =>
      profile?['residenceCardImage']?.toString().trim() ?? '';

  static bool isTripleName(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
    return parts.length >= 3;
  }

  static bool isComplete(Map<String, dynamic>? profile) {
    return name(profile).isNotEmpty &&
        phone(profile).isNotEmpty &&
        homeAddress(profile).isNotEmpty &&
        vehicleType(profile).isNotEmpty &&
        area(profile).isNotEmpty &&
        plate(profile).isNotEmpty &&
        mukhtarName(profile).isNotEmpty &&
        profileImage(profile).isNotEmpty &&
        carImage(profile).isNotEmpty &&
        idFrontImage(profile).isNotEmpty &&
        idBackImage(profile).isNotEmpty &&
        residenceCardImage(profile).isNotEmpty;
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
