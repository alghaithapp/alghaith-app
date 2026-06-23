import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' as latlong2;
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;

/// مكون خريطة التكسي — Google Maps (Maps SDK) المجاني غير المحدود للموبايل.
///
/// يعرض المسار ونقاط الانطلاق/الوصول وموقع السائق.
class TaxiMapWidget extends StatefulWidget {
  /// استدعاء عند إنشاء الخريطة (يمكن استخدامه للحصول على المتحكم)
  final void Function(gmaps.GoogleMapController controller)? onMapCreated;

  /// موقع الانطلاق
  final latlong2.LatLng? pickupLocation;

  /// موقع الوصول
  final latlong2.LatLng? dropoffLocation;

  /// نقاط المسار بين الانطلاق والوصول
  final List<latlong2.LatLng>? routePoints;

  /// موقع السائق الحالي
  final latlong2.LatLng? driverLocation;

  /// مستوى التكبير الابتدائي
  final double zoom;

  /// إظهار علامة التقاطع (crosshair) في منتصف الخريطة
  final bool showCrosshair;

  /// ارتفاع الخريطة (null = يملأ المساحة المتاحة)
  final double? height;

  /// استدعاء عند النقر على الخريطة — يعيد إحداثيات الموقع الذي تم النقر عليه
  final void Function(latlong2.LatLng latlng)? onMapTap;

  /// استدعاء عند اكتمال سحب علامة الانطلاق
  final void Function(latlong2.LatLng latlng)? onPickupDragEnd;

  /// استدعاء عند اكتمال سحب علامة الوصول
  final void Function(latlong2.LatLng latlng)? onDropoffDragEnd;

  const TaxiMapWidget({
    super.key,
    this.onMapCreated,
    this.pickupLocation,
    this.dropoffLocation,
    this.routePoints,
    this.driverLocation,
    this.zoom = 14.0,
    this.showCrosshair = false,
    this.height,
    this.onMapTap,
    this.onPickupDragEnd,
    this.onDropoffDragEnd,
  });

  @override
  State<TaxiMapWidget> createState() => _TaxiMapWidgetState();
}

class _TaxiMapWidgetState extends State<TaxiMapWidget> {
  Set<gmaps.Marker> _markers = {};
  Set<gmaps.Polyline> _polylines = {};
  gmaps.GoogleMapController? _mapController;
  gmaps.LatLng? _lastPickupCoord;
  gmaps.LatLng? _lastDropoffCoord;
  List<gmaps.LatLng>? _lastRoutePoints;

  gmaps.LatLng _toGmaps(latlong2.LatLng ll) =>
      gmaps.LatLng(ll.latitude, ll.longitude);

  // المركز الأساسي: موقع الانطلاق، أو موقع السائق، أو نقطة افتراضية (بغداد)
  gmaps.LatLng get _center => widget.pickupLocation != null
      ? _toGmaps(widget.pickupLocation!)
      : widget.driverLocation != null
          ? _toGmaps(widget.driverLocation!)
          : const gmaps.LatLng(32.9256, 44.7766);

  @override
  void initState() {
    super.initState();
    _rebuildMarkersAndPolylines();
  }

  @override
  void didUpdateWidget(TaxiMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final pickupChanged = widget.pickupLocation != oldWidget.pickupLocation;
    final dropoffChanged = widget.dropoffLocation != oldWidget.dropoffLocation;
    final routeChanged = widget.routePoints != oldWidget.routePoints;
    final driverChanged =
        !_sameLatLng(widget.driverLocation, oldWidget.driverLocation);
    if (pickupChanged || dropoffChanged || routeChanged || driverChanged) {
      _rebuildMarkersAndPolylines();
    }
  }

  bool _sameLatLng(latlong2.LatLng? a, latlong2.LatLng? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return a.latitude == b.latitude && a.longitude == b.longitude;
  }

  void _rebuildMarkersAndPolylines() {
    final markers = <gmaps.Marker>{};
    final polylines = <gmaps.Polyline>{};
    int markerIdCounter = 0;

    // علامة موقع الانطلاق
    if (widget.pickupLocation != null) {
      final g = _toGmaps(widget.pickupLocation!);
      _lastPickupCoord = g;
      markers.add(
        gmaps.Marker(
          markerId: gmaps.MarkerId('pickup_${markerIdCounter++}'),
          position: g,
          icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
            gmaps.BitmapDescriptor.hueAzure,
          ),
          infoWindow: const gmaps.InfoWindow(title: 'نقطة الانطلاق'),
          draggable: true,
          onDragEnd: (gmaps.LatLng pos) {
            widget.onPickupDragEnd?.call(
              latlong2.LatLng(pos.latitude, pos.longitude),
            );
          },
        ),
      );
    }

