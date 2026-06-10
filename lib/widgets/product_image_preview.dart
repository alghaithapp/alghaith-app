import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app_image.dart';

void showProductImagePreview(
  BuildContext context, {
  required String? imageData,
  String? title,
}) {
  final source = imageData?.trim() ?? '';
  if (source.isEmpty) return;

  Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, animation, secondaryAnimation) {
        return FadeTransition(
          opacity: animation,
          child: _ProductImagePreviewPage(
            imageData: source,
            title: title,
          ),
        );
      },
    ),
  );
}

class _ProductImagePreviewPage extends StatelessWidget {
  final String imageData;
  final String? title;

  const _ProductImagePreviewPage({
    required this.imageData,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).maybePop(),
                child: const ColoredBox(color: Colors.transparent),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 56),
                child: Hero(
                  tag: 'product-preview-$imageData',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      child: AppImage(
                        imageData: imageData,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.of(context).maybePop(),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.22),
                    ),
                  ),
                  child: const Icon(
                    CupertinoIcons.xmark,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
            if (title != null && title!.trim().isNotEmpty)
              Positioned(
                left: 20,
                right: 20,
                bottom: 16,
                child: Text(
                  title!.trim(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ProductFavoriteCornerButton extends StatelessWidget {
  final bool isFavorite;
  final VoidCallback onTap;
  final Color activeColor;

  const ProductFavoriteCornerButton({
    super.key,
    required this.isFavorite,
    required this.onTap,
    this.activeColor = const Color(0xFFF5A01D),
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              key: ValueKey(isFavorite),
              size: 18,
              color: isFavorite ? activeColor : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }
}
