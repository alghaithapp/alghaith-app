import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

class AppHelpers {
  static const String supportWhatsAppNumber = '9647701234567';

  static Future<void> launchWhatsApp(String phone, String message) async {
    final targetPhone = phone.isNotEmpty ? phone : supportWhatsAppNumber;
    final encodedMessage = Uri.encodeComponent(message);
    final urls = [
      Uri.parse("https://wa.me/$targetPhone?text=$encodedMessage"),
      if (Platform.isIOS)
        Uri.parse("whatsapp://send?phone=$targetPhone&text=$encodedMessage"),
    ];

    for (final uri in urls) {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    await launchUrl(
      Uri.parse("https://wa.me/$targetPhone?text=$encodedMessage"),
      mode: LaunchMode.externalApplication,
    );
  }

  static Future<void> makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    await launchUrl(launchUri);
  }

  static Future<void> openExternalMapNavigation({
    required double latitude,
    required double longitude,
  }) async {
    final googleUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude&travelmode=driving',
    );
    final geoUri = Uri.parse('geo:$latitude,$longitude?q=$latitude,$longitude');

    if (await canLaunchUrl(geoUri)) {
      await launchUrl(geoUri, mode: LaunchMode.externalApplication);
      return;
    }
    await launchUrl(googleUri, mode: LaunchMode.externalApplication);
  }

  static Future<void> launchEmail({
    required String email,
    String subject = '',
    String body = '',
  }) async {
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {
        if (subject.isNotEmpty) 'subject': subject,
        if (body.isNotEmpty) 'body': body,
      },
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// خيار التقاط صورة أو اختيارها من الاستوديو
  static Future<XFile?> pickImage(BuildContext context) async {
    final ImagePicker picker = ImagePicker();
    ImageSource? source;

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: const Text(
          'إضافة صورة',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
        ),
        message: const Text(
          'اختر مصدر الصورة التي تريد رفعها',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.camera_fill, color: Colors.orange),
                SizedBox(width: 10),
                Text('الكاميرا', style: TextStyle(fontFamily: 'Cairo')),
              ],
            ),
            onPressed: () {
              source = ImageSource.camera;
              Navigator.pop(context);
            },
          ),
          CupertinoActionSheetAction(
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.photo_fill, color: Colors.orange),
                SizedBox(width: 10),
                Text('الاستوديو / ملفات', style: TextStyle(fontFamily: 'Cairo')),
              ],
            ),
            onPressed: () {
              source = ImageSource.gallery;
              Navigator.pop(context);
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء',
              style: TextStyle(fontFamily: 'Cairo', color: Colors.red)),
        ),
      ),
    );

    if (source != null) {
      return await picker.pickImage(
        source: source!,
        imageQuality: 85,
      );
    }
    return null;
  }

  /// خيار اختيار صور متعددة
  static Future<List<XFile>> pickMultiImage(BuildContext context) async {
    final ImagePicker picker = ImagePicker();
    bool useGallery = false;
    bool useCamera = false;

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: const Text(
          'إضافة صور متعددة',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
        ),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.camera_fill, color: Colors.orange),
                SizedBox(width: 10),
                Text('الكاميرا (صورة واحدة)',
                    style: TextStyle(fontFamily: 'Cairo')),
              ],
            ),
            onPressed: () {
              useCamera = true;
              Navigator.pop(context);
            },
          ),
          CupertinoActionSheetAction(
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.photo_fill, color: Colors.orange),
                SizedBox(width: 10),
                Text('اختيار صور من الاستوديو',
                    style: TextStyle(fontFamily: 'Cairo')),
              ],
            ),
            onPressed: () {
              useGallery = true;
              Navigator.pop(context);
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء',
              style: TextStyle(fontFamily: 'Cairo', color: Colors.red)),
        ),
      ),
    );

    if (useGallery) {
      return await picker.pickMultiImage(imageQuality: 85);
    } else if (useCamera) {
      final XFile? file =
          await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (file != null) return [file];
    }
    return const [];
  }
}

