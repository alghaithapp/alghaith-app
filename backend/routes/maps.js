const express = require('express');
const router = express.Router();

// ── Config ──────────────────────────────────────────────────────────────
const mapboxAccessToken = String(process.env.MAPBOX_ACCESS_TOKEN || '').trim();
const mapboxPublicToken = String(process.env.MAPBOX_PUBLIC_TOKEN || '').trim();

function resolvePublicMapboxToken() {
  if (mapboxPublicToken.startsWith('pk.')) return mapboxPublicToken;
  if (mapboxAccessToken.startsWith('pk.')) return mapboxAccessToken;
  return '';
}

// ── Helpers ─────────────────────────────────────────────────────────────

async function geocodeAddressWithMapbox(addressText) {
  const address = String(addressText || '').trim();
  const query = encodeURIComponent(address);
  const params = new URLSearchParams({
    language: 'ar',
    country: 'iq',
    limit: '1',
    access_token: mapboxAccessToken,
  });
  const response = await fetch(
    `https://api.mapbox.com/geocoding/v5/mapbox.places/${query}.json?${params.toString()}`
  );
  if (!response.ok) {
    throw new Error(`Mapbox geocoding failed with status ${response.status}`);
  }
  const payload = await response.json();
  const feature = Array.isArray(payload?.features) ? payload.features[0] : null;
  const center = Array.isArray(feature?.center) ? feature.center : null;
  if (!center || center.length < 2) {
    throw new Error('Could not geocode one of the addresses.');
  }
  const longitude = Number(center[0]);
  const latitude = Number(center[1]);
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
    throw new Error('Invalid coordinates from geocoding result.');
  }
  return { latitude, longitude };
}

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

function normalizeRouteProfile(value) {
  const profile = String(value || '').trim().toLowerCase();
  if (profile === 'walking' || profile === 'pedestrian') return 'walking';
  if (profile === 'cycling' || profile === 'bike' || profile === 'bicycle') {
    return 'cycling';
  }
  if (profile === 'delivery' || profile === 'courier' || profile === 'motorbike') {
    return 'delivery';
  }
  return 'driving';
}

async function computeDrivingRoute(origin, destination) {
  const coordinates =
    `${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}`;
  const params = new URLSearchParams({
    alternatives: 'false',
    overview: 'full',
    geometries: 'geojson',
    language: 'ar',
    access_token: mapboxAccessToken,
    continue_straight: 'false',
  });
  const response = await fetch(
    `https://api.mapbox.com/directions/v5/mapbox/driving/${coordinates}?${params.toString()}`
  );

  if (!response.ok) {
    const bodyText = await response.text();
    throw new Error(bodyText || `Mapbox directions failed with status ${response.status}`);
  }

  const payload = await response.json();
  const route = Array.isArray(payload?.routes) ? payload.routes[0] : null;
  const geometry = route?.geometry;
  const routeCoordinates = Array.isArray(geometry?.coordinates)
    ? geometry.coordinates
    : [];
  if (!route || routeCoordinates.length < 2) {
    throw new Error('No route geometry available between the selected points.');
  }

  const points = routeCoordinates.map((entry) => ({
    latitude: Number(entry[1]),
    longitude: Number(entry[0]),
  }));

  return {
    points,
    distanceMeters: Number(route.distance) || 0,
    durationSeconds: Math.round(Number(route.duration) || 0),
  };
}

async function computeRoadDistanceMeters(origin, destination, profile = 'driving') {
  const coordinates =
    `${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}`;
  const params = new URLSearchParams({
    alternatives: 'false',
    overview: 'false',
    language: 'ar',
    access_token: mapboxAccessToken,
  });
  if (profile === 'driving') {
    params.set('continue_straight', 'false');
  }
  const response = await fetch(
    `https://api.mapbox.com/directions/v5/mapbox/${profile}/${coordinates}?${params.toString()}`
  );

  if (!response.ok) {
    const bodyText = await response.text();
    throw new Error(bodyText || `Mapbox directions failed with status ${response.status}`);
  }

  const payload = await response.json();
  const route = Array.isArray(payload?.routes) ? payload.routes[0] : null;
  if (!route || typeof route.distance !== 'number') {
    throw new Error('No routes available between the selected points.');
  }
  return {
    distanceMeters: route.distance,
    duration: String(route.duration || ''),
    profile,
  };
}

async function computeDeliveryDistanceMeters(origin, destination) {
  const straightMeters = haversineDistanceMeters(origin, destination);
  const fallbackMeters = straightMeters * 1.18;
  const minimumMeters = straightMeters * 1.05;
  const candidates = [];

  for (const profile of ['cycling', 'walking', 'driving']) {
    try {
      const route = await computeRoadDistanceMeters(origin, destination, profile);
      if (Number.isFinite(route.distanceMeters) && route.distanceMeters > 0) {
        candidates.push(route);
      }
    } catch (error) {
      console.warn(`delivery distance ${profile} failed:`, error?.message || error);
    }
  }

  if (!candidates.length) {
    return {
      distanceMeters: fallbackMeters,
      duration: '',
      profile: 'straight-line-adjusted',
    };
  }

  const nonDrivingCandidates = candidates.filter((route) => route.profile !== 'driving');
  const sourceCandidates = nonDrivingCandidates.length ? nonDrivingCandidates : candidates;
  const shortest = sourceCandidates.reduce((best, route) =>
    route.distanceMeters < best.distanceMeters ? route : best
  );
  const cappedMeters = Math.max(shortest.distanceMeters, minimumMeters);
  const adjustedMeters = nonDrivingCandidates.length
    ? cappedMeters
    : Math.min(cappedMeters, fallbackMeters);

  return {
    distanceMeters: adjustedMeters,
    duration: shortest.duration,
    profile: shortest.profile,
  };
}

