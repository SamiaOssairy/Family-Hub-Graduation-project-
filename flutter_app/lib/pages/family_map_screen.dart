import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/services/api_service.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/app_bottom_nav.dart';
import '../core/widgets/guarded_button.dart';

class FamilyMapScreen extends StatefulWidget {
  const FamilyMapScreen({super.key});

  @override
  State<FamilyMapScreen> createState() => _FamilyMapScreenState();
}

class _FamilyMapScreenState extends State<FamilyMapScreen> {
  final ApiService _api = ApiService();
  final MapController _mapController = MapController();

  List<Map<String, dynamic>> _familyLocations = [];
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _selectedMember;
  Timer? _refreshTimer;
  bool _isSharingEnabled = true;
  bool _isSyncingMyLocation = false;
  LatLng? _myPosition;
  String _myUsername = 'You';
  String? _myMail;
  int _unreadLocationAlerts = 0;
  DateTime? _lastLocationSyncAt;
  LatLng? _lastSyncedPosition;

  static const Duration _locationSyncInterval = Duration(seconds: 45);
  static const double _minSyncDistanceMeters = 20;

  // Map palette for member markers
  static const List<Color> _markerColors = [
    Color(0xFF1E88E5), // blue
    Color(0xFFE53935), // red
    Color(0xFF43A047), // green
    Color(0xFFFB8C00), // orange
    Color(0xFF8E24AA), // purple
    Color(0xFF00ACC1), // cyan
    Color(0xFFD81B60), // pink
    Color(0xFF6D4C41), // brown
  ];

