import 'package:latlong2/latlong.dart';

import 'taxi_distance_calculator.dart';

/// عند الاقتراب من الوجهة على الجانب الآخر من الشارع قد يُطيل الموجّه المسار
/// لاستدارة قانونية. نُنهي المسار عند أول نقطة ضمن هذه العتبة.
const double routeNearDestinationTrimMeters = 200;

class RouteDestinationTrimResult {
  final List<LatLng> points;
  final double distanceMeters;
  final int? durationSeconds;
  final bool trimmed;

  const RouteDestinationTrimResult({
    required this.points,
    required this.distanceMeters,
    this.durationSeconds,
    this.trimmed = false,
  });
}

RouteDestinationTrimResult trimRouteNearDestination({
  required List<LatLng> points,
  required LatLng destination,
  double thresholdMeters = routeNearDestinationTrimMeters,
  double? distanceMeters,
  int? durationSeconds,
}) {
  if (points.length < 2) {
    final meters = distanceMeters ?? 0;
    return RouteDestinationTrimResult(
      points: points,
      distanceMeters: meters,
      durationSeconds: durationSeconds,
    );
  }

  final originalDistance = (distanceMeters != null && distanceMeters > 0)
      ? distanceMeters
      : _distanceAlongPolyline(points);

  final near = _findFirstNearPointOnRoute(points, destination, thresholdMeters);
  if (near == null) {
    return RouteDestinationTrimResult(
      points: points,
      distanceMeters: originalDistance,
      durationSeconds: durationSeconds,
    );
  }

  final tailDistance = _distanceAlongPolyline(points.sublist(near.cutIndex + 1));
  if (tailDistance < 30) {
    return RouteDestinationTrimResult(
      points: points,
      distanceMeters: originalDistance,
      durationSeconds: durationSeconds,
    );
  }

  final trimmedPoints = <LatLng>[
    ...points.sublist(0, near.cutIndex + 1),
    near.cutPoint,
    destination,
  ];
  final trimmedDistance = near.distanceAlongMeters + near.remainderMeters;

  int? trimmedDuration = durationSeconds;
  if (durationSeconds != null && originalDistance > 0) {
    final ratio = (trimmedDistance / originalDistance).clamp(0.0, 1.0);
    trimmedDuration = (durationSeconds * ratio).round().clamp(30, durationSeconds);
  }

  return RouteDestinationTrimResult(
    points: trimmedPoints,
    distanceMeters: trimmedDistance,
    durationSeconds: trimmedDuration,
    trimmed: true,
  );
}

class _NearCut {
  final LatLng cutPoint;
  final double distanceAlongMeters;
  final double remainderMeters;
  final int cutIndex;

  const _NearCut({
    required this.cutPoint,
    required this.distanceAlongMeters,
    required this.remainderMeters,
    required this.cutIndex,
  });
}

_NearCut? _findFirstNearPointOnRoute(
  List<LatLng> points,
  LatLng destination,
  double thresholdMeters,
) {
  var accumulatedMeters = 0.0;

  for (var i = 0; i < points.length; i++) {
    final point = points[i];
    final pointDistance = _distanceMeters(point, destination);
    if (pointDistance <= thresholdMeters) {
      return _NearCut(
        cutPoint: point,
        distanceAlongMeters: accumulatedMeters,
        remainderMeters: pointDistance,
        cutIndex: i,
      );
    }

    if (i >= points.length - 1) continue;

    final next = points[i + 1];
    final segmentMeters = _distanceMeters(point, next);
    if (segmentMeters <= 0) continue;

    final steps = (segmentMeters / 8).ceil().clamp(12, 80);
    for (var step = 1; step <= steps; step++) {
      final t = step / steps;
      final sample = LatLng(
        point.latitude + (next.latitude - point.latitude) * t,
        point.longitude + (next.longitude - point.longitude) * t,
      );
      final sampleDistance = _distanceMeters(sample, destination);
      if (sampleDistance <= thresholdMeters) {
        return _NearCut(
          cutPoint: sample,
          distanceAlongMeters: accumulatedMeters + segmentMeters * t,
          remainderMeters: sampleDistance,
          cutIndex: i,
        );
      }
    }

    accumulatedMeters += segmentMeters;
  }

  return null;
}

double _distanceAlongPolyline(List<LatLng> points) {
  if (points.length < 2) return 0;
  var total = 0.0;
  for (var i = 1; i < points.length; i++) {
    total += _distanceMeters(points[i - 1], points[i]);
  }
  return total;
}

double _distanceMeters(LatLng a, LatLng b) {
  return TaxiDistanceCalculator.calculateDistance(
        a.latitude,
        a.longitude,
        b.latitude,
        b.longitude,
      ) *
      1000;
}
