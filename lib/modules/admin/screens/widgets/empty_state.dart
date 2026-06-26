import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  final String text;
  const EmptyState({super.key, required this.text});
  @override
  Widget build(BuildContext context) => Center(child: Text(text, style: const TextStyle(color: Colors.grey, fontFamily: 'Cairo')));
}
