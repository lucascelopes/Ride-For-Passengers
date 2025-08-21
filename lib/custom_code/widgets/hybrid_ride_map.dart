// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom widgets
import '/custom_code/actions/index.dart'; // Imports custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:async';
import 'dart:io' show Platform;

// Google (Android)
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
// Apple (iOS)
import 'package:apple_maps_flutter/apple_maps_flutter.dart' as amap;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart'
    as bg;

class HybridRideMap extends StatefulWidget {
  const HybridRideMap({
    Key? key,
    required this.rideRequested,
    required this.users,
    required this.width,
    required this.height,
    this.destLat, // <<< agora nullable
    this.destLng, // <<< agora nullable
    this.nearbyRadiusMeters = 1500,
    this.encodedPolyline,
  }) : super(key: key);

  final bool rideRequested;
  final List<UsersRecord> users;
  final double width;
  final double height;

  final double? destLat; // nullable
  final double? destLng; // nullable
  final double nearbyRadiusMeters;
  final String? encodedPolyline;

  @override
  State<HybridRideMap> createState() => _HybridRideMapState();
}

class _HybridRideMapState extends State<HybridRideMap> {
  gmap.GoogleMapController? _gController;
  amap.AppleMapController? _aController;

  bg.Location? _me;
  Function(bg.Location)? _locCallback;

  final Set<gmap.Marker> _gMarkers = {};
  final Set<amap.Annotation> _aAnnotations = {};

  final Set<gmap.Polyline> _gPolylines = {};
  final Set<amap.Polyline> _aPolylines = {};

  static const String _googleGreyStyle = r'''[
  {"elementType":"geometry","stylers":[{"color":"#1f1f1f"}]},
  {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#a3a3a3"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#1f1f1f"}]},
  {"featureType":"administrative","elementType":"geometry","stylers":[{"visibility":"off"}]},
  {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#2a2a2a"}]},
  {"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#bfbfbf"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#2b2b2b"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#9e9e9e"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#3c3c3c"}]},
  {"featureType":"transit","elementType":"geometry","stylers":[{"color":"#2a2a2a"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#0f0f0f"}]}
]''';

  @override
  void initState() {
    super.initState();
    _ensureLocation();
  }

  @override
  void didUpdateWidget(covariant HybridRideMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    _refreshLayers();
    _animateToUserIfNeeded();
  }

  @override
  void dispose() {
    if (_locCallback != null) {
      bg.BackgroundGeolocation.removeListener(_locCallback!);
    }
    super.dispose();
  }

  Future<void> _ensureLocation() async {
    try {
      if (_locCallback != null) {
        bg.BackgroundGeolocation.removeListener(_locCallback!);
      }
      _locCallback = (bg.Location loc) {
        if (!mounted) return;
        setState(() => _me = loc);
        _animateToUserIfNeeded();
        _refreshLayers();
      };
      bg.BackgroundGeolocation.onLocation(_locCallback!);

      final pos =
          await bg.BackgroundGeolocation.getCurrentPosition(persist: false);
      if (!mounted) return;
      setState(() => _me = pos);

      _animateToUserIfNeeded();
      _refreshLayers();
    } catch (e) {
      debugPrint('Location error: $e');
    }
  }

  void _animateToUserIfNeeded() {
    if (_me == null) return;
    final lat = _me!.coords.latitude, lng = _me!.coords.longitude;

    if (Platform.isIOS) {
      final c = _aController;
      if (c == null) return;
      c.moveCamera(
        amap.CameraUpdate.newCameraPosition(
          amap.CameraPosition(target: amap.LatLng(lat, lng), zoom: 15),
        ),
      );
    } else {
      final c = _gController;
      if (c == null) return;
      c.animateCamera(
        gmap.CameraUpdate.newCameraPosition(
          gmap.CameraPosition(target: gmap.LatLng(lat, lng), zoom: 15),
        ),
      );
    }
  }

  void _refreshLayers() {
    if (Platform.isIOS) {
      _buildAppleAnnotationsFromUsers();
      _buildAppleRoutePolyline();
    } else {
      _buildGoogleMarkersFromUsers();
      _buildGoogleRoutePolyline();
    }
  }

