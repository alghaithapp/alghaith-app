import 'package:flutter/material.dart';
import '../../../widgets/app_image.dart';

class AvatarPreview extends StatelessWidget {
  final String? imageBase64;
  const AvatarPreview({super.key, this.imageBase64});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: AppImage(imageData: imageBase64),
      ),
    );
  }
}