    // علامة موقع الوصول
    if (widget.dropoffLocation != null) {
      final g = _toGmaps(widget.dropoffLocation!);
      _lastDropoffCoord = g;
      markers.add(
        gmaps.Marker(
          markerId: gmaps.MarkerId('dropoff_${markerIdCounter++}'),
          position: g,
          icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
            gmaps.BitmapDescriptor.hueOrange,
          ),
          infoWindow: const gmaps.InfoWindow(title: 'الوجهة'),
          draggable: true,
          onDragEnd: (gmaps.LatLng pos) {
            widget.onDropoffDragEnd?.call(
              latlong2.LatLng(pos.latitude, pos.longitude),
            );
          },
        ),
      );
    }

    // علامة موقع السائق (سيارة)
    if (widget.driverLocation != null) {
      markers.add(
        gmaps.Marker(
          markerId: gmaps.MarkerId('driver_${markerIdCounter++}'),
          position: _toGmaps(widget.driverLocation!),
          icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
            gmaps.BitmapDescriptor.hueGreen,
          ),
          infoWindow: const gmaps.InfoWindow(title: 'السائق'),
        ),
      );
    }

    // علامة التقاطع (crosshair) في المنتصف
    if (widget.showCrosshair) {
      markers.add(
        gmaps.Marker(
          markerId: gmaps.MarkerId('crosshair_${markerIdCounter++}'),
          position: _center,
          icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
            gmaps.BitmapDescriptor.hueViolet,
          ),
        ),
      );
    }

    // المسار
    if (widget.routePoints != null && widget.routePoints!.length >= 2) {
      _lastRoutePoints = widget.routePoints!.map(_toGmaps).toList();
      polylines.add(
        gmaps.Polyline(
          polylineId: const gmaps.PolylineId('route'),
          points: _lastRoutePoints!,
          color: Colors.orange.withValues(alpha: 0.7),
          width: 4,
        ),
      );
    }

    if (mounted) {
      setState(() {
        _markers = markers;
        _polylines = polylines;
      });
      _fitCameraToContent();
    }
  }

  Future<void> _fitCameraToContent() async {
    final controller = _mapController;
    if (controller == null) return;

    final points = <gmaps.LatLng>[];
    if (widget.pickupLocation != null) {
      points.add(_toGmaps(widget.pickupLocation!));
    }
    if (widget.dropoffLocation != null) {
      points.add(_toGmaps(widget.dropoffLocation!));
    }
    if (widget.routePoints != null && widget.routePoints!.length >= 2) {
      points.addAll(widget.routePoints!.map(_toGmaps));
    }

    if (points.isEmpty) return;

    if (points.length == 1) {
      await controller.animateCamera(
        gmaps.CameraUpdate.newLatLngZoom(points.first, widget.zoom),
      );
      return;
    }

    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;

    for (final point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    if ((maxLat - minLat).abs() < 0.0005 && (maxLng - minLng).abs() < 0.0005) {
      await controller.animateCamera(
        gmaps.CameraUpdate.newLatLngZoom(points.first, 16),
      );
      return;
    }

    final bounds = gmaps.LatLngBounds(
      southwest: gmaps.LatLng(minLat, minLng),
      northeast: gmaps.LatLng(maxLat, maxLng),
    );
    try {
      await controller.animateCamera(
        gmaps.CameraUpdate.newLatLngBounds(bounds, 72),
      );
    } catch (_) {
      await controller.animateCamera(
        gmaps.CameraUpdate.newLatLngZoom(
          gmaps.LatLng(
            (minLat + maxLat) / 2,
            (minLng + maxLng) / 2,
          ),
          13,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: widget.height,
      child: gmaps.GoogleMap(
        initialCameraPosition: gmaps.CameraPosition(
          target: _center,
          zoom: widget.zoom,
        ),
        mapType: gmaps.MapType.normal,
        markers: _markers,
        polylines: _polylines,
        myLocationEnabled: true,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        compassEnabled: true,
        buildingsEnabled: true,
        trafficEnabled: false,
        onTap: (gmaps.LatLng pos) {
          widget.onMapTap?.call(
            latlong2.LatLng(pos.latitude, pos.longitude),
          );
        },
        onMapCreated: (gmaps.GoogleMapController controller) {
          _mapController = controller;
          widget.onMapCreated?.call(controller);
          _fitCameraToContent();
        },
      ),
    );
  }
}
