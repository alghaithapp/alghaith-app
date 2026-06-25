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

  @override
  Widget build(BuildContext context) {
    final imageWidget = _buildImage(ImageStorageService.normalizeImageRef(imageData));

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: SizedBox(width: width, height: height, child: imageWidget),
      );
    }

    return SizedBox(width: width, height: height, child: imageWidget);
  }

  Widget _buildImage(String? normalizedData) {
    if (normalizedData == null || normalizedData.isEmpty) {
      return _buildPlaceholder();
    }

    if (ImageStorageService.isRemoteUrl(normalizedData)) {
      return _buildNetworkImage(normalizedData);
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
          width: width,
          height: height,
          fit: fit,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => _buildError(),
        );
      } catch (e) {
        debugPrint('AppImage Base64 Error: $e');
        return _buildError();
      }
    }

    if (normalizedData.startsWith('assets/')) {
      return Image.asset(
        normalizedData,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _buildError(),
      );
    }

    return _buildPlaceholder();
  }

  Widget _buildNetworkImage(String url) {
    return CachedNetworkImage(
      imageUrl: url,
      cacheKey: url,
      width: width,
      height: height,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 120),
      fadeOutDuration: const Duration(milliseconds: 80),
      placeholder: (context, _) => _buildLoading(),
      errorWidget: (context, _, error) {
        debugPrint('AppImage network error for $url: $error');
        return Image.network(
          url,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, _, __) => _buildError(),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _buildLoading();
          },
        );
      },
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: const Icon(CupertinoIcons.person_fill, color: Colors.grey),
    );
  }

  Widget _buildLoading() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[100],
      child: const Center(child: CupertinoActivityIndicator()),
    );
  }

  Widget _buildError() {
    return Container(
      width: width,
      height: height,
      color: Colors.orange.shade50,
      child: Icon(
        CupertinoIcons.person_crop_circle,
        color: Colors.orange.shade300,
        size: (width != null && height != null)
            ? (width! < height! ? width! * 0.55 : height! * 0.55)
            : 32,
      ),
    );
  }
}
