enum AdminRole {
  superAdmin,
  admin,
  moderator,
  financeViewer,
  contentManager,
  support,
}

extension AdminRoleX on AdminRole {
  String get key {
    switch (this) {
      case AdminRole.superAdmin:
        return 'super_admin';
      case AdminRole.admin:
        return 'admin';
      case AdminRole.moderator:
        return 'moderator';
      case AdminRole.financeViewer:
        return 'finance_viewer';
      case AdminRole.contentManager:
        return 'content_manager';
      case AdminRole.support:
        return 'support';
    }
  }

  String get label {
    switch (this) {
      case AdminRole.superAdmin:
        return 'مشرف عام';
      case AdminRole.admin:
        return 'مشرف';
      case AdminRole.moderator:
        return 'مدقق';
      case AdminRole.financeViewer:
        return 'مشرف مالي';
      case AdminRole.contentManager:
        return 'مدير محتوى';
      case AdminRole.support:
        return 'دعم';
    }
  }

  int get level {
    switch (this) {
      case AdminRole.superAdmin:
        return 100;
      case AdminRole.admin:
        return 80;
      case AdminRole.moderator:
        return 60;
      case AdminRole.financeViewer:
        return 40;
      case AdminRole.contentManager:
        return 40;
      case AdminRole.support:
        return 20;
    }
  }

  static AdminRole? fromKey(String? key) {
    switch (key?.trim()) {
      case 'super_admin':
        return AdminRole.superAdmin;
      case 'admin':
        return AdminRole.admin;
      case 'moderator':
        return AdminRole.moderator;
      case 'finance_viewer':
        return AdminRole.financeViewer;
      case 'content_manager':
        return AdminRole.contentManager;
      case 'support':
        return AdminRole.support;
      default:
        return null;
    }
  }
}

enum AdminPermission {
  manageAdmins,
  moderateMerchants,
  moderateCouriers,
  moderateDrivers,
  viewFinance,
  manageContent,
  manageAppUpdate,
  deleteAccounts,
  changeRoles,
  viewAuditLog,
}

Set<AdminPermission> permissionsForRole(AdminRole role) {
  switch (role) {
    case AdminRole.superAdmin:
      return AdminPermission.values.toSet();
    case AdminRole.admin:
      return {
        AdminPermission.moderateMerchants,
        AdminPermission.moderateCouriers,
        AdminPermission.moderateDrivers,
        AdminPermission.viewFinance,
        AdminPermission.manageContent,
        AdminPermission.manageAppUpdate,
        AdminPermission.deleteAccounts,
        AdminPermission.changeRoles,
        AdminPermission.viewAuditLog,
      };
    case AdminRole.moderator:
      return {
        AdminPermission.moderateMerchants,
        AdminPermission.moderateCouriers,
        AdminPermission.moderateDrivers,
      };
    case AdminRole.financeViewer:
      return {AdminPermission.viewFinance};
    case AdminRole.contentManager:
      return {
        AdminPermission.manageContent,
        AdminPermission.manageAppUpdate,
      };
    case AdminRole.support:
      return {AdminPermission.viewAuditLog};
  }
}
