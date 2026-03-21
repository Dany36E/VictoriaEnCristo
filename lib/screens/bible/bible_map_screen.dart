import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../models/bible/bible_map_models.dart';
import '../../screens/bible/bible_reader_screen.dart';
import '../../services/bible/bible_maps_service.dart';
import '../../services/bible/bible_user_data_service.dart';
import '../../services/feedback_engine.dart';
import '../../theme/bible_reader_theme.dart';

// ─── CONSTANTES DE DISEÑO ────────────────────────────────────

const _kGold = Color(0xFFD4AF37);
const _kDarkGold = Color(0xFFB8860B);
const _kBeige = Color(0xFFF5E6C8);
const _kWaterBlue = Color(0xFFB3E0F2);
const _kPanelBg = Color(0xFFFFFBF5);
const _kDarkText = Color(0xFF1A1A1A);

const _kHolyLandCenter = LatLng(31.5, 35.0);
const _kInitialZoom = 7.5;

const _kEsriTopoUrl =
    'https://server.arcgisonline.com/ArcGIS/rest/services/'
    'World_Topo_Map/MapServer/tile/{z}/{y}/{x}';

/// Pantalla principal de mapas bíblicos interactivos.
class BibleMapScreen extends StatefulWidget {
  final int? initialBookNumber;

  const BibleMapScreen({super.key, this.initialBookNumber});

  @override
  State<BibleMapScreen> createState() => _BibleMapScreenState();
}

