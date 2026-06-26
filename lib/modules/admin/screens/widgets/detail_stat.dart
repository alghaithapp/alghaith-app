import 'package:flutter/material.dart';

class DetailStat extends StatelessWidget {
  final String label;
  final String value;
  final bool isMoney;

  const DetailStat({
    super.key,
    required this.label,
    required this.value,
    this.isMoney = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: isMoney ? 13 : 18,
              color: const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 2),
          Text(label,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 10,
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
