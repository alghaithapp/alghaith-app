import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// أزرار تنقّل موحّدة لصفحات الخدمات (رجوع + تحديث).
class ServiceNavIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool isLoading;
  final Color? iconColor;
  final double size;

  const ServiceNavIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.isLoading = false,
    this.iconColor,
    this.size = 42,
  });

  @override
  Widget build(BuildContext context) {
    final iconWidget = isLoading
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: AppColors.accent,
            ),
          )
        : Icon(
            icon,
            size: 19,
            color: iconColor ?? AppColors.textPrimary,
          );

    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.accent.withValues(alpha: 0.16),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.07),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(child: iconWidget),
        ),
      ),
    );

    if (tooltip == null || tooltip!.isEmpty) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

class ServiceBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool hide;

  const ServiceBackButton({super.key, this.onPressed, this.hide = false});

  @override
  Widget build(BuildContext context) {
    if (hide) return const SizedBox.shrink();
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed ?? () => Navigator.of(context).maybePop(),
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.accent.withValues(alpha: 0.15),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              isRtl
                  ? Icons.arrow_forward_ios_rounded
                  : Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: AppColors.accent,
            ),
          ),
        ),
      ),
    );
  }
}

class ServiceRefreshButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;

  const ServiceRefreshButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return ServiceNavIconButton(
      icon: Icons.sync_rounded,
      tooltip: 'تحديث',
      onPressed: onPressed,
      isLoading: isLoading,
    );
  }
}

class ServiceNavigationBar extends StatelessWidget
    implements ObstructingPreferredSizeWidget {
  final String title;
  final VoidCallback? onRefresh;
  final bool isRefreshing;
  final Widget? trailing;
  final VoidCallback? onBack;
  final bool hideBack;

  const ServiceNavigationBar({
    super.key,
    required this.title,
    this.onRefresh,
    this.isRefreshing = false,
    this.trailing,
    this.onBack,
    this.hideBack = false,
  }) : assert(
          onRefresh == null || trailing == null,
          'Use either onRefresh or trailing, not both.',
        );

  @override
  Size get preferredSize => const Size.fromHeight(44);

  @override
  bool shouldFullyObstruct(BuildContext context) => true;

  @override
  Widget build(BuildContext context) {
    Widget? trailingWidget = trailing;
    if (trailingWidget == null && onRefresh != null) {
      trailingWidget = ServiceRefreshButton(
        onPressed: onRefresh,
        isLoading: isRefreshing,
      );
    }

    return CupertinoNavigationBar(
      border: null,
      transitionBetweenRoutes: true,
      leading: Padding(
        padding: const EdgeInsetsDirectional.only(start: 6),
        child: ServiceBackButton(onPressed: onBack, hide: hideBack),
      ),
      middle: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontFamily: 'Cairo',
          fontSize: 17,
        ),
      ),
      trailing: trailingWidget == null
          ? null
          : Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: trailingWidget,
            ),
    );
  }
}