class _BibleMapScreenState extends State<BibleMapScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();

  // ─── Data ───
  List<BiblicalPlace> _allPlaces = [];
  List<HistoricalRoute> _allRoutes = [];
  List<HistoricalRegion> _allRegions = [];
  bool _loading = true;

  // ─── Filters ───
  String _selectedPeriod = 'all';

  // ─── Layer visibility ───
  bool _showPlaces = true;
  bool _showRoutes = true;
  bool _showRegions = true;
  bool _showLabels = true;

  // ─── Selection ───
  BiblicalPlace? _selectedPlace;

  // ─── UI state ───
  bool _showLayerPanel = false;

  // ─── Filtered data (cached per build) ───
  List<BiblicalPlace> _filteredPlaces = [];
  List<HistoricalRoute> _filteredRoutes = [];
  List<HistoricalRegion> _filteredRegions = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final svc = BibleMapsService.instance;
    final places = await svc.getPlaces();
    final routes = await svc.getRoutes();
    final regions = await svc.getRegions();

    if (!mounted) return;
    setState(() {
      _allPlaces = places;
      _allRoutes = routes;
      _allRegions = regions;
      _loading = false;
      _applyFilters();
    });
  }

  void _applyFilters() {
    final p = _selectedPeriod;
    _filteredPlaces = p == 'all'
        ? _allPlaces
        : _allPlaces.where((e) => e.periods.contains(p)).toList();
    _filteredRoutes = p == 'all'
        ? _allRoutes
        : _allRoutes.where((e) => e.period == p).toList();
    _filteredRegions = p == 'all'
        ? _allRegions
        : _allRegions.where((e) => e.periods.contains(p)).toList();
  }

  void _selectPeriod(String period) {
    FeedbackEngine.I.tap();
    setState(() {
      _selectedPeriod = period;
      _selectedPlace = null;
      _applyFilters();
    });
  }

  void _selectPlace(BiblicalPlace place) {
    FeedbackEngine.I.tap();
    setState(() => _selectedPlace = place);
    _animatedMove(place.position, null);
  }

  void _deselectPlace() {
    setState(() => _selectedPlace = null);
  }

  void _animatedMove(LatLng dest, double? zoom) {
    final cam = _mapController.camera;
    final latTween =
        Tween<double>(begin: cam.center.latitude, end: dest.latitude);
    final lngTween =
        Tween<double>(begin: cam.center.longitude, end: dest.longitude);
    final zoomTween =
        Tween<double>(begin: cam.zoom, end: zoom ?? cam.zoom);

    final ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    final curve =
        CurvedAnimation(parent: ctrl, curve: Curves.easeInOut);

    ctrl.addListener(() {
      _mapController.move(
        LatLng(latTween.evaluate(curve), lngTween.evaluate(curve)),
        zoomTween.evaluate(curve),
      );
    });
    ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) ctrl.dispose();
    });
    ctrl.forward();
  }

  // ─── Reference → Verse navigation ───

  void _navigateToVerse(String osisRef) {
    // osisRef format: "MAT.4.13" or "GEN.12.1"
    final parts = osisRef.split('.');
    if (parts.length < 2) return;

    final bookCode = parts[0];
    final chapter = int.tryParse(parts[1]) ?? 1;
    final bookNum = kBookCodeToNumber[bookCode];
    if (bookNum == null) return;

    final bookName = kBookNumberToNameEs[bookNum] ?? '';
    final version =
        BibleUserDataService.I.preferredVersionNotifier.value;

    FeedbackEngine.I.confirm();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BibleReaderScreen(
          bookNumber: bookNum,
          bookName: bookName,
          chapter: chapter,
          version: version,
        ),
      ),
    );
  }

  // ─── BUILD ───

  @override
  Widget build(BuildContext context) {
    final t = BibleReaderThemeData.fromId(
      BibleReaderThemeData.migrateId(
          BibleUserDataService.I.readerThemeNotifier.value),
    );
    return Scaffold(
      body: _loading
          ? Container(
              color: t.background,
              child: Center(
                child:
                    CircularProgressIndicator(color: t.accent),
              ),
            )
          : Stack(
              children: [
                // 1. The map
                _buildFlutterMap(),
                // 2. Top bar with back + period selector
                _buildTopBar(),
                // 3. Layer control panel (right)
                if (_showLayerPanel) _buildLayerPanel(),
                // 4. Layer toggle button (right)
                _buildLayerToggle(),
                // 5. Bottom info panel
                if (_selectedPlace != null)
                  _buildBottomPanel(_selectedPlace!),
              ],
            ),
    );
  }

  // ─── 1. THE MAP ───

  Widget _buildFlutterMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _kHolyLandCenter,
        initialZoom: _kInitialZoom,
        minZoom: 4,
        maxZoom: 15,
        onTap: (tapPos, point) => _deselectPlace(),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
        backgroundColor: const Color(0xFFD2E3F3),
      ),
      children: [
        // Tile layer — ESRI World Topo Map
        TileLayer(
          urlTemplate: _kEsriTopoUrl,
          userAgentPackageName: 'com.example.victoria',
          maxZoom: 18,
          tileProvider: NetworkTileProvider(),
        ),

        // Region polygons
        if (_showRegions && _filteredRegions.isNotEmpty)
          PolygonLayer(
            polygons: _filteredRegions.map(_buildRegionPolygon).toList(),
          ),

        // Route polylines
        if (_showRoutes && _filteredRoutes.isNotEmpty)
          PolylineLayer(
            polylines: _filteredRoutes.map(_buildRoutePolyline).toList(),
          ),

        // Place markers + labels
        if (_showPlaces && _filteredPlaces.isNotEmpty)
          MarkerLayer(
            markers: _buildPlaceMarkers(),
          ),
      ],
    );
  }

  // ─── Regions ───

  Polygon _buildRegionPolygon(HistoricalRegion region) {
    final color = _parseColor(region.color);
    return Polygon(
      points: region.points,
      color: color.withValues(alpha: region.opacity * 0.6),
      borderColor: _parseColor(region.borderColor),
      borderStrokeWidth: 1.5,
      isFilled: true,
      label: region.nameEs,
      labelStyle: TextStyle(
        fontFamily: 'Georgia',
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: color.withValues(alpha: 0.8),
      ),
    );
  }

  // ─── Routes ───

  Polyline _buildRoutePolyline(HistoricalRoute route) {
    final color = _parseColor(route.color);
    return Polyline(
      points: route.points,
      color: color,
      strokeWidth: route.width,
      pattern: route.dotted
          ? const StrokePattern.dotted(spacingFactor: 1.5)
          : const StrokePattern.solid(),
      borderColor: color.withValues(alpha: 0.3),
      borderStrokeWidth: 1,
    );
  }

  // ─── Place markers ───

  List<Marker> _buildPlaceMarkers() {
    final markers = <Marker>[];

    for (final place in _filteredPlaces) {
      final isSelected = _selectedPlace?.id == place.id;
      final size = isSelected ? 36.0 : _markerSize(place.importance);

      // Marker icon
      markers.add(Marker(
        point: place.position,
        width: size + 4,
        height: size + 4,
        child: GestureDetector(
          onTap: () => _selectPlace(place),
          child: _PlaceMarkerWidget(
            place: place,
            isSelected: isSelected,
            size: size,
          ),
        ),
      ));

      // Label below marker
      if (_showLabels && place.importance >= 3) {
        markers.add(Marker(
          point: place.position,
          width: 120,
          height: 24,
          alignment: const Alignment(0, 2.8),
          child: _PlaceLabelWidget(name: place.nameEs),
        ));
      }
    }

    return markers;
  }

  double _markerSize(int importance) {
    if (importance >= 5) return 32;
    if (importance >= 4) return 30;
    if (importance >= 3) return 28;
    return 24;
  }

  // ─── 2. TOP BAR ───

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.5),
              Colors.black.withValues(alpha: 0.0),
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Back + title
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.map_outlined,
                        color: _kGold, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'MAPAS BÍBLICOS',
                        style: GoogleFonts.cinzel(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          shadows: [
                            const Shadow(
                                blurRadius: 4, color: Colors.black54),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Period selector chips
              SizedBox(
                height: 42,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: kBiblicalPeriods.length,
                  itemBuilder: (context, i) {
                    final period = kBiblicalPeriods[i];
                    final isActive =
                        _selectedPeriod == period.id;
                    return Padding(
                      padding:
                          const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(period.nameEs),
                        selected: isActive,
                        onSelected: (_) =>
                            _selectPeriod(period.id),
                        backgroundColor: Colors.black54,
                        selectedColor: _kGold,
                        labelStyle: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isActive
                              ? Colors.black
                              : Colors.white,
                        ),
                        side: BorderSide(
                          color: isActive
                              ? _kGold
                              : Colors.white30,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6),
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ─── 3. LAYER PANEL ───

  Widget _buildLayerPanel() {
    return Positioned(
      right: 12,
      top: MediaQuery.of(context).padding.top + 100,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        color: _kPanelBg,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Capas',
                  style: GoogleFonts.cinzel(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _kDarkText)),
              const SizedBox(height: 6),
              _layerSwitch(
                  Icons.terrain, 'Regiones', _showRegions,
                  (v) => setState(() => _showRegions = v)),
              _layerSwitch(
                  Icons.route, 'Rutas', _showRoutes,
                  (v) => setState(() => _showRoutes = v)),
              _layerSwitch(
                  Icons.place, 'Lugares', _showPlaces,
                  (v) => setState(() => _showPlaces = v)),
              _layerSwitch(
                  Icons.label_outline, 'Nombres', _showLabels,
                  (v) => setState(() => _showLabels = v)),
              const Divider(height: 12),
              // Zoom controls
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _zoomButton(Icons.add, () {
                    final cam = _mapController.camera;
                    _animatedMove(cam.center, cam.zoom + 1);
                  }),
                  const SizedBox(width: 8),
                  _zoomButton(Icons.remove, () {
                    final cam = _mapController.camera;
                    _animatedMove(cam.center, cam.zoom - 1);
                  }),
                  const SizedBox(width: 8),
                  _zoomButton(Icons.my_location, () {
                    _animatedMove(_kHolyLandCenter, _kInitialZoom);
                  }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _layerSwitch(
      IconData icon, String label, bool value, ValueChanged<bool> onChanged) {
    return SizedBox(
      height: 32,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: _kDarkGold),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.manrope(
                  fontSize: 12, color: _kDarkText)),
          const SizedBox(width: 6),
          SizedBox(
            width: 36,
            height: 20,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeColor: _kGold,
              materialTapTargetSize:
                  MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _zoomButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: _kGold.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _kDarkGold.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, size: 18, color: _kDarkGold),
      ),
    );
  }

  // ─── 4. LAYER TOGGLE BUTTON ───

  Widget _buildLayerToggle() {
    return Positioned(
      right: 12,
      top: MediaQuery.of(context).padding.top + 60,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(10),
        color: _showLayerPanel
            ? _kGold
            : _kPanelBg,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            FeedbackEngine.I.tap();
            setState(() => _showLayerPanel = !_showLayerPanel);
          },
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              Icons.layers,
              size: 22,
              color: _showLayerPanel ? Colors.black : _kDarkGold,
            ),
          ),
        ),
      ),
    );
  }

  // ─── 5. BOTTOM INFO PANEL ───

  Widget _buildBottomPanel(BiblicalPlace place) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        decoration: BoxDecoration(
          color: _kPanelBg,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding:
                const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Place name + close
                Row(
                  children: [
                    _buildPlaceIcon(place.type, 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            place.nameEs,
                            style: GoogleFonts.cinzel(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: _kDarkGold,
                            ),
                          ),
                          Text(
                            '${_placeTypeLabel(place.type)}${place.periods.isNotEmpty ? ' · ${_periodLabel(place.periods.first)}' : ''}',
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close,
                          color: Colors.grey.shade400),
                      onPressed: _deselectPlace,
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Description
                Text(
                  place.description,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    height: 1.6,
                    color: _kDarkText.withValues(alpha: 0.8),
                  ),
                ),

                // References
                if (place.references.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Referencias',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade500,
                        letterSpacing: 0.5,
                      )),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: place.references.map((ref) {
                      final display =
                          ref.replaceAll('.', ' ');
                      return Material(
                        color: _kGold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          borderRadius:
                              BorderRadius.circular(8),
                          onTap: () =>
                              _navigateToVerse(ref),
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5),
                            child: Text(
                              display,
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _kDarkGold,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Helpers ───

  Widget _buildPlaceIcon(BiblicalPlaceType type, double size) {
    IconData icon;
    Color bg;
    switch (type) {
      case BiblicalPlaceType.city:
        icon = Icons.location_city;
        bg = _kBeige;
        break;
      case BiblicalPlaceType.mountain:
        icon = Icons.terrain;
        bg = _kBeige;
        break;
      case BiblicalPlaceType.sea:
      case BiblicalPlaceType.river:
        icon = Icons.water;
        bg = _kWaterBlue;
        break;
      case BiblicalPlaceType.temple:
        icon = Icons.church;
        bg = _kBeige;
        break;
      case BiblicalPlaceType.battlefield:
        icon = Icons.shield;
        bg = const Color(0xFFFFCCCC);
        break;
      case BiblicalPlaceType.region:
        icon = Icons.landscape;
        bg = _kBeige;
        break;
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: _kDarkGold, width: 1.5),
      ),
      child: Icon(icon, size: size * 0.55, color: _kDarkGold),
    );
  }

  String _placeTypeLabel(BiblicalPlaceType type) {
    switch (type) {
      case BiblicalPlaceType.city:
        return 'Ciudad';
      case BiblicalPlaceType.mountain:
        return 'Monte';
      case BiblicalPlaceType.sea:
        return 'Mar';
      case BiblicalPlaceType.river:
        return 'Río';
      case BiblicalPlaceType.temple:
        return 'Templo';
      case BiblicalPlaceType.battlefield:
        return 'Batalla';
      case BiblicalPlaceType.region:
        return 'Región';
    }
  }

  String _periodLabel(String period) {
    for (final p in kBiblicalPeriods) {
      if (p.id == period) return p.nameEs;
    }
    return period;
  }

  Color _parseColor(String hex) {
    final h = hex.replaceFirst('#', '');
    if (h.length == 6) return Color(int.parse('FF$h', radix: 16));
    return _kGold;
  }
}

// ─── MARKER WIDGET ───────────────────────────────────────────

class _PlaceMarkerWidget extends StatelessWidget {
  final BiblicalPlace place;
  final bool isSelected;
  final double size;

  const _PlaceMarkerWidget({
    required this.place,
    required this.isSelected,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color bg;
    switch (place.type) {
      case BiblicalPlaceType.city:
        icon = Icons.location_city;
        bg = _kBeige;
        break;
      case BiblicalPlaceType.mountain:
        icon = Icons.terrain;
        bg = _kBeige;
        break;
      case BiblicalPlaceType.sea:
      case BiblicalPlaceType.river:
        icon = Icons.water;
        bg = _kWaterBlue;
        break;
      case BiblicalPlaceType.temple:
        icon = Icons.church;
        bg = _kBeige;
        break;
      case BiblicalPlaceType.battlefield:
        icon = Icons.shield;
        bg = const Color(0xFFFFCCCC);
        break;
      case BiblicalPlaceType.region:
        icon = Icons.landscape;
        bg = _kBeige;
        break;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? _kGold : _kDarkGold,
          width: isSelected ? 2.5 : 1.5,
        ),
        boxShadow: [
          if (isSelected)
            BoxShadow(
              color: _kGold.withValues(alpha: 0.5),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(icon, size: size * 0.52, color: _kDarkGold),
    );
  }
}

// ─── LABEL WIDGET ────────────────────────────────────────────

class _PlaceLabelWidget extends StatelessWidget {
  final String name;

  const _PlaceLabelWidget({required this.name});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Text(
        name,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'Georgia',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _kDarkText,
          shadows: const [
            Shadow(offset: Offset(1, 1), blurRadius: 2, color: Colors.white),
            Shadow(offset: Offset(-1, -1), blurRadius: 2, color: Colors.white),
            Shadow(offset: Offset(1, -1), blurRadius: 2, color: Colors.white),
            Shadow(offset: Offset(-1, 1), blurRadius: 2, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
