import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:go_router/go_router.dart';

import '../spots/models/spot.dart';
import '../spots/repo/spots_repository.dart';
import '../../common/services/external_maps.dart';
import '../reviews/review_form.dart';
import '../photos/photo_uploader.dart';

const bool kUseEmulators = bool.fromEnvironment('USE_EMULATORS', defaultValue: false);

class MapPage extends ConsumerStatefulWidget {
  const MapPage({super.key});

  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage> {
  final MapController mapController = MapController();
  LatLng? userCenter;
  List<dynamic> suggestions = [];
  final TextEditingController searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    ref.read(seedSpotsProvider).call();
    _initLocation();
  }

  Future<void> _initLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever || perm == LocationPermission.denied) {
        setState(() => userCenter = const LatLng(52.520008, 13.404954)); // Berlin fallback
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      setState(() => userCenter = LatLng(pos.latitude, pos.longitude));
      mapController.move(userCenter!, 14);
    } catch (_) {
      setState(() => userCenter = const LatLng(52.520008, 13.404954));
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      if (value.trim().isEmpty) {
        setState(() => suggestions = []);
        return;
      }
      try {
        final callable = FirebaseFunctions.instance.httpsCallable('nominatimSearch');
        final res = await callable.call({'q': value, 'limit': 5});
        setState(() => suggestions = (res.data as List?) ?? []);
      } catch (_) {
        setState(() => suggestions = []);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spotsAsync = ref.watch(spotsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('puffpoint'),
        actions: [
          IconButton(
            onPressed: () => context.push('/admin'),
            icon: const Icon(Icons.admin_panel_settings),
          ),
          IconButton(
            onPressed: () => context.push('/spot/new'),
            icon: const Icon(Icons.add_location_alt),
          ),
        ],
        bottom: kUseEmulators
            ? const PreferredSize(
                preferredSize: Size.fromHeight(18),
                child: Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text('EMULATORS', style: TextStyle(fontSize: 12, color: Colors.orange)),
                ),
              )
            : null,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                TextField(
                  controller: searchController,
                  onChanged: _onSearchChanged,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Suche Ort / Adresse',
                  ),
                ),
                if (suggestions.isNotEmpty)
                  SizedBox(
                    height: 150,
                    child: ListView.builder(
                      itemCount: suggestions.length,
                      itemBuilder: (context, i) {
                        final s = suggestions[i] as Map;
                        return ListTile(
                          title: Text('${s['display_name']}'),
                          onTap: () {
                            final lat = double.parse(s['lat'] as String);
                            final lon = double.parse(s['lon'] as String);
                            mapController.move(LatLng(lat, lon), 15);
                            setState(() => suggestions = []);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: spotsAsync.when(
              data: (spots) {
                final markers = spots
                    .map((s) => Marker(
                          width: 40,
                          height: 40,
                          point: LatLng(s.coords.latitude, s.coords.longitude),
                          child: GestureDetector(
                            onTap: () => _openSpotSheet(context, s),
                            child: const Icon(Icons.location_on, color: Colors.red, size: 32),
                          ),
                        ))
                    .toList();
                return Stack(
                  children: [
                    FlutterMap(
                      mapController: mapController,
                      options: MapOptions(
                        initialCenter: userCenter ?? const LatLng(52.520008, 13.404954),
                        initialZoom: 12,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                          subdomains: const ['a', 'b', 'c'],
                          userAgentPackageName: 'com.puffpoint.app',
                          retinaMode: true,
                          tileProvider: NetworkTileProvider(),
                        ),
                        MarkerClusterLayerWidget(
                          options: MarkerClusterLayerOptions(
                            markers: markers,
                            maxClusterRadius: 45,
                            size: const Size(40, 40),
                            builder: (context, clusterMarkers) => CircleAvatar(
                              child: Text('${clusterMarkers.length}')
                            ),
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(4)),
                        child: const Text('© OpenStreetMap contributors', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final center = userCenter ?? const LatLng(52.520008, 13.404954);
          mapController.move(center, 14);
        },
        child: const Icon(Icons.my_location),
      ),
    );
  }

  void _openSpotSheet(BuildContext context, Spot spot) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(spot.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('${spot.avgRating.toStringAsFixed(1)} ★  (${spot.ratingsCount})'),
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => openInExternalMaps(
                      lat: spot.coords.latitude,
                      lng: spot.coords.longitude,
                      label: spot.title,
                    ),
                    icon: const Icon(Icons.directions),
                    label: const Text('Route'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        showDragHandle: true,
                        builder: (_) => ReviewForm(spotId: spot.id),
                      );
                    },
                    icon: const Icon(Icons.rate_review),
                    label: const Text('Review'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              PhotoUploader(spotId: spot.id),
            ],
          ),
        );
      },
    );
  }
}
