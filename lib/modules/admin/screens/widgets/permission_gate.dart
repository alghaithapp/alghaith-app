import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/app_provider.dart';
import '../models/admin_role.dart';

class PermissionGate extends StatelessWidget {
  final AdminPermission requiredPermission;
  final Widget child;
  final Widget? fallback;

  const PermissionGate({
    super.key,
    required this.requiredPermission,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final hasPermission = provider.hasAdminPermission(requiredPermission);
    if (hasPermission) return child;
    return fallback ?? const SizedBox.shrink();
  }
}

class PermissionGuard extends StatelessWidget {
  final AdminRole minRole;
  final Widget child;
  final Widget? fallback;

  const PermissionGuard({
    super.key,
    required this.minRole,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final hasRole = provider.adminRoleLevel >= minRole.level;
    if (hasRole) return child;
    return fallback ?? const SizedBox.shrink();
  }
}
