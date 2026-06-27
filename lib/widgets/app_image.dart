import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../services/image_storage_service.dart';

class AppImage extends StatelessWidget {
  final String? imageData;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const AppImage({
    super.key,
    this.imageData,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  int _preferredWidthForVariant() {
    final w = width;
    if (w == null || !w.isFinite || w <= 0) return 256;
    return w.round().clamp(64, 1024);
  }

  double? _finiteDimension(double? value) {
    if (value == null || !value.isFinite) return null;
    return value;
  }

  double _errorIconSize() {
    final w = _finiteDimension(width);
    final h = _finiteDimension(height);
    if (w == null || h == null) return 32;
    return (w < h ? w : h) * 0.55;
  }

  @override
  Widget build(BuildContext context) {
    final normalized = ImageStorageService.normalizeImageRef(imageData);
    final displayUrl = ImageStorageService.pickVariantUrl(
      normalized,
      preferredWidth: _preferredWidthForVariant(),
    );
    final layoutWidth = _finiteDimension(width);
    final layoutHeight = _finiteDimension(height);
    final imageWidget = _buildImage(displayUrl, layoutWidth, layoutHeight);

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: SizedBox(
          width: layoutWidth,
          height: layoutHeight,
          child: imageWidget,
        ),
      );
    }

    return SizedBox(
      width: layoutWidth,
      height: layoutHeight,
      child: imageWidget,
    );
  }

  Widget _buildImage(String? normalizedData, double? layoutWidth, double? layoutHeight) {
    if (normalizedData == null || normalizedData.isEmpty) {
      return _buildPlaceholder(layoutWidth, layoutHeight);
    }

    if (ImageStorageService.isRemoteUrl(normalizedData)) {
      return _buildNetworkImage(normalizedData, layoutWidth, layoutHeight);
    }

    var base64String = normalizedData;
    if (base64String.contains('base64,')) {
      base64String = base64String.split('base64,').last;
    }

    if (base64String.startsWith('iVBOR') ||
        base64String.startsWith('/9j/') ||
        base64String.startsWith('R0lG') ||
        base64String.startsWith('UklGR')) {
      try {
        return Image.memory(
          base64Decode(base64String),
          width: layoutWidth,
          height: layoutHeight,
          fit: fit,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) =>
              _buildError(layoutWidth, layoutHeight),
        );
      } catch (e) {
        debugPrint('AppImage Base64 Error: $e');
        return _buildError(layoutWidth, layoutHeight);
      }
    }

    if (normalizedData.startsWith('assets/')) {
      return Image.asset(
        normalizedData,
        width: layoutWidth,
        height: layoutHeight,
        fit: fit,
        errorBuilder: (context, error, stackTrace) =>
            _buildError(layoutWidth, layoutHeight),
      );
    }

    return _buildPlaceholder(layoutWidth, layoutHeight);
  }

  Widget _buildNetworkImage(
    String url,
    double? layoutWidth,
    double? layoutHeight,
  ) {
    return CachedNetworkImage(
      imageUrl: url,
      cacheKey: url,
      width: layoutWidth,
      height: layoutHeight,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 120),
      fadeOutDuration: const Duration(milliseconds: 80),
      placeholder: (context, _) => _buildLoading(layoutWidth, layoutHeight),
      errorWidget: (context, _, error) {
        debugPrint('AppImage network error for $url: $error');
        return Image.network(
          url,
          width: layoutWidth,
          height: layoutHeight,
          fit: fit,
          errorBuilder: (context, _, __) =>
              _buildError(layoutWidth, layoutHeight),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _buildLoading(layoutWidth, layoutHeight);
          },
        );
      },
    );
  }

  Widget _buildPlaceholder(double? layoutWidth, double? layoutHeight) {
    return Container(
      width: layoutWidth,
      height: layoutHeight,
      color: Colors.grey[200],
      child: const Icon(CupertinoIcons.person_fill, color: Colors.grey),
    );
  }

  Widget _buildLoading(double? layoutWidth, double? layoutHeight) {
    return Container(
      width: layoutWidth,
      height: layoutHeight,
      color: Colors.grey[100],
      child: const Center(child: CupertinoActivityIndicator()),
    );
  }

  Widget _buildError(double? layoutWidth, double? layoutHeight) {
    return Container(
      width: layoutWidth,
      height: layoutHeight,
      color: Colors.orange.shade50,
      child: Icon(
        CupertinoIcons.person_crop_circle,
        color: Colors.orange.shade300,
        size: _errorIconSize(),
      ),
    );
  }
}