  @override
  void initState() {
    super.initState();
    _loadCachedProfile();
    _loadData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) => _loadData(silent: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCachedProfile() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _myUsername = prefs.getString('username') ?? 'You';
    });
  }

  Future<void> _loadData({bool silent = false}) async {
    try {
      if (!silent && mounted) {
        setState(() {
          _isLoading = true;
          _error = null;
        });
      }

      final myLocResponse = await _api.getMyLocation().catchError((_) => <String, dynamic>{});
      if (myLocResponse.containsKey('data')) {
        final locData = myLocResponse['data']?['location'];
        if (locData != null) {
          _isSharingEnabled = locData['is_sharing_enabled'] ?? true;
          _myMail = locData['member_mail']?.toString();
        }
      }

      await _updateMyLiveLocation();

      final results = await Future.wait([
        _api.getFamilyLocations(),
        _api.getUnreadLocationAlertCount().catchError((_) => 0),
      ]);

      final locations = (results[0] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      final unreadCount = results[1] as int;

      final filteredFamily = locations.where((location) {
        final locationMail = location['member_mail']?.toString();
        return _myMail == null || locationMail != _myMail;
      }).toList();

      if (mounted) {
        setState(() {
          _familyLocations = filteredFamily;
          _unreadLocationAlerts = unreadCount;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _openLocationAlertsSheet() async {
    final alerts = await _api.getMyAlerts();
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.72,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_active_outlined, color: AppColors.primary),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Location Notifications',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        await _api.markAllAlertsRead();
                        if (mounted) {
                          setState(() => _unreadLocationAlerts = 0);
                        }
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                        }
                      },
                      child: const Text('Mark all read'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: alerts.isEmpty
                    ? const Center(
                        child: Text(
                          'No location notifications yet',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.separated(
                        itemCount: alerts.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final alert = Map<String, dynamic>.from(alerts[i]);
                          final isRead = alert['is_read'] == true;
                          final alertId = (alert['_id'] ?? '').toString();
                          final message = (alert['message'] ?? 'Location alert').toString();
                          final createdAt = _timeAgo(alert['created_at']?.toString());

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isRead ? Colors.grey.shade300 : const Color(0xFFFFE8E8),
                              child: Icon(
                                Icons.location_off_outlined,
                                color: isRead ? Colors.grey.shade700 : Colors.red,
                              ),
                            ),
                            title: Text(
                              message,
                              style: TextStyle(
                                fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(createdAt),
                            trailing: isRead
                                ? const Icon(Icons.done, size: 18, color: Colors.grey)
                                : TextButton(
                                    onPressed: () async {
                                      if (alertId.isEmpty) return;
                                      await _api.markAlertRead(alertId);
                                      if (mounted) {
                                        setState(() {
                                          _unreadLocationAlerts = (_unreadLocationAlerts - 1).clamp(0, 1 << 20);
                                        });
                                      }
                                      if (ctx.mounted) {
                                        Navigator.pop(ctx);
                                      }
                                    },
                                    child: const Text('Read'),
                                  ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _colorForIndex(int i) => _markerColors[i % _markerColors.length];

  bool _hasCoordinates(Map<String, dynamic> loc) {
    final lat = loc['latitude'];
    final lng = loc['longitude'];
    return lat is num && lng is num;
  }

  bool _isMemberOnline(Map<String, dynamic> loc, {bool isYou = false}) {
    if (isYou) return true;
    if (loc['is_sharing_enabled'] != true) return false;
    final dateStr = loc['last_updated']?.toString();
    final dt = dateStr != null ? DateTime.tryParse(dateStr) : null;
    if (dt == null) return false;
    return DateTime.now().difference(dt) <= const Duration(minutes: 2);
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return DateFormat('MMM d, h:mm a').format(dt.toLocal());
  }

  String _memberPresence(Map<String, dynamic> loc) {
    final lastUpdated = loc['last_updated']?.toString();
    if (lastUpdated == null) return 'No location update yet';
    final dt = DateTime.tryParse(lastUpdated);
    if (dt == null) return 'No location update yet';
    final timeText = _relativeTime(dt);
    return _isMemberOnline(loc) ? 'Online $timeText' : 'Last update $timeText';
  }

  Future<void> _openDirectionsToMember(Map<String, dynamic> loc) async {
    if (!_hasCoordinates(loc)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This member has no saved location yet.')),
      );
      return;
    }

    final destinationLat = (loc['latitude'] as num).toDouble();
    final destinationLng = (loc['longitude'] as num).toDouble();

    final params = <String, String>{
      'api': '1',
      'destination': '$destinationLat,$destinationLng',
      'travelmode': 'driving',
    };

    if (_myPosition != null) {
      params['origin'] = '${_myPosition!.latitude},${_myPosition!.longitude}';
    }

    final uri = Uri.https('www.google.com', '/maps/dir/', params);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open Google Maps on this device.')),
    );
  }

  Future<void> _updateMyLiveLocation() async {
    if (_isSyncingMyLocation) return;
    _isSyncingMyLocation = true;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );

      final newPosition = LatLng(position.latitude, position.longitude);
      _myPosition = newPosition;

      final now = DateTime.now();
      final intervalPassed = _lastLocationSyncAt == null ||
          now.difference(_lastLocationSyncAt!) >= _locationSyncInterval;
      final movedEnough = _lastSyncedPosition == null ||
          Geolocator.distanceBetween(
                _lastSyncedPosition!.latitude,
                _lastSyncedPosition!.longitude,
                newPosition.latitude,
                newPosition.longitude,
              ) >=
              _minSyncDistanceMeters;

      if (_isSharingEnabled && (intervalPassed || movedEnough)) {
        await _api.updateMyLocation(newPosition.latitude, newPosition.longitude);
        _lastLocationSyncAt = now;
        _lastSyncedPosition = newPosition;
      }
    } finally {
      _isSyncingMyLocation = false;
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.substring(0, name.length.clamp(0, 2)).toUpperCase();
  }

  String _timeAgo(String? dateStr) {
    if (dateStr == null) return 'Last online unknown';
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return 'Last online unknown';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Online from just now';
    if (diff.inMinutes < 60) return 'Online from ${diff.inMinutes} min ago';
    if (diff.inHours < 24) return 'Online from ${diff.inHours} hr ago';
    return 'Last online ${DateFormat('MMM d, h:mm a').format(dt.toLocal())}';
  }

  Future<void> _toggleSharing() async {
    final newVal = !_isSharingEnabled;
    try {
      await _api.toggleLocationSharing(newVal);
      setState(() => _isSharingEnabled = newVal);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(newVal ? 'Location sharing enabled' : 'Location sharing disabled')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString().replaceFirst("Exception: ", "")}')),
        );
      }
    }
  }

  Future<void> _sendSOS() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Send SOS Alert'),
          ],
        ),
        content: const Text(
          'This will send an emergency alert to all family members with your current location. Continue?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send SOS'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _api.createLocationAlert({
        'alert_type': 'sos',
        'message': 'Emergency SOS! I need help!',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SOS alert sent to all family members!'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send SOS: ${e.toString().replaceFirst("Exception: ", "")}')),
        );
      }
    }
  }

  LatLng _mapCenter() {
    if (_myPosition != null) return _myPosition!;
    final validLocations = _familyLocations.where(_hasCoordinates).toList();
    if (validLocations.isEmpty) return const LatLng(30.0444, 31.2357);
    double lat = 0, lng = 0;
    for (final loc in validLocations) {
      lat += (loc['latitude'] as num).toDouble();
      lng += (loc['longitude'] as num).toDouble();
    }
    return LatLng(lat / validLocations.length, lng / validLocations.length);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? _buildError()
              : _buildMap(),
      bottomNavigationBar: const AppBottomNav(selectedIndex: 3),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _loadData();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap() {
    final center = _mapCenter();
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: _familyLocations.isEmpty ? 15.5 : 13.2,
            onTap: (_, __) => setState(() => _selectedMember = null),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              retinaMode: MediaQuery.of(context).devicePixelRatio > 1.0,
              userAgentPackageName: 'com.familyhub.app',
            ),
            if (_myPosition != null)
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: _myPosition!,
                    radius: 48,
                    useRadiusInMeter: false,
                    color: const Color(0x4D00C2FF),
                    borderStrokeWidth: 0,
                  ),
                  CircleMarker(
                    point: _myPosition!,
                    radius: 74,
                    useRadiusInMeter: false,
                    color: const Color(0x1F00E5FF),
                    borderStrokeWidth: 0,
                  ),
                ],
              ),
            MarkerLayer(markers: _buildMarkers()),
          ],
        ),

        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0x269C27B0),
                    Colors.transparent,
                    const Color(0x3339D39F),
                  ],
                ),
              ),
            ),
          ),
        ),

        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF5FCFF), Color(0xFFEAFBF3)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: const Color(0xFFB8EED9), width: 1),
              boxShadow: [
                BoxShadow(
                  color: const Color(0x331AA7EC),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1AA7EC), Color(0xFF4FC3A1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.location_searching, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Family Map',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        _myPosition == null ? 'Waiting for your location' : 'You + ${_familyLocations.length} family members',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: _openLocationAlertsSheet,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE0F7FF), Color(0xFFD7FCE8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Center(
                          child: Icon(Icons.notifications_none_rounded, color: AppColors.textPrimary, size: 22),
                        ),
                        if (_unreadLocationAlerts > 0)
                          Positioned(
                            right: -3,
                            top: -3,
                            child: Container(
                              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                _unreadLocationAlerts > 99 ? '99+' : '$_unreadLocationAlerts',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE9F7FF), Color(0xFFE8FFF4)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    '${_familyLocations.length + (_myPosition != null ? 1 : 0)} live',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        if (_myPosition != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 86,
            left: 16,
            child: _buildYouBadge(),
          ),

        if (_familyLocations.isNotEmpty)
          Positioned(
            bottom: 14,
            left: 12,
            right: 12,
            child: Container(
              height: 114,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF9FDFF), Color(0xFFF2FFF9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFFD2F0E3), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0x331AA7EC),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                itemCount: _familyLocations.length,
                itemBuilder: (ctx, i) => _buildMemberChip(i),
              ),
            ),
          ),

        if (_selectedMember != null)
          Positioned(
            bottom: _familyLocations.isNotEmpty ? 138 : 20,
            left: 20,
            right: 20,
            child: _buildDetailCard(_selectedMember!),
          ),

        Positioned(
          right: 16,
          bottom: _familyLocations.isNotEmpty ? 138 : 22,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton.small(
                heroTag: 'sharing',
                backgroundColor: _isSharingEnabled ? AppColors.primary : Colors.grey,
                onPressed: _toggleSharing,
                child: Icon(
                  _isSharingEnabled ? Icons.location_on : Icons.location_off,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              FloatingActionButton.small(
                heroTag: 'recenter',
                backgroundColor: Colors.white,
                onPressed: () => _mapController.move(center, _mapController.camera.zoom),
                child: const Icon(Icons.my_location, color: AppColors.primary),
              ),
              const SizedBox(height: 8),
              GuardedFab(
                heroTag: 'sos',
                backgroundColor: Colors.red,
                onPressed: _sendSOS,
                child: const Text(
                  'SOS',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildYouBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildAvatarBubble(
            label: _initials(_myUsername),
            colors: const [Color(0xFF1AA7EC), Color(0xFF4FC3A1)],
            size: 34,
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'You',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              Text(
                _isSharingEnabled ? 'Live now' : 'Visible only to you',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    if (_myPosition != null) {
      markers.add(
        Marker(
          point: _myPosition!,
          width: 90,
          height: 104,
          child: GestureDetector(
            onTap: () => setState(() {
              _selectedMember = {
                'member_username': _myUsername,
                'member_type': 'You',
                'member_mail': _myMail ?? '',
                'last_updated': DateTime.now().toIso8601String(),
              };
            }),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    'You',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                _buildAvatarBubble(
                  label: _initials(_myUsername),
                  colors: const [Color(0xFF1AA7EC), Color(0xFF4FC3A1)],
                  size: 54,
                  borderColor: Colors.white,
                ),
                CustomPaint(
                  size: const Size(14, 10),
                  painter: _TrianglePainter(const Color(0xFF1AA7EC)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final locationsWithCoordinates = _familyLocations.where(_hasCoordinates).toList();

    markers.addAll(List.generate(locationsWithCoordinates.length, (i) {
      final loc = locationsWithCoordinates[i];
      final lat = (loc['latitude'] as num).toDouble();
      final lng = (loc['longitude'] as num).toDouble();
      final color = _colorForIndex(i);
      final name = loc['member_username'] ?? 'Unknown';
      final isOnline = _isMemberOnline(loc);

      return Marker(
        point: LatLng(lat, lng),
        width: 82,
        height: 96,
        child: GestureDetector(
          onTap: () => setState(() => _selectedMember = loc),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: isOnline ? const Color(0xFF00897B) : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      name.split(' ').first,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              _buildAvatarBubble(
                label: _initials(name),
                colors: isOnline
                    ? [color, color.withValues(alpha: 0.72)]
                    : [Colors.blueGrey, Colors.blueGrey.withValues(alpha: 0.72)],
                size: 48,
                borderColor: Colors.white,
              ),
              CustomPaint(
                size: const Size(12, 8),
                painter: _TrianglePainter(isOnline ? color : Colors.blueGrey),
              ),
            ],
          ),
        ),
      );
    }));

    return markers;
  }

  Widget _buildMemberChip(int i) {
    final loc = _familyLocations[i];
    final name = loc['member_username'] ?? 'Unknown';
    final color = _colorForIndex(i);
    final isOnline = _isMemberOnline(loc);
    final isSelected = _selectedMember != null &&
        _selectedMember!['member_mail'] == loc['member_mail'];

    return GestureDetector(
      onTap: () {
        if (_hasCoordinates(loc)) {
          final lat = (loc['latitude'] as num).toDouble();
          final lng = (loc['longitude'] as num).toDouble();
          _mapController.move(LatLng(lat, lng), 15);
        }
        setState(() => _selectedMember = loc);
      },
      child: Container(
        width: 78,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              duration: const Duration(milliseconds: 180),
              scale: isSelected ? 1.08 : 1,
              child: _buildAvatarBubble(
                label: _initials(name),
                colors: isOnline
                    ? [color, color.withValues(alpha: 0.72)]
                    : [Colors.blueGrey, Colors.blueGrey.withValues(alpha: 0.72)],
                size: 52,
                borderColor: isSelected ? Colors.white : Colors.transparent,
                shadowColor: isSelected ? color.withValues(alpha: 0.42) : null,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: isOnline ? const Color(0xFF00897B) : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    name.split(' ').first,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              _memberPresence(loc),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9,
                color: AppColors.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard(Map<String, dynamic> loc) {
    final name = loc['member_username'] ?? 'Unknown';
    final type = loc['member_type'] ?? 'Member';
    final mail = loc['member_mail'] ?? '';
    final i = _familyLocations.indexWhere((l) => l['member_mail'] == loc['member_mail']);
    final isYou = type == 'You';
    final isOnline = _isMemberOnline(loc, isYou: isYou);
    final color = isYou ? const Color(0xFF1AA7EC) : _colorForIndex(i >= 0 ? i : 0);

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _buildAvatarBubble(
              label: _initials(name),
              colors: [color, color.withValues(alpha: 0.72)],
              size: 52,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isOnline ? const Color(0xFF00897B) : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isOnline ? 'Online' : 'Offline',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        isYou
                            ? Icons.my_location_rounded
                            : type == 'Parent'
                                ? Icons.shield_outlined
                                : Icons.person_outline,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        type,
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    mail,
                    style: TextStyle(color: AppColors.textHint, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 13, color: AppColors.textHint),
                      const SizedBox(width: 4),
                      Text(
                        _memberPresence(loc),
                        style: TextStyle(color: AppColors.textHint, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _hasCoordinates(loc) ? () => _openDirectionsToMember(loc) : null,
                      icon: const Icon(Icons.directions, size: 18),
                      label: const Text('Directions'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0B8FCE),
                        side: const BorderSide(color: Color(0xFFBDE8FF)),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => setState(() => _selectedMember = null),
              icon: const Icon(Icons.close, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarBubble({
    required String label,
    required List<Color> colors,
    required double size,
    Color borderColor = Colors.white,
    Color? shadowColor,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 3),
        boxShadow: [
          BoxShadow(
            color: (shadowColor ?? colors.first).withValues(alpha: 0.28),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.30,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// Paints a small downward-pointing triangle under the marker circle.
class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
