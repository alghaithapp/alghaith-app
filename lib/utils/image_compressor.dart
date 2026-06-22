import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class ImageCompressor {
  static Future<File> compress(File file, {int maxWidth = 1024, int maxHeight = 1024, int quality = 70}) async {
    final ext = file.path.split('.').last.toLowerCase();
    if (!['jpg', 'jpeg', 'png', 'webp'].contains(ext)) return file;

    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      '${file.absolute.path}.compressed.${ext == 'png' ? 'png' : 'jpg'}',
      minWidth: maxWidth,
      minHeight: maxHeight,
      quality: quality,
      format: ext == 'png' ? CompressFormat.png : CompressFormat.jpeg,
    );

    if (result == null) return file;
    return File(result.path);
  }

  static Future<Uint8List?> compressBytes(Uint8List bytes, {int maxWidth = 1024, int maxHeight = 1024, int quality = 70}) async {
    return await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: maxWidth,
      minHeight: maxHeight,
      quality: quality,
    );
  }
}
