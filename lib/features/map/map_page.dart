import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:http/http.dart' as http;
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:smart_pulchowk/core/constants/app_constants.dart';
import 'package:smart_pulchowk/core/services/storage_service.dart';
import 'package:smart_pulchowk/core/services/haptic_service.dart';
import 'package:smart_pulchowk/core/theme/app_theme.dart';
import 'package:smart_pulchowk/features/map/widgets/category_filter_bar.dart';
import 'package:smart_pulchowk/features/map/widgets/location_details_sheet.dart';
import 'package:smart_pulchowk/features/map/widgets/chat_bot_widget.dart';
import 'package:smart_pulchowk/features/map/models/chatbot_response.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Icon URLs (single source of truth)
// ─────────────────────────────────────────────────────────────────────────────
const Map<String, String> _kIconUrls = {
  'bank': 'https://cdn-icons-png.flaticon.com/512/6395/6395444.png',
  'food': 'https://cdn-icons-png.freepik.com/512/11167/11167112.png',
  'library': 'https://cdn-icons-png.freepik.com/512/7985/7985904.png',
  'department': 'https://cdn-icons-png.flaticon.com/512/7906/7906888.png',
  'temple': 'https://cdn-icons-png.flaticon.com/512/1183/1183391.png',
  'gym': 'https://cdn-icons-png.flaticon.com/512/11020/11020519.png',
  'football': 'https://cdn-icons-png.freepik.com/512/8893/8893610.png',
  'cricket': 'https://i.postimg.cc/cLb6QFC1/download.png',
  'sports': 'https://i.postimg.cc/mDW05pSw-/volleyball.png',
  'hostel': 'https://cdn-icons-png.flaticon.com/512/7804/7804352.png',
  'lab': 'https://cdn-icons-png.flaticon.com/256/12348/12348567.png',
  'helipad': 'https://cdn-icons-png.flaticon.com/512/5695/5695654.png',
  'parking':
      'https://cdn.iconscout.com/icon/premium/png-256-thumb/parking-place-icon-svg-download-png-897308.png',
  'electrical': 'https://cdn-icons-png.flaticon.com/512/9922/9922144.png',
  'music': 'https://cdn-icons-png.flaticon.com/512/5905/5905923.png',
  'energy': 'https://cdn-icons-png.flaticon.com/512/10053/10053795.png',
  'helm':
      'https://png.pngtree.com/png-clipart/20230918/original/pngtree-aircraftplaneairplane-map-pin-icon-aviation-aircraft-transportation-vector-png-image_12363891.png',
  'garden': 'https://cdn-icons-png.flaticon.com/512/15359/15359437.png',
  'store': 'https://cdn-icons-png.flaticon.com/512/3448/3448673.png',
  'quarter': 'https://static.thenounproject.com/png/331579-200.png',
  'robotics': 'https://cdn-icons-png.flaticon.com/512/10681/10681183.png',
  'clinic': 'https://cdn-icons-png.flaticon.com/512/10714/10714002.png',
  'badminton': 'https://static.thenounproject.com/png/198230-200.png',
  'entrance': 'https://i.postimg.cc/jjLDcb6p/image-removebg-preview.png',
  'office': 'https://cdn-icons-png.flaticon.com/512/3846/3846807.png',
  'building': 'https://cdn-icons-png.flaticon.com/512/5193/5193760.png',
  'block': 'https://cdn-icons-png.flaticon.com/512/3311/3311565.png',
  'cave': 'https://cdn-icons-png.flaticon.com/512/210/210567.png',
  'fountain':
      'https://cdn.iconscout.com/icon/free/png-256/free-fountain-icon-svg-download-png-449881.png',
  'water':
      'https://static.vecteezy.com/system/resources/thumbnails/044/570/540/small_2x/single-water-drop-on-transparent-background-free-png.png',
  'workshop': 'https://cdn-icons-png.flaticon.com/512/10747/10747285.png',
  'toilet':
      'https://www.shareicon.net/data/2015/09/21/644170_pointer_512x512.png',
  'bridge':
      'https://icons.veryicon.com/png/o/phone/map-anchor-4-colors/01_bridge-blue.png',
  'marker':
      'https://toppng.com/uploads/preview/eat-play-do-icon-map-marker-115548254600u9yjx6qhj.png',
};

// ─────────────────────────────────────────────────────────────────────────────
// MapPage
// ─────────────────────────────────────────────────────────────────────────────

class MapPage extends StatefulWidget {
  final List<double>? initialLocation; // [lng, lat]
  const MapPage({super.key, this.initialLocation});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  MapLibreMapController? _mapController;
  bool _isStyleLoaded = false;
  bool _isSatellite = false;

  List<Map<String, dynamic>> _allLocations = [];
  Set<String> _selectedCategories = {'all'};

  final Map<String, Uint8List> _iconCache = {};
  final Set<String> _failedIcons = {};

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _showSuggestions = false;

  bool _isNavigating = false;
  Map<String, dynamic>? _startPoint;
  Map<String, dynamic>? _endPoint;
  List<LatLng>? _routeCoordinates;
  String _routeDistance = '';
  String _routeDuration = '';
  bool _isCalculatingRoute = false;
  bool _isLocating = false;
  bool _showMyLocation = false;
  bool _isNavigationPanelExpanded = true;
  bool _isTogglingMapType = false;
  double _cameraBearing = 0.0;

