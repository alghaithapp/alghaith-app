import 'package:flutter/material.dart';

const accountBackground = Color(0xFFF2F2F7);
const accountHeadline = Color(0xFF1A1A1A);
const accountBodyGray = Color(0xFF6B7280);
const accountBrandRed = Color(0xFFE60012);

abstract final class AccountUi {
  static const brandGradient = LinearGradient(
    colors: [Color(0xFFFF8A00), accountBrandRed],
    begin: Alignment.centerRight,
    end: Alignment.centerLeft,
  );

  static BoxDecoration cardDecoration({double radius = 22}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
}