  // ---------- Helpers de UsersRecord + parsing seguro ----------
  dynamic _readField(UsersRecord u, String key) {
    try {
      if (u.snapshotData.containsKey(key)) return u.snapshotData[key];
    } catch (_) {}
    return null;
  }

  double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  _DriverPos? _extractDriverPos(UsersRecord u) {
    final loc = _readField(u, 'location'); // LatLng do FF
    if (loc is LatLng) {
      if (loc.latitude.isFinite && loc.longitude.isFinite) {
        return _DriverPos(lat: loc.latitude, lng: loc.longitude);
      }
      return null;
    }
    final lat = _asDouble(_readField(u, 'lat'));
    final lng = _asDouble(_readField(u, 'lng'));
    if (lat == null || lng == null) return null;
    if (!lat.isFinite || !lng.isFinite) return null;
    return _DriverPos(lat: lat, lng: lng);
  }

  double _extractHeading(UsersRecord u) {
    final h = _asDouble(_readField(u, 'heading'));
    final b = _asDouble(_readField(u, 'bearing'));
    return (h ?? b ?? 0.0);
  }

  bool _isOnline(UsersRecord u) {
    final on = _readField(u, 'isOnline');
    if (on is bool) return on;
    return true;
  }

  // ---------- ANDROID (Google) ----------
  void _buildGoogleMarkersFromUsers() {
    _gMarkers.clear();

    if (_me == null || widget.users.isEmpty) {
      if (mounted) setState(() {});
      return;
    }

    final userLat = _me!.coords.latitude;
    final userLng = _me!.coords.longitude;

    for (int i = 0; i < widget.users.length; i++) {
      final u = widget.users[i];
      if (!_isOnline(u)) continue;

      final pos = _extractDriverPos(u);
      if (pos == null) continue;

      final distM =
          Geolocator.distanceBetween(userLat, userLng, pos.lat, pos.lng);
      if (distM > widget.nearbyRadiusMeters) continue;

      final heading = _extractHeading(u);
      final veryNear = distM < 120.0;

      _gMarkers.add(
        gmap.Marker(
          markerId: gmap.MarkerId('driver_$i'),
          position: gmap.LatLng(pos.lat, pos.lng),
          rotation: heading,
          flat: true,
          icon: gmap.BitmapDescriptor.defaultMarkerWithHue(veryNear ? 12 : 42),
        ),
      );
    }

    if (mounted) setState(() {});
  }

  void _buildGoogleRoutePolyline() {
    _gPolylines.clear();

    // Sem destino válido? Nada de rota.
    final hasDest = (widget.destLat != null && widget.destLng != null);
    if (!widget.rideRequested || _me == null || !hasDest) {
      if (mounted) setState(() {});
      return;
    }

    final user = gmap.LatLng(_me!.coords.latitude, _me!.coords.longitude);
    final destG = gmap.LatLng(widget.destLat!, widget.destLng!);

    final encoded = (widget.encodedPolyline ?? '').trim();
    List<gmap.LatLng> gpts;
    if (encoded.isNotEmpty && encoded.toLowerCase() != 'null') {
      final decoded = _safeDecode(encoded);
      if (decoded != null && decoded.isNotEmpty) {
        gpts =
            decoded.map((p) => gmap.LatLng(p.latitude, p.longitude)).toList();
      } else {
        gpts = [user, destG];
      }
    } else {
      gpts = [user, destG];
    }

    _gPolylines.add(
      gmap.Polyline(
        polylineId: const gmap.PolylineId('route'),
        points: gpts,
        width: 5,
        color: Colors.orangeAccent,
        geodesic: true,
      ),
    );

    if (mounted) setState(() {});
  }

