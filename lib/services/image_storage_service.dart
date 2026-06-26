import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../data/repositories/database_repository.dart';
import '../utils/image_compressor.dart';
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

  /// رفع: ضغط الصورة أولاً ثم الرفع عبر الـ backend (variants) أو Cloudflare.
  static Future<String?> uploadImageFile(
    File file, {
    String bucket = 'uploads',
    String role = 'gallery',
    String ownerType = 'user',
    String? ownerId,
  }) async {
    File fileToUpload = file;
    try {
      final compressed = await ImageCompressor.compress(file);
      fileToUpload = compressed;
      debugPrint(
        'IMAGE_STORAGE: Compressed from ${file.lengthSync()} to ${compressed.lengthSync()} bytes',
      );
    } catch (e) {
      debugPrint('IMAGE_STORAGE_COMPRESS_ERROR: $e');
    }

    try {
      final bytes = await fileToUpload.readAsBytes();
      if (bytes.isNotEmpty) {
        final backendUrl = await DatabaseRepository.instance.uploadMediaImage(
          imageBase64: base64Encode(bytes),
          ownerType: ownerType,
          ownerId: ownerId,
          role: role,
        );
        if (backendUrl != null && backendUrl.trim().isNotEmpty) {
          return backendUrl.trim();
        }
      }
    } catch (e) {
      debugPrint('IMAGE_STORAGE_BACKEND_ERROR: $e');
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
      if (isRemoteUrl(value)) {
        payload['profile_image_url'] = value;
        payload['profileImageUrl'] = value;
        return;
      }
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
        'image_url': value,
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

  /// يختار نسخة أصغر من صورة R2 المرفوعة عبر `/db/media/upload` عند العرض.
  static String? pickVariantUrl(
    String? url, {
    int preferredWidth = 256,
  }) {
    final trimmed = url?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    if (!isRemoteUrl(trimmed)) return trimmed;
    if (!trimmed.contains('/media/')) return trimmed;

    final variant = preferredWidth <= 128
        ? 'thumbnail'
        : preferredWidth <= 256
            ? '256'
            : '512';
    for (final candidate in [variant, '256', 'thumbnail', '512', 'original']) {
      final swapped = trimmed.replaceFirst(
        RegExp(r'/(original|512|256|thumbnail)\.webp(\?.*)?$'),
        '/$candidate.webp',
      );
      if (swapped != trimmed) return swapped;
    }
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
    final url = imageUrl?.trim();
    if (url != null && url.isNotEmpty && isRemoteUrl(url)) return url;
    final path = image?.trim();
    if (path != null && path.isNotEmpty && isRemoteUrl(path)) return path;
    final primary = imageBase64?.trim();
    if (primary != null && primary.isNotEmpty) {
      if (isRemoteUrl(primary)) return primary;
      return primary;
    }
    if (path != null && path.isNotEmpty) return path;
    return null;
  }
}