  static const LatLng _pulchowkCenter = LatLng(
    27.68222689200303,
    85.32121137093469,
  );
  static const double _initialZoom = 17.0;

  static final LatLngBounds _campusBounds = LatLngBounds(
    southwest: const LatLng(27.6792, 85.3165),
    northeast: const LatLng(27.6848, 85.3262),
  );

  static const String _satelliteStyle = '''
{
  "version": 8,
  "glyphs": "https://demotiles.maplibre.org/font/{fontstack}/{range}.pbf",
  "sources": {
    "arcgis-world-imagery": {
      "type": "raster",
      "tiles": ["https://services.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}"],
      "tileSize": 256
    }
  },
  "layers": [{"id": "satellite","type": "raster","source": "arcgis-world-imagery","minzoom": 0,"maxzoom": 22}]
}
''';

  static const String _mapStyle =
      'https://basemaps.cartocdn.com/gl/voyager-gl-style/style.json';

  String get _currentStyle => _isSatellite ? _satelliteStyle : _mapStyle;

  List<Map<String, dynamic>> get _visibleLocations {
    if (_selectedCategories.contains('all')) return _allLocations;

    final sportsIds = {'football', 'cricket', 'sports', 'badminton'};

    return _allLocations.where((l) {
      final icon = l['icon'] as String;

      // Check if location's direct icon is selected
      if (_selectedCategories.contains(icon)) return true;

      // Special handling for grouped categories
      if (_selectedCategories.contains('sports') && sportsIds.contains(icon)) {
        return true;
      }
      if (_selectedCategories.contains('gym') && icon == 'gym') {
        return true;
      }

      return false;
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredSuggestions {
    if (_searchQuery.trim().isEmpty) return [];
    final query = _searchQuery.toLowerCase();
    return _visibleLocations
        .where((loc) => (loc['title'] as String).toLowerCase().contains(query))
        .take(8)
        .toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // ── GeoJSON ──────────────────────────────────────────────────────────────

  Future<void> _loadGeoJSON() async {
    try {
      if (_allLocations.isEmpty) {
        // Try reading from cache first
        final cached = StorageService.readCache(AppConstants.cacheMapLocations);
        if (cached != null && cached is List) {
          _allLocations = List<Map<String, dynamic>>.from(
            cached.map((e) => Map<String, dynamic>.from(e as Map)),
          );
        }

        if (_allLocations.isEmpty) {
          final String json = await rootBundle.loadString(
            'assets/geojson/pulchowk.json',
          );
          final Map<String, dynamic> geojson = jsonDecode(json);
          final List<dynamic> features = geojson['features'] ?? [];
          final locations = <Map<String, dynamic>>[];
          for (int i = 1; i < features.length; i++) {
            final feature = features[i];
            final props = feature['properties'] ?? {};
            final geometry = feature['geometry'] ?? {};
            if (props['description'] == null && props['title'] == null)
              continue;
            List<double> coords;
            if (geometry['type'] == 'Point') {
              coords = List<double>.from(geometry['coordinates']);
            } else if (geometry['type'] == 'Polygon') {
              coords = _getPolygonCentroid(geometry['coordinates'][0]);
            } else {
              continue;
            }
            final title = props['description'] ?? props['title'] ?? 'Unknown';
            locations.add({
              'title': title,
              'description': props['about'] ?? '',
              'images': props['image'],
              'coordinates': coords,
              'icon': _getIconForDescription(title),
            });
          }
          _allLocations = locations;
          // Clear old cache before saving new data
          await StorageService.deleteCache(AppConstants.cacheMapLocations);
          // Save to cache
          await StorageService.writeCache(
            AppConstants.cacheMapLocations,
            _allLocations,
          );
        }
        if (mounted) setState(() {});
      }
      if (_mapController != null && _isStyleLoaded) {
        await _addCampusMask();
        await _addMarkersToMap();
      }
    } catch (e) {
      debugPrint('Error loading GeoJSON: $e');
    }
  }

  List<double> _getPolygonCentroid(List<dynamic> coordinates) {
    double sumLng = 0, sumLat = 0;
    for (var c in coordinates) {
      sumLng += c[0];
      sumLat += c[1];
    }
    return [sumLng / coordinates.length, sumLat / coordinates.length];
  }

  String _getIconForDescription(String desc) {
    final d = desc.toLowerCase();
    if (d.contains('bank') || d.contains('atm')) return 'bank';
    if (d.contains('mess') || d.contains('canteen') || d.contains('food')) {
      return 'food';
    }
    if (d.contains('library')) return 'library';
    if (d.contains('department')) return 'department';
    if (d.contains('mandir')) return 'temple';
    if (d.contains('gym')) return 'gym';
    if (d.contains('football')) return 'football';
    if (d.contains('cricket')) return 'cricket';
    if (d.contains('basketball') || d.contains('volleyball')) return 'sports';
    if (d.contains('hostel')) return 'hostel';
    if (d.contains('lab')) return 'lab';
    if (d.contains('helicopter')) return 'helipad';
    if (d.contains('parking')) return 'parking';
    if (d.contains('electrical club')) return 'electrical';
    if (d.contains('music club')) return 'music';
    if (d.contains('center for energy')) return 'energy';
    if (d.contains('the helm')) return 'helm';
    if (d.contains('park') ||
        d.contains('garden') ||
        d.contains('pi chautari')) {
      return 'garden';
    }
    if (d.contains('store') || d.contains('bookshop')) return 'store';
    if (d.contains('quarter')) return 'quarter';
    if (d.contains('robotics')) return 'robotics';
    if (d.contains('clinic') || d.contains('health')) return 'clinic';
    if (d.contains('badminton')) return 'badminton';
    if (d.contains('entrance')) return 'entrance';
    if (d.contains('office') ||
        d.contains('ntbns') ||
        d.contains('seds') ||
        d.contains('cids')) {
      return 'office';
    }
    if (d.contains('building')) return 'building';
    if (d.contains('block') || d.contains('embark')) return 'block';
    if (d.contains('cave')) return 'cave';
    if (d.contains('fountain')) return 'fountain';
    if (d.contains('water')) return 'water';
    if (d.contains('workshop')) return 'workshop';
    if (d.contains('toilet') || d.contains('washroom')) return 'toilet';
    if (d.contains('bridge')) return 'bridge';
    return 'marker';
  }

  Color _getMarkerColor(String iconType) {
    switch (iconType) {
      case 'food':
        return Colors.orange;
      case 'library':
        return Colors.purple;
      case 'department':
        return Colors.blue;
      case 'hostel':
        return Colors.teal;
      case 'lab':
        return Colors.indigo;
      case 'office':
        return Colors.blueGrey;
      case 'gym':
      case 'football':
      case 'cricket':
      case 'sports':
      case 'badminton':
        return Colors.green;
      case 'parking':
        return Colors.grey;
      case 'clinic':
        return Colors.red;
      case 'garden':
        return Colors.lightGreen;
      case 'store':
        return Colors.amber;
      case 'bank':
        return Colors.blue;
      case 'temple':
        return Colors.deepOrange;
      case 'water':
      case 'fountain':
        return Colors.cyan;
      case 'toilet':
        return Colors.brown;
      case 'entrance':
        return Colors.deepPurple;
      default:
        return AppColors.primary;
    }
  }

  // ── Campus mask ───────────────────────────────────────────────────────────

  Future<void> _addCampusMask() async {
    if (_mapController == null) return;
    try {
      final String json = await rootBundle.loadString(
        'assets/geojson/pulchowk.json',
      );
      final Map<String, dynamic> geojson = jsonDecode(json);
      try {
        await _mapController!.removeLayer('campus-mask');
        await _mapController!.removeSource('campus-mask-source');
      } catch (_) {}
      await _mapController!.addGeoJsonSource('campus-mask-source', geojson);
      await _mapController!.addFillLayer(
        'campus-mask-source',
        'campus-mask',
        FillLayerProperties(
          fillColor: '#FFFFFF',
          fillOpacity: _isSatellite ? 0.9 : 0.75,
          fillOutlineColor: '#4A5568',
        ),
        filter: [
          'all',
          [
            '==',
            ['geometry-type'],
            'Polygon',
          ],
          [
            '!',
            ['has', 'description'],
          ],
        ],
      );
    } catch (e) {
      debugPrint('Error adding campus mask: $e');
    }
  }

  // ── Markers ───────────────────────────────────────────────────────────────

  Future<Uint8List> _createFallbackMarker(String iconType) async {
    final color = _getMarkerColor(iconType);
    const size = 280;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawCircle(
      const Offset(140, 140),
      138,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      const Offset(140, 140),
      138,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<void> _loadIconImages() async {
    if (_mapController == null) return;
    await Future.wait(
      _kIconUrls.entries.map((entry) async {
        try {
          final iconName = '${entry.key}-icon';
          if (_iconCache.containsKey(entry.key)) {
            await _mapController!.addImage(iconName, _iconCache[entry.key]!);
            return;
          }
          final response = await http
              .get(Uri.parse(entry.value))
              .timeout(const Duration(seconds: 5));
          if (response.statusCode == 200) {
            _iconCache[entry.key] = response.bodyBytes;
            await _mapController!.addImage(iconName, response.bodyBytes);
          } else {
            throw Exception('HTTP ${response.statusCode}');
          }
        } catch (_) {
          _failedIcons.add(entry.key);
          try {
            final fb = await _createFallbackMarker(entry.key);
            await _mapController!.addImage('${entry.key}-icon', fb);
          } catch (_) {}
        }
      }),
    );
    if (_failedIcons.isNotEmpty) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) _retryFailedIcons();
      });
    }
  }

  Future<void> _retryFailedIcons() async {
    if (_mapController == null || _failedIcons.isEmpty) return;
    final toRetry = Set<String>.from(_failedIcons);
    for (final key in toRetry) {
      if (!_kIconUrls.containsKey(key)) continue;
      try {
        final response = await http
            .get(Uri.parse(_kIconUrls[key]!))
            .timeout(const Duration(seconds: 8));
        if (response.statusCode == 200) {
          _iconCache[key] = response.bodyBytes;
          await _mapController!.addImage('$key-icon', response.bodyBytes);
          _failedIcons.remove(key);
        }
      } catch (_) {}
    }
  }

  Future<void> _addMarkersToMap() async {
    if (_mapController == null) return;
    final locations = _visibleLocations;
    try {
      try {
        await _mapController!.removeLayer('markers-layer');
        await _mapController!.removeSource('markers-source');
      } catch (_) {}

      await _loadIconImages();

      final features = locations.map((location) {
        final coords = location['coordinates'] as List<double>;
        final iconType = location['icon'] as String;
        return {
          'type': 'Feature',
          'properties': {'icon': '$iconType-icon', 'title': location['title']},
          'geometry': {'type': 'Point', 'coordinates': coords},
        };
      }).toList();

      await _mapController!.addGeoJsonSource('markers-source', {
        'type': 'FeatureCollection',
        'features': features,
      });
      await _mapController!.addSymbolLayer(
        'markers-source',
        'markers-layer',
        SymbolLayerProperties(
          iconImage: ['get', 'icon'],
          iconSize: [
            'match',
            ['get', 'icon'],
            'cricket-icon',
            0.1,
            'sports-icon',
            0.11,
            'marker-icon',
            0.08,
            'parking-icon',
            0.3,
            'badminton-icon',
            0.3,
            'lab-icon',
            0.24,
            'quarter-icon',
            0.3,
            'fountain-icon',
            0.3,
            0.12,
          ],
          iconAnchor: 'center',
          iconAllowOverlap: false,
          iconOptional: true,
          textField: ['get', 'title'],
          textSize: 10,
          textAnchor: 'top',
          textOffset: [0, 1.2],
          textAllowOverlap: false,
          textOptional: true,
          textColor: _isSatellite ? '#FFFFFF' : '#000000',
          textHaloColor: _isSatellite ? '#000000' : '#FFFFFF',
          textHaloWidth: 1.5,
          textMaxWidth: 8,
        ),
      );
    } catch (e) {
      debugPrint('Error adding markers: $e');
    }
  }

  // ── Map callbacks ─────────────────────────────────────────────────────────

  void _onMapCreated(MapLibreMapController controller) =>
      _mapController = controller;

  void _onStyleLoaded() {
    setState(() {
      _isStyleLoaded = true;
      _isTogglingMapType = false;
    });
    _loadGeoJSON();
  }

  void _onMapClick(Point<double> point, LatLng coordinates) async {
    if (_mapController == null) return;
    if (_searchFocusNode.hasFocus || _showSuggestions) {
      FocusScope.of(context).unfocus();
      setState(() => _showSuggestions = false);
    }
    try {
      final tapRect = Rect.fromLTRB(
        point.x - 30,
        point.y - 30,
        point.x + 30,
        point.y + 50,
      );
      final features = await _mapController!.queryRenderedFeaturesInRect(
        tapRect,
        ['markers-layer'],
        null,
      );
      if (features.isNotEmpty) {
        final feature = features.first;
        String? title;
        if (feature is Map) {
          final props = feature['properties'];
          if (props is Map) title = props['title']?.toString();
          title ??= feature['title']?.toString();
        }
        if (title != null && title.isNotEmpty) {
          final location = _allLocations.firstWhere(
            (l) => l['title'] == title,
            orElse: () => <String, dynamic>{},
          );
          if (location.isNotEmpty) {
            _showLocationDetails(location);
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('Error querying features: $e');
    }
  }

  // ── Location details ──────────────────────────────────────────────────────

  void _showLocationDetails(Map<String, dynamic> location) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => LocationDetailsSheet(
        title: location['title'] ?? 'Unknown Location',
        description: location['description'],
        images: location['images'],
        onNavigate: () {
          Navigator.pop(context);
          _startNavigation(location);
        },
      ),
    );
  }

  void _flyToLocation(Map<String, dynamic> location, {bool showPopup = true}) {
    if (_mapController == null) return;
    final coords = location['coordinates'] as List<double>;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _searchFocusNode.unfocus();
      setState(() {
        _showSuggestions = false;
        _searchQuery = '';
        _searchController.clear();
      });
      await Future.delayed(const Duration(milliseconds: 300));
      if (_mapController != null && mounted) {
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(coords[1], coords[0]), 19),
        );
      }
      if (showPopup && mounted) _showLocationDetails(location);
    });
  }

  // ── Location permission & GPS ─────────────────────────────────────────────

  bool _isWithinCampus(LatLng loc) =>
      loc.latitude >= _campusBounds.southwest.latitude &&
      loc.latitude <= _campusBounds.northeast.latitude &&
      loc.longitude >= _campusBounds.southwest.longitude &&
      loc.longitude <= _campusBounds.northeast.longitude;

  Future<void> _goToCurrentLocation() async {
    if (_mapController == null || _isLocating) return;
    if (_showMyLocation) {
      setState(() => _showMyLocation = false);
      return;
    }
    setState(() => _isLocating = true);
    try {
      bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted)
          _showSnack(
            'Please enable location services',
            action: ('Settings', geo.Geolocator.openLocationSettings),
          );
        return;
      }
      geo.LocationPermission permission =
          await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
        if (permission == geo.LocationPermission.denied) {
          if (mounted) _showSnack('Location permission required');
          return;
        }
      }
      if (permission == geo.LocationPermission.deniedForever) {
        if (mounted)
          _showSnack(
            'Location permission denied.',
            action: ('Settings', geo.Geolocator.openAppSettings),
          );
        return;
      }
      final pos = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      final latLng = LatLng(pos.latitude, pos.longitude);
      if (_isWithinCampus(latLng)) {
        setState(() => _showMyLocation = true);
        if (mounted && _mapController != null) {
          await _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(latLng, 19),
          );
        }
      } else {
        if (mounted) _showSnack('You are outside the campus area');
      }
    } on TimeoutException {
      if (mounted) _showSnack('Location request timed out');
    } catch (e) {
      if (mounted) _showSnack('Unable to get your location');
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _showSnack(String msg, {(String, VoidCallback)? action}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.orange[700],
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: action != null
            ? SnackBarAction(
                label: action.$1,
                textColor: Colors.white,
                onPressed: action.$2,
              )
            : null,
      ),
    );
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  void _startNavigation(Map<String, dynamic> destination) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Choose Starting Point',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Navigate to: ${destination['title']}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.my_location, color: Colors.blue[600]),
              ),
              title: const Text(
                'Use My Location',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Get directions from your current position'),
              onTap: () {
                Navigator.pop(ctx);
                _startNavigationWithLocation(destination);
              },
            ),
            const Divider(),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.place, color: Colors.green[600]),
              ),
              title: const Text(
                'Choose Another Place',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Select a location from campus as start'),
              onTap: () {
                Navigator.pop(ctx);
                _showStartPointPicker(destination);
              },
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  void _startNavigationWithLocation(Map<String, dynamic> destination) async {
    final coords = destination['coordinates'] as List<double>;
    setState(() {
      _isNavigating = true;
      _isNavigationPanelExpanded = true;
      _endPoint = {
        'coords': coords,
        'name': destination['title'] ?? 'Destination',
      };
      _startPoint = null;
      _routeCoordinates = null;
      _routeDistance = '';
      _routeDuration = '';
    });
    try {
      bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isNavigating = false);
        return;
      }
      geo.LocationPermission perm = await geo.Geolocator.checkPermission();
      if (perm == geo.LocationPermission.denied) {
        perm = await geo.Geolocator.requestPermission();
      }
      if (perm == geo.LocationPermission.denied ||
          perm == geo.LocationPermission.deniedForever) {
        setState(() => _isNavigating = false);
        return;
      }
      final pos = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      final latLng = LatLng(pos.latitude, pos.longitude);
      if (_isWithinCampus(latLng)) {
        setState(
          () => _startPoint = {
            'coords': [latLng.longitude, latLng.latitude],
            'name': 'Your Location',
          },
        );
        _getDirections();
      } else {
        if (mounted) _showSnack('You are outside the campus area');
        setState(() => _isNavigating = false);
      }
    } catch (_) {
      if (mounted) _showSnack('Unable to get your location');
      setState(() => _isNavigating = false);
    }
  }

  void _showStartPointPicker(Map<String, dynamic> destination) async {
    final destTitle = destination['title']?.toString() ?? '';
    final all = _allLocations.where((l) => l['title'] != destTitle).toList()
      ..sort((a, b) => (a['title'] as String).compareTo(b['title'] as String));
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _StartPointPickerSheet(
        allLocations: all,
        destination: destination,
        onLocationSelected: (loc) {
          Navigator.pop(context);
          _startNavigationFromPlace(loc, destination);
        },
      ),
    );
  }

  void _startNavigationFromPlace(
    Map<String, dynamic> startLocation,
    Map<String, dynamic> destination,
  ) {
    setState(() {
      _isNavigating = true;
      _isNavigationPanelExpanded = true;
      _startPoint = {
        'coords': startLocation['coordinates'],
        'name': startLocation['title'] ?? 'Start',
      };
      _endPoint = {
        'coords': destination['coordinates'],
        'name': destination['title'] ?? 'Destination',
      };
      _routeCoordinates = null;
      _routeDistance = '';
      _routeDuration = '';
    });
    _getDirections();
  }

  double _haversineDistance(List<double> c1, List<double> c2) {
    const R = 6371e3;
    final phi1 = c1[1] * pi / 180;
    final phi2 = c2[1] * pi / 180;
    final dPhi = (c2[1] - c1[1]) * pi / 180;
    final dLam = (c2[0] - c1[0]) * pi / 180;
    final a =
        sin(dPhi / 2) * sin(dPhi / 2) +
        cos(phi1) * cos(phi2) * sin(dLam / 2) * sin(dLam / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  Future<void> _getDirections() async {
    if (_startPoint == null || _endPoint == null) return;
    setState(() => _isCalculatingRoute = true);
    final sc = _startPoint!['coords'] as List<double>;
    final ec = _endPoint!['coords'] as List<double>;
    final straight = _haversineDistance(sc, ec);
    if (straight < 20) {
      _createStraightLine(sc, ec, straight);
      setState(() => _isCalculatingRoute = false);
      return;
    }
    final url =
        'https://router.project-osrm.org/route/v1/foot/${sc[0]},${sc[1]};${ec[0]},${ec[1]}?overview=full&geometries=geojson&radiuses=200;200';
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final routes = data['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final route = routes[0];
          final coords = (route['geometry']['coordinates'] as List)
              .map<LatLng>((c) => LatLng(c[1], c[0]))
              .toList();
          final distance = route['distance'] as num;
          if (distance > 2000 || distance > straight * 3) {
            _createStraightLine(sc, ec, straight);
          } else {
            setState(() {
              _routeCoordinates = coords;
              _routeDistance = distance < 1000
                  ? '${distance.round()} m'
                  : '${(distance / 1000).toStringAsFixed(1)} km';
              final secs = distance / 1.2;
              _routeDuration = secs < 60
                  ? '${secs.round()} sec'
                  : '${(secs / 60).round()} min';
              _isNavigationPanelExpanded =
                  false; // Auto-collapse when route found
            });
            _drawRoute();
          }
        } else {
          _createStraightLine(sc, ec, straight);
        }
      } else {
        _createStraightLine(sc, ec, straight);
      }
    } catch (_) {
      _createStraightLine(sc, ec, straight);
    } finally {
      setState(() => _isCalculatingRoute = false);
    }
  }

  void _createStraightLine(
    List<double> start,
    List<double> end,
    double distance,
  ) {
    setState(() {
      _routeCoordinates = [LatLng(start[1], start[0]), LatLng(end[1], end[0])];
      _routeDistance = distance < 1000
          ? '${distance.round()} m'
          : '${(distance / 1000).toStringAsFixed(1)} km';
      final secs = distance / 1.2;
      _routeDuration = secs < 60
          ? '${secs.round()} sec'
          : '${(secs / 60).round()} min';
      _isNavigationPanelExpanded = false;
    });
    _drawRoute();
  }

  Future<void> _drawRoute() async {
    if (_mapController == null || _routeCoordinates == null) return;
    try {
      await _mapController!.removeLayer('route-layer');
      await _mapController!.removeSource('route-source');
    } catch (_) {}
    final sc = _startPoint!['coords'] as List<double>;
    final ec = _endPoint!['coords'] as List<double>;
    final coordsList = <List<double>>[
      [sc[0], sc[1]],
      ..._routeCoordinates!.map((c) => [c.longitude, c.latitude]),
      [ec[0], ec[1]],
    ];
    await _mapController!.addGeoJsonSource('route-source', {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'geometry': {'type': 'LineString', 'coordinates': coordsList},
        },
      ],
    });
    await _mapController!.addLineLayer(
      'route-source',
      'route-layer',
      LineLayerProperties(
        lineColor: '#2563eb',
        lineWidth: 5,
        lineOpacity: 0.8,
        lineCap: 'round',
        lineJoin: 'round',
      ),
    );
    if (_routeCoordinates!.length >= 2) {
      final bounds = LatLngBounds(
        southwest: LatLng(
          _routeCoordinates!.map((c) => c.latitude).reduce(min),
          _routeCoordinates!.map((c) => c.longitude).reduce(min),
        ),
        northeast: LatLng(
          _routeCoordinates!.map((c) => c.latitude).reduce(max),
          _routeCoordinates!.map((c) => c.longitude).reduce(max),
        ),
      );
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(
          bounds,
          left: 50,
          top: 150,
          right: 50,
          bottom: 100,
        ),
      );
    }
  }

  void _exitNavigation() async {
    try {
      await _mapController?.removeLayer('route-layer');
      await _mapController?.removeSource('route-source');
    } catch (_) {}
    setState(() {
      _isNavigating = false;
      _startPoint = null;
      _endPoint = null;
      _routeCoordinates = null;
      _routeDistance = '';
      _routeDuration = '';
    });
  }

  void _toggleMapType() {
    if (_isTogglingMapType || !_isStyleLoaded) return;
    setState(() {
      _isTogglingMapType = true;
      _isSatellite = !_isSatellite;
      _isStyleLoaded = false;
    });
  }

  void _onCategorySelected(String catId) {
    setState(() {
      if (catId == 'all') {
        _selectedCategories = {'all'};
      } else {
        // Remove 'all' if adding a specific category
        _selectedCategories.remove('all');

        if (_selectedCategories.contains(catId)) {
          _selectedCategories.remove(catId);
        } else {
          _selectedCategories.add(catId);
        }

        // Default back to 'all' if everything is deselected
        if (_selectedCategories.isEmpty) {
          _selectedCategories = {'all'};
        }
      }
    });

    if (_isStyleLoaded && _mapController != null) _addMarkersToMap();
  }

  // ── ChatBot location handling ──
  void _handleChatBotLocations(List<ChatBotLocation> locations, String action) {
    if (locations.isEmpty) return;

    final first = locations.first;
    final targetLatLng = LatLng(first.lat, first.lng);

    if (action == 'show_route') {
      // If AI says show route, try to find the match in our markers or just route to latlng
      final destinationMatch = _allLocations.firstWhere(
        (l) => l['id'] == first.buildingId,
        orElse: () => _allLocations.isNotEmpty ? _allLocations.first : {},
      );
      if (destinationMatch.isNotEmpty) {
        _showStartPointPicker(destinationMatch);
      }
    } else {
      // Just center on the location
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(targetLatLng, 17.5),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final bottomNavHeight = bottomPad + 38.0;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // ── MapLibre ──
            MapLibreMap(
              key: const ValueKey('map_libre_main'),
              styleString: _currentStyle,
              initialCameraPosition: const CameraPosition(
                target: _pulchowkCenter,
                zoom: _initialZoom,
              ),
              onMapCreated: _onMapCreated,
              onStyleLoadedCallback: _onStyleLoaded,
              onMapClick: _onMapClick,
              myLocationEnabled: _showMyLocation,
              myLocationTrackingMode: MyLocationTrackingMode.none,
              myLocationRenderMode: _showMyLocation
                  ? MyLocationRenderMode.compass
                  : MyLocationRenderMode.normal,
              trackCameraPosition: true,
              compassEnabled: false,
              onCameraIdle: () {
                if (_mapController != null) {
                  final bearing =
                      _mapController!.cameraPosition?.bearing ?? 0.0;
                  if (bearing != _cameraBearing) {
                    setState(() => _cameraBearing = bearing);
                  }
                }
              },
              cameraTargetBounds: CameraTargetBounds(_campusBounds),
              minMaxZoomPreference: MinMaxZoomPreference(
                16,
                _isSatellite ? 18.45 : 20,
              ),
              scrollGesturesEnabled: true,
              tiltGesturesEnabled: false,
              rotateGesturesEnabled: true,
              doubleClickZoomEnabled: true,
              attributionButtonMargins: Point(8, bottomNavHeight + 4),
            ),

            // ── Loading overlay ──
            if (!_isStyleLoaded)
              Container(
                color: isDark
                    ? const Color(0xFF0D1321)
                    : const Color(0xFFF8FAFC),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 2.5,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Loading campus map…',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Search + Category bar (top) — hidden during navigation ──
            if (!_isNavigating)
              Positioned(
                top: topPad + 8,
                left: 16,
                right: 16,
                child: TapRegion(
                  onTapOutside: (_) {
                    if (_searchFocusNode.hasFocus || _showSuggestions) {
                      _searchFocusNode.unfocus();
                      setState(() => _showSuggestions = false);
                    }
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Search bar
                      _GlassContainer(
                        isDark: isDark,
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                focusNode: _searchFocusNode,
                                style: Theme.of(context).textTheme.bodyLarge,
                                onChanged: (v) => setState(() {
                                  _searchQuery = v;
                                  _showSuggestions = v.isNotEmpty;
                                }),
                                onTap: () => setState(
                                  () => _showSuggestions =
                                      _searchQuery.isNotEmpty,
                                ),
                                textInputAction: TextInputAction.search,
                                onSubmitted: (v) {
                                  if (v.isEmpty) return;
                                  setState(() {
                                    _searchQuery = v;
                                    _showSuggestions = v.isNotEmpty;
                                  });
                                  if (_filteredSuggestions.isNotEmpty) {
                                    _flyToLocation(_filteredSuggestions.first);
                                  }
                                },
                                decoration: InputDecoration(
                                  hintText:
                                      'Search labs, canteen, departments…',
                                  hintStyle: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant
                                        .withValues(alpha: 0.5),
                                  ),
                                  prefixIcon: Icon(
                                    Icons.search_rounded,
                                    color: AppColors.primary,
                                  ),
                                  suffixIcon: _searchQuery.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear_rounded),
                                          onPressed: () {
                                            haptics.selectionClick();
                                            setState(() {
                                              _searchController.clear();
                                              _searchQuery = '';
                                              _showSuggestions = false;
                                            });
                                          },
                                        )
                                      : null,
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              height: 24,
                              width: 1,
                              color: Theme.of(
                                context,
                              ).colorScheme.outline.withValues(alpha: 0.2),
                            ),
                            PopupMenuButton<String>(
                              onSelected: _onCategorySelected,
                              tooltip: 'Filter by category',
                              icon: Stack(
                                children: [
                                  Icon(
                                    Icons.tune_rounded,
                                    color: _selectedCategories.contains('all')
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant
                                        : AppColors.primary,
                                  ),
                                  if (!_selectedCategories.contains('all'))
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      child: Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isDark
                                                ? const Color(0xFF1E293B)
                                                : Colors.white,
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              offset: const Offset(0, 45),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              itemBuilder: (context) => kMapCategories.map((
                                cat,
                              ) {
                                final isActive = _selectedCategories.contains(
                                  cat.id,
                                );
                                return PopupMenuItem<String>(
                                  value: cat.id,
                                  child: Row(
                                    children: [
                                      Icon(
                                        cat.icon,
                                        size: 18,
                                        color: isActive
                                            ? cat.color
                                            : Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          cat.label,
                                          style: TextStyle(
                                            fontWeight: isActive
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            color: isActive ? cat.color : null,
                                          ),
                                        ),
                                      ),
                                      if (isActive)
                                        Icon(
                                          Icons.check_rounded,
                                          size: 16,
                                          color: cat.color,
                                        ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),

                      // Suggestions dropdown
                      if (_showSuggestions && _filteredSuggestions.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _GlassContainer(
                            isDark: isDark,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight:
                                    MediaQuery.of(context).size.height * 0.4,
                              ),
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: _filteredSuggestions.map((loc) {
                                    final iconType = loc['icon'] as String;
                                    final color = _getMarkerColor(iconType);
                                    return ListTile(
                                      leading: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.location_on_rounded,
                                          size: 18,
                                          color: color,
                                        ),
                                      ),
                                      title: Text(
                                        loc['title'],
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      subtitle: Text(
                                        'Pulchowk Campus',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                      onTap: () {
                                        haptics.lightImpact();
                                        _flyToLocation(loc);
                                      },
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ),
                        ),

                      if (_showSuggestions &&
                          _searchQuery.isNotEmpty &&
                          _filteredSuggestions.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _GlassContainer(
                            isDark: isDark,
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.search_off_rounded,
                                    size: 40,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant
                                        .withValues(alpha: 0.5),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No locations found',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Try a different search term',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

            // ── Navigation panel (top) ──
            if (_isNavigating)
              Positioned(
                top: topPad + 16,
                left: 16,
                right: 16,
                child: _GlassContainer(
                  isDark: isDark,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              haptics.selectionClick();
                              _exitNavigation();
                            },
                            icon: const Icon(Icons.close_rounded),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Directions',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () {
                              haptics.selectionClick();
                              setState(
                                () => _isNavigationPanelExpanded =
                                    !_isNavigationPanelExpanded,
                              );
                            },
                            icon: Icon(
                              _isNavigationPanelExpanded
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      if (_isNavigationPanelExpanded) ...[
                        const SizedBox(height: 16),
                        _RoutePoint(
                          label:
                              _startPoint?['name'] ?? 'Getting your location…',
                          isStart: true,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 5),
                          child: Column(
                            children: List.generate(
                              3,
                              (_) => Container(
                                width: 2,
                                height: 4,
                                margin: const EdgeInsets.symmetric(vertical: 1),
                                color: Theme.of(
                                  context,
                                ).colorScheme.outline.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        _RoutePoint(
                          label: _endPoint?['name'] ?? 'Destination',
                          isStart: false,
                        ),
                        if (_routeDistance.isNotEmpty &&
                            _routeDuration.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.directions_walk_rounded,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '$_routeDuration · $_routeDistance',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (_isCalculatingRoute)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Calculating route…',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),

            // ── Compass button ──
            if (_cameraBearing.abs() > 1)
              Positioned(
                bottom: bottomNavHeight + 128, // Stacked (64 + 64)
                right: 16,
                child: _MapButton(
                  isDark: isDark,
                  onTap: () {
                    haptics.selectionClick();
                    _mapController?.animateCamera(CameraUpdate.bearingTo(0));
                  },
                  child: Transform.rotate(
                    angle: -_cameraBearing * (pi / 180),
                    child: Icon(
                      Icons.navigation_rounded,
                      color: AppColors.error,
                      size: 26,
                    ),
                  ),
                ),
              ),

            // ── My Location button ──
            Positioned(
              bottom: bottomNavHeight + 64, // Stacked (64)
              right: 16,
              child: _MapButton(
                isDark: isDark,
                onTap: () {
                  haptics.mediumImpact();
                  _goToCurrentLocation();
                },
                child: _isLocating
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : Icon(
                        _showMyLocation
                            ? Icons.location_disabled_rounded
                            : Icons.my_location_rounded,
                        color: _showMyLocation
                            ? AppColors.error
                            : AppColors.primary,
                      ),
              ),
            ),

            // ── Map/Satellite toggle ──
            Positioned(
              bottom: bottomNavHeight + 0, // Flush with navbar
              left: 16,
              child: _GlassContainer(
                isDark: isDark,
                padding: const EdgeInsets.all(4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildMapTypeButton(
                      isDark: isDark,
                      label: 'Map',
                      isActive: !_isSatellite,
                      onTap: () {
                        if (_isSatellite) {
                          haptics.selectionClick();
                          _toggleMapType();
                        }
                      },
                    ),
                    const SizedBox(width: 4),
                    _buildMapTypeButton(
                      isDark: isDark,
                      label: 'Satellite',
                      isActive: _isSatellite,
                      onTap: () {
                        if (!_isSatellite) {
                          haptics.selectionClick();
                          _toggleMapType();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),

            // ── ChatBot Assistant (Stacked last to overlay everything) ──
            ChatBotWidget(
              bottomOffset: bottomNavHeight,
              onLocationsReturned: (locations, action) {
                _handleChatBotLocations(locations, action);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapTypeButton({
    required bool isDark,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: isActive
                ? AppColors.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper widgets
// ─────────────────────────────────────────────────────────────────────────────

class _GlassContainer extends StatelessWidget {
  final bool isDark;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const _GlassContainer({
    required this.isDark,
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1E293B).withValues(alpha: 0.9)
              : Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  final bool isDark;
  final VoidCallback onTap;
  final Widget child;

  const _MapButton({
    required this.isDark,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1E293B).withValues(alpha: 0.9)
              : Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _RoutePoint extends StatelessWidget {
  final String label;
  final bool isStart;

  const _RoutePoint({required this.label, required this.isStart});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isStart ? null : Theme.of(context).colorScheme.error,
            border: isStart
                ? Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 3,
                  )
                : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: isStart ? FontWeight.normal : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Start Point Picker Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _StartPointPickerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> allLocations;
  final Map<String, dynamic> destination;
  final void Function(Map<String, dynamic>) onLocationSelected;

  const _StartPointPickerSheet({
    required this.allLocations,
    required this.destination,
    required this.onLocationSelected,
  });

  @override
  State<_StartPointPickerSheet> createState() => _StartPointPickerSheetState();
}

class _StartPointPickerSheetState extends State<_StartPointPickerSheet> {
  final TextEditingController _sc = TextEditingController();

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _sc.text.toLowerCase();
    final filtered = widget.allLocations
        .where((loc) => (loc['title'] as String).toLowerCase().contains(query))
        .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: _sc,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search start location…',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  filled: true,
                  fillColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  suffixIcon: _sc.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            _sc.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No locations found',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: filtered.length,
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).padding.bottom + 8,
                      ),
                      itemBuilder: (_, i) {
                        final loc = filtered[i];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary.withValues(
                              alpha: 0.1,
                            ),
                            child: Icon(
                              Icons.place,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            loc['title'] ?? 'Unknown',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          onTap: () => widget.onLocationSelected(loc),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
