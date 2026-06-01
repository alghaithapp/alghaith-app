import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'cloudflare_service.dart';
import 'supabase_service.dart';

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

  /// رفع مع احتياط: Worker → Supabase Storage → Base64 مضغوط.
  static Future<String?> uploadImageFile(
    File file, {
    String bucket = 'uploads',
  }) async {
    final cloudUrl = await CloudflareService.uploadFile(file, bucket: bucket);
    if (cloudUrl != null && cloudUrl.trim().isNotEmpty) {
      return cloudUrl.trim();
    }

    final storageUrl = await SupabaseService.uploadImage(
      bucket,
      'profiles/${DateTime.now().millisecondsSinceEpoch}',
      file,
    );
    if (storageUrl != null && storageUrl.trim().isNotEmpty) {
      return storageUrl.trim();
    }

    final base64 = await encodeFileAsBase64(file);
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
