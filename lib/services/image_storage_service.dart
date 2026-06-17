import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:path/path.dart' as p;

import 'cloudflare_service.dart';

/// مرجع صورة: رابط عام (مفضّل) أو Base64 مضغوط كاحتياط.
class ImageStorageService {
  const ImageStorageService._();

  static const int _maxBase64Bytes = 900 * 1024;

  static bool isRemoteUrl(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.startsWith('http://') || trimmed.startsWith('https://');
  }

  static bool isBase64Image(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return false;
    if (isRemoteUrl(trimmed)) return false;
    var payload = trimmed;
    if (payload.contains('base64,')) {
      payload = payload.split('base64,').last;
    }
    return payload.startsWith('iVBOR') ||
        payload.startsWith('/9j/') ||
        payload.startsWith('R0lG') ||
        payload.startsWith('UklGR') ||
        payload.length > 80;
  }

  /// رفع: ضغط الصورة أولاً ثم الرفع إلى Cloudflare Worker.
  static Future<String?> uploadImageFile(
    File file, {
    String bucket = 'uploads',
  }) async {
    File fileToUpload = file;
    try {
      final compressed = await compressImage(file);
      if (compressed != null) {
        fileToUpload = compressed;
        debugPrint(
          'IMAGE_STORAGE: Compressed from ${file.lengthSync()} to ${compressed.lengthSync()} bytes',
        );
      }
    } catch (e) {
      debugPrint('IMAGE_STORAGE_COMPRESS_ERROR: $e');
    }

    final cloudUrl = await CloudflareService.uploadFile(fileToUpload, bucket: bucket);
    if (cloudUrl != null && cloudUrl.trim().isNotEmpty) {
      return cloudUrl.trim();
    }

    final base64 = await encodeFileAsBase64(fileToUpload);
    if (base64 != null) {
      debugPrint('IMAGE_STORAGE: Using Base64 fallback (${base64.length} chars)');
    }
    return base64;
  }

  /// ضغط الصورة لتقليل الباندويث والمساحة.
  static Future<File?> compressImage(File file) async {
    try {
      final tempDir = await path_provider.getTemporaryDirectory();
      final targetPath = p.join(
        tempDir.path,
        '${DateTime.now().millisecondsSinceEpoch}_compressed.jpg',
      );

      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 80,
        minWidth: 1024,
        minHeight: 1024,
        format: CompressFormat.jpeg,
      );

      if (result == null) return null;
      return File(result.path);
    } catch (e) {
      debugPrint('IMAGE_COMPRESSION_FAILED: $e');
      return null;
    }
  }

  static Future<String?> encodeFileAsBase64(File file) async {
    try {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return null;
      if (bytes.length > _maxBase64Bytes) {
        debugPrint(
          'IMAGE_STORAGE: File too large for Base64 fallback (${bytes.length} bytes)',
        );
        return null;
      }
      return base64Encode(bytes);
    } catch (error) {
      debugPrint('IMAGE_STORAGE_BASE64_ERROR: $error');
      return null;
    }
  }

  /// يجهّز حقول الحفظ في Supabase للصور (رابط أو Base64).
  static Map<String, dynamic> customerAvatarFields(String? imageRef) {
    final value = imageRef?.trim();
    if (value == null || value.isEmpty) return {};
    return {
      'avatar_base64': value,
      'customer_avatar_base64': value,
    };
  }

  static Map<String, dynamic> merchantImageFields({
    String? profileRef,
    String? coverRef,
    String? logoRef,
    List<String>? workSamples,
  }) {
    final payload = <String, dynamic>{};

    void assignProfile(String? ref) {
      final value = ref?.trim();
      if (value == null || value.isEmpty) return;
      payload['profile_image_base64'] = value;
      payload['profileImageBase64'] = value;
    }

    void assignCover(String? ref) {
      final value = ref?.trim();
      if (value == null || value.isEmpty) return;
      if (isRemoteUrl(value)) {
        payload['cover_image_url'] = value;
        payload['coverImage'] = value;
      } else {
        payload['cover_image_url'] = value;
        payload['coverImageBase64'] = value;
      }
    }

    void assignLogo(String? ref) {
      final value = ref?.trim();
      if (value == null || value.isEmpty) return;
      if (isRemoteUrl(value)) {
        payload['logo_image_url'] = value;
        payload['logoImage'] = value;
      } else {
        payload['logo_image_url'] = value;
        payload['logoImageBase64'] = value;
      }
    }

    assignProfile(profileRef);
    assignCover(coverRef);
    assignLogo(logoRef);

    if (workSamples != null && workSamples.isNotEmpty) {
      payload['work_sample_images_base64'] = workSamples;
      payload['workSampleImagesBase64'] = workSamples;
    }

    return payload;
  }

  static Map<String, dynamic> productImageFields(String? imageRef, {String? fallbackAsset}) {
    final value = imageRef?.trim();
    if (value == null || value.isEmpty) {
      return {
        if (fallbackAsset != null && fallbackAsset.isNotEmpty) 'image': fallbackAsset,
      };
    }
    if (isRemoteUrl(value)) {
      return {
        'image': value,
        'image_base64': value,
      };
    }
    return {
      'image': fallbackAsset ?? '',
      'image_base64': value,
    };
  }

  static String? normalizeImageRef(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    if (isRemoteUrl(trimmed)) return trimmed;
    return trimmed;
  }

  /// صور مدمجة في التطبيق (ليست رفع المستخدم).
  static bool isBundledAssetImage(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.startsWith('assets/');
  }

  /// صورة رفعها التاجر (رابط أو Base64) — تستبعد مسارات assets الافتراضية.
  static bool isMerchantUploadedImage(String? value) {
    final ref = normalizeImageRef(value);
    if (ref == null || ref.isEmpty) return false;
    if (isBundledAssetImage(ref)) return false;
    return isRemoteUrl(ref) || isBase64Image(ref);
  }

  static String? merchantUploadedImageRef(String? value) {
    return isMerchantUploadedImage(value) ? normalizeImageRef(value) : null;
  }

  static String? resolveDisplayImage({
    String? imageBase64,
    String? image,
    String? imageUrl,
  }) {
    final primary = imageBase64?.trim();
    if (primary != null && primary.isNotEmpty) return primary;
    final url = imageUrl?.trim();
    if (url != null && url.isNotEmpty) return url;
    final path = image?.trim();
    if (path != null && path.isNotEmpty) return path;
    return null;
  }
}
