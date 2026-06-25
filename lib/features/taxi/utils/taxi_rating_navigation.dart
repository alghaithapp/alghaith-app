import 'package:flutter/material.dart';

import '../models/taxi_request.dart';
import '../screens/customer/taxi_rating_screen.dart';

/// فتح شاشة التقييم مرة واحدة لكل رحلة.
class TaxiRatingNavigation {
  static String? _openForRequestId;

  static Future<void> openIfNeeded(
    BuildContext context,
    TaxiRequest request,
  ) async {
    final id = request.id.trim();
    if (id.isEmpty || _openForRequestId == id) return;
    _openForRequestId = id;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TaxiRatingScreen(request: request),
        fullscreenDialog: true,
      ),
    );

    if (_openForRequestId == id) {
      _openForRequestId = null;
    }
  }
}
