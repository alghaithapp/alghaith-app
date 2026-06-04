import 'dart:async';

import 'package:flutter/material.dart';

/// بانر علوي قابل للنقر؛ يُعاد [true] إذا نقر المستخدم (يُعتبر مقروءاً).
Future<bool> showInAppNotificationBanner({
  required BuildContext context,
  required String title,
  required String body,
  required Color accentColor,
  required IconData icon,
  Duration autoHide = const Duration(seconds: 4),
}) async {
  final overlay = Overlay.of(context, rootOverlay: true);
  final completer = Completer<bool>();
  late OverlayEntry entry;
  var dismissed = false;

  void finish(bool tapped) {
    if (dismissed) return;
    dismissed = true;
    entry.remove();
    if (!completer.isCompleted) completer.complete(tapped);
  }

  entry = OverlayEntry(
    builder: (ctx) => _InAppBannerOverlay(
      title: title,
      body: body,
      accentColor: accentColor,
      icon: icon,
      onTap: () => finish(true),
      onDismiss: () => finish(false),
    ),
  );

  overlay.insert(entry);
  Timer(autoHide, () => finish(false));
  return completer.future;
}

class _InAppBannerOverlay extends StatefulWidget {
  final String title;
  final String body;
  final Color accentColor;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _InAppBannerOverlay({
    required this.title,
    required this.body,
    required this.accentColor,
    required this.icon,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<_InAppBannerOverlay> createState() => _InAppBannerOverlayState();
}

class _InAppBannerOverlayState extends State<_InAppBannerOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _dismiss({required bool tapped}) async {
    await _ctrl.reverse();
    if (tapped) {
      widget.onTap();
    } else {
      widget.onDismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top + 12;
    return Positioned(
      top: top,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slide,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: () => _dismiss(tapped: true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    widget.accentColor,
                    widget.accentColor.withValues(alpha: 0.85),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: widget.accentColor.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(widget.icon, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            fontFamily: 'Cairo',
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _dismiss(tapped: false),
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
