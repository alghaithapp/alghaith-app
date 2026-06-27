/**
 * عند الاقتراب من الوجهة (على الجانب الآخر من الشارع) قد يُطيل Mapbox المسار
 * لاستدارة قانونية. نُنهي المسار عند أول نقطة ضمن عتبة قريبة ولا نحسب الاستدارة.
 */

const NEAR_DESTINATION_THRESHOLD_METERS = Number.parseInt(
  process.env.ROUTE_NEAR_DESTINATION_METERS || '200',
  10
);

function haversineDistanceMeters(origin, destination) {
  const earthRadiusMeters = 6371000;
  const toRadians = (value) => (value * Math.PI) / 180;
  const lat1 = toRadians(origin.latitude);
  const lat2 = toRadians(destination.latitude);
  const deltaLat = toRadians(destination.latitude - origin.latitude);
  const deltaLng = toRadians(destination.longitude - origin.longitude);
  const a =
    Math.sin(deltaLat / 2) * Math.sin(deltaLat / 2) +
    Math.cos(lat1) *
      Math.cos(lat2) *
      Math.sin(deltaLng / 2) *
      Math.sin(deltaLng / 2);
  return earthRadiusMeters * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function lerpPoint(a, b, t) {
  return {
    latitude: a.latitude + (b.latitude - a.latitude) * t,
    longitude: a.longitude + (b.longitude - a.longitude) * t,
  };
}

function distanceAlongPolyline(points) {
  if (!Array.isArray(points) || points.length < 2) return 0;
  let total = 0;
  for (let i = 1; i < points.length; i += 1) {
    total += haversineDistanceMeters(points[i - 1], points[i]);
  }
  return total;
}

function findFirstNearPointOnRoute(points, destination, thresholdMeters) {
  if (!Array.isArray(points) || points.length === 0) return null;

  let accumulatedMeters = 0;
  const dest = {
    latitude: Number(destination.latitude),
    longitude: Number(destination.longitude),
  };

  for (let i = 0; i < points.length; i += 1) {
    const point = points[i];
    const pointDistance = haversineDistanceMeters(point, dest);
    if (pointDistance <= thresholdMeters) {
      return {
        cutPoint: point,
        distanceAlongMeters: accumulatedMeters,
        remainderMeters: pointDistance,
        cutIndex: i,
      };
    }

    if (i >= points.length - 1) continue;

    const next = points[i + 1];
    const segmentMeters = haversineDistanceMeters(point, next);
    if (segmentMeters <= 0) continue;

    const steps = Math.max(12, Math.ceil(segmentMeters / 8));
    for (let step = 1; step <= steps; step += 1) {
      const t = step / steps;
      const sample = lerpPoint(point, next, t);
      const sampleDistance = haversineDistanceMeters(sample, dest);
      if (sampleDistance <= thresholdMeters) {
        return {
          cutPoint: sample,
          distanceAlongMeters: accumulatedMeters + segmentMeters * t,
          remainderMeters: sampleDistance,
          cutIndex: i,
        };
      }
    }

    accumulatedMeters += segmentMeters;
  }

  return null;
}

function trimRouteNearDestination(
  points,
  destination,
  {
    thresholdMeters = NEAR_DESTINATION_THRESHOLD_METERS,
    durationSeconds = null,
    distanceMeters = null,
  } = {}
) {
  const normalizedPoints = Array.isArray(points)
    ? points
        .map((entry) => ({
          latitude: Number(entry.latitude),
          longitude: Number(entry.longitude),
        }))
        .filter(
          (entry) =>
            Number.isFinite(entry.latitude) && Number.isFinite(entry.longitude)
        )
    : [];

  const dest = {
    latitude: Number(destination?.latitude),
    longitude: Number(destination?.longitude),
  };

  const originalDistance =
    Number.isFinite(distanceMeters) && distanceMeters > 0
      ? distanceMeters
      : distanceAlongPolyline(normalizedPoints);
  const originalDuration =
    Number.isFinite(durationSeconds) && durationSeconds > 0
      ? durationSeconds
      : null;

  if (
    normalizedPoints.length < 2 ||
    !Number.isFinite(dest.latitude) ||
    !Number.isFinite(dest.longitude)
  ) {
    return {
      points: normalizedPoints,
      distanceMeters: originalDistance,
      durationSeconds: originalDuration,
      trimmed: false,
    };
  }

  const near = findFirstNearPointOnRoute(
    normalizedPoints,
    dest,
    thresholdMeters
  );
  if (!near) {
    return {
      points: normalizedPoints,
      distanceMeters: originalDistance,
      durationSeconds: originalDuration,
      trimmed: false,
    };
  }

  const tailDistance = distanceAlongPolyline(
    normalizedPoints.slice(near.cutIndex + 1)
  );
  if (tailDistance < 30) {
    return {
      points: normalizedPoints,
      distanceMeters: originalDistance,
      durationSeconds: originalDuration,
      trimmed: false,
    };
  }

  const head = normalizedPoints.slice(0, near.cutIndex + 1);
  const trimmedPoints = [...head, near.cutPoint, dest];
  const trimmedDistance = near.distanceAlongMeters + near.remainderMeters;

  let trimmedDuration = originalDuration;
  if (originalDuration != null && originalDistance > 0) {
    const ratio = Math.min(1, trimmedDistance / originalDistance);
    trimmedDuration = Math.max(30, Math.round(originalDuration * ratio));
  }

  return {
    points: trimmedPoints,
    distanceMeters: trimmedDistance,
    durationSeconds: trimmedDuration,
    trimmed: true,
  };
}

module.exports = {
  NEAR_DESTINATION_THRESHOLD_METERS,
  haversineDistanceMeters,
  trimRouteNearDestination,
};
