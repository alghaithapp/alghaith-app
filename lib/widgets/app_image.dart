import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';

class AppImage extends StatelessWidget {
  final String? imageData; // يمكن أن يكون URL أو Base64 أو Asset Path
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
    final Widget imageWidget = _buildImage();
    
    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: SizedBox(width: width, height: height, child: imageWidget),
      );
    }
    
    return SizedBox(width: width, height: height, child: imageWidget);
  }

  Widget _buildImage() {
    if (imageData == null || imageData!.isEmpty) {
      return _buildPlaceholder();
    }

    // 1. التحقق إذا كان رابط إنترنت (Cloudflare URL)
    if (imageData!.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: imageData!,
        fit: fit,
        placeholder: (context, url) => _buildLoading(),
        errorWidget: (context, url, error) => _buildError(),
      );
    }

    // 2. التحقق إذا كان Base64
    if (imageData!.startsWith('iVBOR') || imageData!.startsWith('/9j/') || imageData!.length > 100) {
      try {
        return Image.memory(
          base64Decode(imageData!),
          fit: fit,
          errorBuilder: (context, error, stackTrace) => _buildError(),
        );
      } catch (e) {
        return _buildError();
      }
    }

    // 3. التحقق إذا كان Asset Path
    if (imageData!.startsWith('assets/')) {
      return Image.asset(
        imageData!,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _buildError(),
      );
    }

    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: const Icon(CupertinoIcons.photo, color: Colors.grey),
    );
  }

  Widget _buildLoading() {
    return Container(
      color: Colors.grey[100],
      child: const Center(
        child: CupertinoActivityIndicator(),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      color: Colors.red[50],
      child: const Icon(Icons.broken_image_rounded, color: Colors.redAccent),
    );
  }
}
