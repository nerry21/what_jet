import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'package:what_jet/core/theme/app_colors.dart';
import 'package:what_jet/core/theme/app_dimensions.dart';

/// Result returned from the location picker.
class PickedLocationResult {
  const PickedLocationResult({
    required this.latitude,
    required this.longitude,
    this.name,
    this.address,
  });

  final double latitude;
  final double longitude;
  final String? name;
  final String? address;
}

/// Full-screen location picker powered by OpenStreetMap (free, no API key
/// required). Mimics the WhatsApp "Kirim Lokasi" flow shown in the user's
/// last two screenshots.
///
/// Flow:
///  1. Page opens → tries to centre the map on the user's current GPS fix.
///  2. User can drag the map or tap anywhere — a centre pin marks the
///     chosen coordinate.
///  3. "Kirim lokasi Anda saat ini" is always shown as the top option.
///  4. Reverse-geocoded nearby places are listed below.
///  5. Tapping any row returns the coordinate + name + address.
class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({super.key});

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  // Reasonable Indonesian default if GPS fails to resolve.
  static const LatLng _fallbackCentre = LatLng(-0.5071, 100.5478);
  static const double _defaultZoom = 15.5;

  final MapController _mapController = MapController();

  LatLng _pickedLatLng = _fallbackCentre;
  bool _hasPickedLatLng = false;
  String? _pickedName;
  String? _pickedAddress;
  List<_NearbyPlace> _nearbyPlaces = const <_NearbyPlace>[];
  bool _isResolvingCurrent = true;
  bool _isResolvingAddress = false;
  String? _gpsErrorMessage;
  Timer? _moveDebounce;

  @override
  void initState() {
    super.initState();
    unawaited(_initializeCurrentLocation());
  }

  @override
  void dispose() {
    _moveDebounce?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _initializeCurrentLocation() async {
    try {
      final permission = await _ensureLocationPermission();
      if (!permission) {
        if (!mounted) return;
        setState(() {
          _isResolvingCurrent = false;
          _gpsErrorMessage =
              'Izin lokasi tidak diberikan. Geser peta untuk memilih titik lain, atau aktifkan izin di pengaturan.';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      final latLng = LatLng(position.latitude, position.longitude);
      await _updateSelection(latLng, animateCamera: true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _gpsErrorMessage = 'Gagal membaca lokasi saat ini: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isResolvingCurrent = false;
        });
      }
    }
  }

  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  Future<void> _updateSelection(
    LatLng latLng, {
    bool animateCamera = false,
  }) async {
    setState(() {
      _pickedLatLng = latLng;
      _hasPickedLatLng = true;
      _isResolvingAddress = true;
    });

    if (animateCamera) {
      try {
        _mapController.move(latLng, _defaultZoom);
      } catch (_) {
        // Map controller may not be ready yet on first frame.
      }
    }

    await _refreshAddressFor(latLng);
  }

  Future<void> _refreshAddressFor(LatLng latLng) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        latLng.latitude,
        latLng.longitude,
      );

      if (!mounted) return;

      if (placemarks.isEmpty) {
        setState(() {
          _pickedName = null;
          _pickedAddress = null;
          _nearbyPlaces = const <_NearbyPlace>[];
          _isResolvingAddress = false;
        });
        return;
      }

      final primary = placemarks.first;
      final primaryName = _shortName(primary);
      final primaryAddress = _fullAddress(primary);

      final nearby = placemarks
          .skip(1)
          .take(6)
          .map(
            (p) => _NearbyPlace(
              name: _shortName(p) ?? 'Lokasi',
              address: _fullAddress(p) ?? '',
            ),
          )
          .where((p) => p.address.isNotEmpty)
          .toList(growable: false);

      setState(() {
        _pickedName = primaryName;
        _pickedAddress = primaryAddress;
        _nearbyPlaces = nearby;
        _isResolvingAddress = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pickedName = null;
        _pickedAddress = null;
        _nearbyPlaces = const <_NearbyPlace>[];
        _isResolvingAddress = false;
      });
    }
  }

  String? _shortName(Placemark p) {
    final candidates = <String?>[p.name, p.street, p.subLocality, p.locality];
    for (final candidate in candidates) {
      final trimmed = candidate?.trim() ?? '';
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return null;
  }

  String? _fullAddress(Placemark p) {
    final parts = <String>[
      p.street?.trim() ?? '',
      p.subLocality?.trim() ?? '',
      p.locality?.trim() ?? '',
      p.subAdministrativeArea?.trim() ?? '',
      p.administrativeArea?.trim() ?? '',
      p.postalCode?.trim() ?? '',
      p.country?.trim() ?? '',
    ].where((part) => part.isNotEmpty).toList();

    if (parts.isEmpty) return null;
    return parts.join(', ');
  }

  Future<void> _goToCurrentLocation() async {
    setState(() {
      _isResolvingCurrent = true;
      _gpsErrorMessage = null;
    });
    await _initializeCurrentLocation();
  }

  void _handleMapEvent(MapEvent event) {
    // When the user finishes panning/zooming, refresh the selection to the
    // new map centre. Debounced so we don't spam the geocoder.
    if (event is MapEventMoveEnd || event is MapEventFlingAnimationEnd) {
      _moveDebounce?.cancel();
      _moveDebounce = Timer(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        final centre = _mapController.camera.center;
        unawaited(_updateSelection(centre));
      });
    }
  }

  void _handleSendCurrentLocation() {
    if (!_hasPickedLatLng) return;

    Navigator.of(context).pop(
      PickedLocationResult(
        latitude: _pickedLatLng.latitude,
        longitude: _pickedLatLng.longitude,
        name: _pickedName,
        address: _pickedAddress,
      ),
    );
  }

  void _handleSendNearby(_NearbyPlace place) {
    if (!_hasPickedLatLng) return;

    Navigator.of(context).pop(
      PickedLocationResult(
        latitude: _pickedLatLng.latitude,
        longitude: _pickedLatLng.longitude,
        name: place.name,
        address: place.address,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfacePrimary,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Kirim lokasi'),
        centerTitle: false,
        backgroundColor: AppColors.surfacePrimary,
        foregroundColor: AppColors.neutral800,
        elevation: 0,
      ),
      body: Column(
        children: <Widget>[
          SizedBox(
            height: 320,
            child: Stack(
              children: <Widget>[
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _pickedLatLng,
                    initialZoom: _defaultZoom,
                    minZoom: 3,
                    maxZoom: 19,
                    onTap: (_, latLng) => _updateSelection(latLng),
                    onMapEvent: _handleMapEvent,
                  ),
                  children: <Widget>[
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.whatsjet.admin',
                      maxZoom: 19,
                    ),
                    // Attribution required by OSM.
                    const RichAttributionWidget(
                      alignment: AttributionAlignment.bottomLeft,
                      attributions: <SourceAttribution>[
                        TextSourceAttribution('© OpenStreetMap contributors'),
                      ],
                    ),
                  ],
                ),
                // Centre pin overlay (always reflects the map centre).
                const IgnorePointer(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 28),
                      child: Icon(
                        Icons.location_on_rounded,
                        color: Color(0xFFEA4335),
                        size: 42,
                      ),
                    ),
                  ),
                ),
                // My-location button
                Positioned(
                  top: 12,
                  right: 12,
                  child: Material(
                    color: AppColors.surfacePrimary,
                    shape: const CircleBorder(),
                    elevation: 3,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _goToCurrentLocation,
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Icon(
                          Icons.my_location_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
                if (_isResolvingCurrent)
                  Positioned(
                    bottom: 12,
                    left: 12,
                    right: 12,
                    child: _InfoBanner(
                      icon: Icons.gps_fixed_rounded,
                      text: 'Mencari lokasi Anda saat ini...',
                    ),
                  ),
                if (_gpsErrorMessage != null && !_isResolvingCurrent)
                  Positioned(
                    bottom: 12,
                    left: 12,
                    right: 12,
                    child: _InfoBanner(
                      icon: Icons.error_outline_rounded,
                      text: _gpsErrorMessage!,
                      isError: true,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: <Widget>[
                _SendCurrentTile(
                  isLoading: _isResolvingAddress,
                  name: _pickedName,
                  address: _pickedAddress,
                  onTap: !_hasPickedLatLng ? null : _handleSendCurrentLocation,
                ),
                if (_nearbyPlaces.isNotEmpty) ...<Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Text(
                      'Tempat sekitar',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.neutral500,
                      ),
                    ),
                  ),
                  for (final place in _nearbyPlaces)
                    _NearbyTile(
                      place: place,
                      onTap: () => _handleSendNearby(place),
                    ),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NearbyPlace {
  const _NearbyPlace({required this.name, required this.address});

  final String name;
  final String address;
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.icon,
    required this.text,
    this.isError = false,
  });

  final IconData icon;
  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final bg = isError ? const Color(0xFFFDECEC) : AppColors.surfaceSecondary;
    final fg = isError ? AppColors.error : AppColors.neutral700;

    return Material(
      color: bg,
      borderRadius: AppRadii.borderRadiusLg,
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text, style: TextStyle(fontSize: 12, color: fg)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SendCurrentTile extends StatelessWidget {
  const _SendCurrentTile({
    required this.isLoading,
    required this.name,
    required this.address,
    required this.onTap,
  });

  final bool isLoading;
  final String? name;
  final String? address;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = isLoading
        ? 'Menyiapkan detail alamat...'
        : (address?.isNotEmpty == true ? address! : 'Koordinat siap dikirim');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.send_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Kirim lokasi Anda saat ini',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.neutral800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: AppColors.neutral500),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NearbyTile extends StatelessWidget {
  const _NearbyTile({required this.place, required this.onTap});

  final _NearbyPlace place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surfaceTertiary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.location_on_outlined,
                color: AppColors.neutral500,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    place.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.neutral800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    place.address,
                    style: TextStyle(fontSize: 12, color: AppColors.neutral500),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