// ── Routes ──────────────────────────────────────────────────────────────

router.get('/public-token', (_, res) => {
  const token = resolvePublicMapboxToken();
  if (!token) {
    return res.status(503).json({
      message: 'MAPBOX_PUBLIC_TOKEN is not configured on backend.',
    });
  }
  return res.json({ publicToken: token });
});

router.post('/route-distance', async (req, res) => {
  try {
    if (!mapboxAccessToken) {
      return res.status(503).json({
        message: 'MAPBOX_ACCESS_TOKEN is not configured on backend.',
      });
    }

    const pickupAddress = String(req.body?.pickupAddress || '').trim();
    const dropoffAddress = String(req.body?.dropoffAddress || '').trim();
    const pickupLatitude = Number(req.body?.pickupLatitude);
    const pickupLongitude = Number(req.body?.pickupLongitude);
    const dropoffLatitude = Number(req.body?.dropoffLatitude);
    const dropoffLongitude = Number(req.body?.dropoffLongitude);
    const routeProfile = normalizeRouteProfile(req.body?.routeProfile);

    const hasPickupCoords =
      Number.isFinite(pickupLatitude) && Number.isFinite(pickupLongitude);
    const hasDropoffCoords =
      Number.isFinite(dropoffLatitude) && Number.isFinite(dropoffLongitude);

    const origin = hasPickupCoords
      ? { latitude: pickupLatitude, longitude: pickupLongitude }
      : pickupAddress
        ? await geocodeAddressWithMapbox(pickupAddress)
        : null;
    const destination = hasDropoffCoords
      ? { latitude: dropoffLatitude, longitude: dropoffLongitude }
      : dropoffAddress
        ? await geocodeAddressWithMapbox(dropoffAddress)
        : null;

    if (!origin || !destination) {
      return res.status(400).json({
        message:
          'Provide pickup/dropoff coordinates or valid addresses for both points.',
      });
    }

    const route =
      routeProfile === 'delivery'
        ? await computeDeliveryDistanceMeters(origin, destination)
        : await computeRoadDistanceMeters(origin, destination, routeProfile);
    return res.json({
      distanceMeters: route.distanceMeters,
      distanceKm: route.distanceMeters / 1000,
      duration: route.duration,
      routeProfile: route.profile,
    });
  } catch (error) {
    console.error('route-distance error:', error);
    return res.status(500).json({
      message: error?.message || 'Failed to compute route distance.',
    });
  }
});

router.post('/driving-route', async (req, res) => {
  try {
    if (!mapboxAccessToken) {
      return res.status(503).json({
        message: 'MAPBOX_ACCESS_TOKEN is not configured on backend.',
      });
    }

    const pickupAddress = String(req.body?.pickupAddress || '').trim();
    const dropoffAddress = String(req.body?.dropoffAddress || '').trim();
    const pickupLatitude = Number(req.body?.pickupLatitude);
    const pickupLongitude = Number(req.body?.pickupLongitude);
    const dropoffLatitude = Number(req.body?.dropoffLatitude);
    const dropoffLongitude = Number(req.body?.dropoffLongitude);

    const hasPickupCoords =
      Number.isFinite(pickupLatitude) && Number.isFinite(pickupLongitude);
    const hasDropoffCoords =
      Number.isFinite(dropoffLatitude) && Number.isFinite(dropoffLongitude);

    const origin = hasPickupCoords
      ? { latitude: pickupLatitude, longitude: pickupLongitude }
      : pickupAddress
        ? await geocodeAddressWithMapbox(pickupAddress)
        : null;
    const destination = hasDropoffCoords
      ? { latitude: dropoffLatitude, longitude: dropoffLongitude }
      : dropoffAddress
        ? await geocodeAddressWithMapbox(dropoffAddress)
        : null;

    if (!origin || !destination) {
      return res.status(400).json({
        message:
          'Provide pickup/dropoff coordinates or valid addresses for both points.',
      });
    }

    const route = await computeDrivingRoute(origin, destination);
    return res.json({
      points: route.points,
      distanceMeters: route.distanceMeters,
      distanceKm: route.distanceMeters / 1000,
      durationSeconds: route.durationSeconds,
    });
  } catch (error) {
    console.error('driving-route error:', error);
    return res.status(500).json({
      message: error?.message || 'Failed to compute driving route.',
    });
  }
});

module.exports = router;
