import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pawpulse/services/vet_locator_service.dart';
import 'package:pawpulse/theme/app_theme.dart';

class NearbyVetsScreen extends StatefulWidget {
  static const String routeName = '/nearby-vets';
  const NearbyVetsScreen({super.key});

  @override
  State<NearbyVetsScreen> createState() => _NearbyVetsScreenState();
}

enum _LoadState { loading, ready, error, permissionDenied }

class _NearbyVetsScreenState extends State<NearbyVetsScreen> {
  final VetLocatorService _vetService = VetLocatorService();
  final MapController _mapController = MapController();

  _LoadState _state = _LoadState.loading;
  String? _error;
  LatLng? _userLocation;
  List<VetLocation> _vets = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() => _state = _LoadState.loading);
    try {
      final position = await _getCurrentLocation();
      final userLatLng = LatLng(position.latitude, position.longitude);
      final vets = await _vetService.findNearbyVets(lat: position.latitude, lon: position.longitude);

      setState(() {
        _userLocation = userLatLng;
        _vets = vets;
        _state = _LoadState.ready;
      });
    } on _LocationPermissionException {
      setState(() => _state = _LoadState.permissionDenied);
    } catch (e) {
      setState(() {
        _state = _LoadState.error;
        _error = e.toString();
      });
    }
  }

  Future<Position> _getCurrentLocation() async {
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    throw Exception('Location services are turned off. Please enable them in Settings.');
  }

  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      throw _LocationPermissionException();
    }
  }
  if (permission == LocationPermission.deniedForever) {
    throw _LocationPermissionException();
  }

  // 1. Try to get last known position first (instant)
  final lastKnown = await Geolocator.getLastKnownPosition();
  if (lastKnown != null) return lastKnown;

  // 2. Fetch current position with a 5-second safety timeout
  try {
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.low,
    ).timeout(const Duration(seconds: 5));
  } catch (_) {
    // 3. Fallback to default Singapore coordinates if emulator GPS hangs
    return Position(
      latitude: 1.3521,
      longitude: 103.8198,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }
}

  Future<void> _openDirections(VetLocation vet) async {
    final uri = Uri.parse('https://www.openstreetmap.org/directions?to=${vet.lat}%2C${vet.lon}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('Nearby Vets'),
        backgroundColor: AppColors.cream,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case _LoadState.loading:
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Finding your location & nearby vets...'),
            ],
          ),
        );

      case _LoadState.permissionDenied:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_off, size: 56, color: AppColors.softGrey),
                const SizedBox(height: 12),
                const Text(
                  'Location permission is needed to find vets near you.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _init, child: const Text('Try Again')),
              ],
            ),
          ),
        );

      case _LoadState.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 56, color: Colors.red),
                const SizedBox(height: 12),
                Text(_error ?? 'Something went wrong.', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _init, child: const Text('Retry')),
              ],
            ),
          ),
        );

      case _LoadState.ready:
        return Column(
          children: [
            Expanded(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _userLocation!,
                  initialZoom: 14,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.pawpulse',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _userLocation!,
                        width: 40,
                        height: 40,
                        child: const Icon(Icons.my_location, color: AppColors.teal, size: 32),
                      ),
                      ..._vets.map(
                        (v) => Marker(
                          point: LatLng(v.lat, v.lon),
                          width: 40,
                          height: 40,
                          child: GestureDetector(
                            onTap: () => _showVetSheet(v),
                            child: const Icon(Icons.location_on, color: AppColors.terracotta, size: 36),
                          ),
                        ),
                      ),
                    ],
                  ),
                  RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution(
                        'OpenStreetMap contributors',
                        onTap: () => launchUrl(Uri.parse('https://openstreetmap.org/copyright')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.white,
              child: Row(
                children: [
                  const Icon(Icons.pets, size: 16, color: AppColors.terracotta),
                  const SizedBox(width: 8),
                  Text('${_vets.length} vet clinic${_vets.length == 1 ? '' : 's'} found nearby'),
                ],
              ),
            ),
          ],
        );
    }
  }

  void _showVetSheet(VetLocation vet) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(vet.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if (vet.address != null) ...[
              const SizedBox(height: 4),
              Text(vet.address!, style: const TextStyle(color: AppColors.softGrey)),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openDirections(vet),
                icon: const Icon(Icons.directions),
                label: const Text('Get Directions'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.terracotta, foregroundColor: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationPermissionException implements Exception {}