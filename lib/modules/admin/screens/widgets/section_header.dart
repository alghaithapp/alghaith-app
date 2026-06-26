import 'package:flutter/material.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final Color color;
  const SectionHeader({super.key, required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 4, height: 18, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 16)),
      ],
    );
  }
}
