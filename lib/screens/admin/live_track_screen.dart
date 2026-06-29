import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:trip_manager/models/trip_log_model.dart';
import 'package:trip_manager/services/location_service.dart';
import 'package:trip_manager/services/supabase_service.dart';
import 'package:trip_manager/theme/app_theme.dart';

class LiveTrackScreen extends StatefulWidget {
  final String tripId;
  const LiveTrackScreen({super.key, required this.tripId});
  @override State<LiveTrackScreen> createState() => _LiveTrackScreenState();
}

class _LiveTrackScreenState extends State<LiveTrackScreen> {
  GoogleMapController? _mapController;
  TripLogModel? _log;
  StreamSubscription? _sub;
  Set<Marker> _markers = {};
  double? _lastGeocodedLat;
  double? _lastGeocodedLng;
  String _address = 'Fetching location address...';

  @override
  void initState() {
    super.initState();
    _loadInitialLog();
    _subscribeToLog();
  }

  Future<void> _loadInitialLog() async {
    try {
      final data = await SupabaseService.getTripLog(widget.tripId);
      if (data != null && mounted) {
        final log = TripLogModel.fromJson(data);
        setState(() {
          _log = log;
          _updateLocation(log);
        });
      }
    } catch (e) {
      debugPrint('Error loading initial trip log: $e');
    }
  }

  void _subscribeToLog() {
    _sub = SupabaseService.watchTripLog(widget.tripId).listen(
      (data) {
        try {
          if (data.isNotEmpty) {
            final log = TripLogModel.fromJson(data.first);
            if (mounted) {
              setState(() {
                _log = log;
                _updateLocation(log);
              });
            }
          }
        } catch (e) {
          debugPrint('Error parsing trip log in stream listener: $e');
        }
      },
      onError: (err) {
        debugPrint('Realtime trip log stream error: $err');
      },
    );
  }

  void _updateLocation(TripLogModel log) {
    if (log.currentLat != null && log.currentLng != null) {
      final pos = LatLng(log.currentLat!, log.currentLng!);
      _fetchAddress(log.currentLat!, log.currentLng!);
      if (mounted) {
        setState(() {
          _markers = {
            Marker(
              markerId: const MarkerId('driver'),
              position: pos,
              infoWindow: const InfoWindow(title: 'Driver Location'),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
            ),
          };
        });
      }
      try {
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(pos, 14.5)).catchError((e) {
          debugPrint('Error animating camera (async): $e');
        });
      } catch (e) {
        debugPrint('Error animating camera: $e');
      }
    }
  }

  Future<void> _fetchAddress(double lat, double lng) async {
    if (_lastGeocodedLat == lat && _lastGeocodedLng == lng) return;
    _lastGeocodedLat = lat;
    _lastGeocodedLng = lng;
    final addr = await LocationService.getAddressFromCoordinates(lat, lng);
    if (mounted) {
      setState(() {
        _address = addr;
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasLocation = _log?.currentLat != null;
    final isDesktop = !kIsWeb && (defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/admin')),
        title: const Text('Live Tracking'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _log?.currentStatus == JourneyStatus.ongoing ? AppColors.ongoingBg : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (_log?.currentStatus == JourneyStatus.ongoing)
                Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.ongoing, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(
                _log?.currentStatus == JourneyStatus.ongoing ? 'Ongoing' : 'Not started',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600,
                  color: _log?.currentStatus == JourneyStatus.ongoing ? AppColors.ongoing : AppColors.textSecondary),
              ),
            ]),
          ),
        ],
      ),
      body: Stack(children: [
        isDesktop
            ? (hasLocation ? _buildDesktopMap(LatLng(_log!.currentLat!, _log!.currentLng!)) : _buildDesktopPlaceholder())
            : GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: hasLocation
                      ? LatLng(_log!.currentLat!, _log!.currentLng!)
                      : const LatLng(20.5937, 78.9629),
                  zoom: hasLocation ? 14 : 5,
                ),
                onMapCreated: (c) {
                  _mapController = c;
                  if (hasLocation) {
                    _updateLocation(_log!);
                  }
                },
                markers: _markers,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
              ),
        if (!hasLocation)
          Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)]),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.location_searching, color: AppColors.textHint, size: 36),
                const SizedBox(height: 8),
                Text('Waiting for driver location...', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary)),
              ]),
            ),
          ),
        if (hasLocation)
          Positioned(
            bottom: 20, left: 16, right: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  const Icon(Icons.location_on, color: AppColors.ongoing),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Driver Location', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text(
                        _address,
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_log!.currentLat!.toStringAsFixed(6)}, ${_log!.currentLng!.toStringAsFixed(6)}',
                        style: GoogleFonts.inter(fontSize: 10, color: AppColors.textHint),
                      ),
                    ]),
                  ),
                  const SizedBox(width: 10),
                  Text('Live', style: GoogleFonts.inter(fontSize: 12, color: AppColors.ongoing, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _buildDesktopMap(LatLng pos) {
    final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      return const Center(child: Text('Google Maps API key is missing. Cannot load map.'));
    }
    final lat = pos.latitude;
    final lng = pos.longitude;
    final mapUrl = 'https://maps.googleapis.com/maps/api/staticmap?center=$lat,$lng&zoom=15&size=800x600&scale=2&markers=color:blue%7Clabel:D%7C$lat,$lng&key=$apiKey';

    return Image.network(
      mapUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const Center(child: CircularProgressIndicator());
      },
      errorBuilder: (context, error, stackTrace) {
        return const Center(child: Text('Error loading map image. Check API key/permissions.'));
      },
    );
  }

  Widget _buildDesktopPlaceholder() {
    final pos = _log?.currentLat != null ? LatLng(_log!.currentLat!, _log!.currentLng!) : null;
    return Container(
      color: AppColors.surfaceAlt,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.map_rounded,
                  size: 64,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Live Telemetry (Desktop Mode)',
                style: GoogleFonts.sora(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Google Maps is active on mobile devices.\nDisplaying real-time coordinate updates below.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              if (pos != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.my_location, color: AppColors.ongoing, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Latitude: ${pos.latitude.toStringAsFixed(6)}',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.my_location, color: AppColors.ongoing, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Longitude: ${pos.longitude.toStringAsFixed(6)}',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