  // ---------- iOS (Apple) 1.4.0 ----------
  void _buildAppleAnnotationsFromUsers() {
    _aAnnotations.clear();

    if (_me == null || widget.users.isEmpty) {
      if (mounted) setState(() {});
      return;
    }

    final userLat = _me!.coords.latitude;
    final userLng = _me!.coords.longitude;

    for (int i = 0; i < widget.users.length; i++) {
      final u = widget.users[i];
      if (!_isOnline(u)) continue;

      final pos = _extractDriverPos(u);
      if (pos == null) continue;

      final distM =
          Geolocator.distanceBetween(userLat, userLng, pos.lat, pos.lng);
      if (distM > widget.nearbyRadiusMeters) continue;

      final veryNear = distM < 120.0;

      _aAnnotations.add(
        amap.Annotation(
          annotationId: amap.AnnotationId('driver_$i'),
          position: amap.LatLng(pos.lat, pos.lng),
          infoWindow: amap.InfoWindow(
            title: veryNear ? 'Driver (nearby)' : 'Driver',
            snippet: veryNear ? '≈ ${distM.toStringAsFixed(0)} m' : 'Nearby',
          ),
        ),
      );
    }

    if (mounted) setState(() {});
  }

  void _buildAppleRoutePolyline() {
    _aPolylines.clear();

    final hasDest = (widget.destLat != null && widget.destLng != null);
    if (!widget.rideRequested || _me == null || !hasDest) {
      if (mounted) setState(() {});
      return;
    }

    final user = amap.LatLng(_me!.coords.latitude, _me!.coords.longitude);
    final destA = amap.LatLng(widget.destLat!, widget.destLng!);

    final encoded = (widget.encodedPolyline ?? '').trim();
    List<amap.LatLng> apts;
    if (encoded.isNotEmpty && encoded.toLowerCase() != 'null') {
      final decoded = _safeDecode(encoded);
      if (decoded != null && decoded.isNotEmpty) {
        apts =
            decoded.map((p) => amap.LatLng(p.latitude, p.longitude)).toList();
      } else {
        apts = [user, destA];
      }
    } else {
      apts = [user, destA];
    }

    _aPolylines.add(
      amap.Polyline(
        polylineId: amap.PolylineId('route'),
        points: apts,
        width: 5,
        color: Colors.orangeAccent,
      ),
    );

    if (mounted) setState(() {});
  }

  // --- SAFE decoder: não derruba se a string estiver ruim ---
  List<_LatLng>? _safeDecode(String encoded) {
    try {
      return _decodePolyline(encoded);
    } catch (e) {
      debugPrint('Polyline decode error: $e');
      return null;
    }
  }

  // --- Polyline decoder ---
  List<_LatLng> _decodePolyline(String encoded) {
    final poly = <_LatLng>[];
    int index = 0, lat = 0, lng = 0;
    while (index < encoded.length) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20 && index < encoded.length);
      final dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20 && index < encoded.length);
      final dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      poly.add(_LatLng(lat / 1e5, lng / 1e5));
    }
    return poly;
  }

  @override
  Widget build(BuildContext context) {
    final startLat = _me?.coords.latitude ?? widget.destLat ?? 0.0;
    final startLng = _me?.coords.longitude ?? widget.destLng ?? 0.0;
    final hasStart = startLat.isFinite && startLng.isFinite;

    final initialPos = hasStart
        ? gmap.CameraPosition(target: gmap.LatLng(startLat, startLng), zoom: 14)
        : const gmap.CameraPosition(target: gmap.LatLng(0, 0), zoom: 1);

    if (Platform.isIOS) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: amap.AppleMap(
            initialCameraPosition: amap.CameraPosition(
              target: amap.LatLng(
                  initialPos.target.latitude, initialPos.target.longitude),
              zoom: initialPos.zoom,
            ),
            onMapCreated: (c) => _aController = c,
            mapType: amap.MapType.standard,
            myLocationEnabled: true,
            annotations: _aAnnotations,
            polylines: _aPolylines,
          ),
        ),
      );
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: gmap.GoogleMap(
          initialCameraPosition: initialPos,
          onMapCreated: (c) async {
            _gController = c;
            try {
              await c.setMapStyle(_googleGreyStyle);
            } catch (_) {}
          },
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          compassEnabled: false,
          buildingsEnabled: false,
          markers: _gMarkers,
          polylines: _gPolylines,
          zoomControlsEnabled: false,
        ),
      ),
    );
  }
}

class _LatLng {
  final double latitude;
  final double longitude;
  _LatLng(this.latitude, this.longitude);
}

class _DriverPos {
  final double lat;
  final double lng;
  _DriverPos({required this.lat, required this.lng});
}
