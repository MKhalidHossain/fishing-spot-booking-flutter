import 'package:app_pigeon/app_pigeon.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:xocobaby13/core/constants/api_endpoints.dart';
import 'package:xocobaby13/feature/profile/controller/profile_controller.dart';
import 'package:xocobaby13/feature/notification/presentation/routes/notification_routes.dart';
import 'package:xocobaby13/feature/spot_owner/presentation/routes/spot_owner_routes.dart';
import 'package:xocobaby13/core/common/widget/button/loading_buttons.dart';

class SpotOwnerHomeScreen extends StatefulWidget {
  const SpotOwnerHomeScreen({super.key});

  @override
  State<SpotOwnerHomeScreen> createState() => _SpotOwnerHomeScreenState();
}

class _SpotOwnerHomeScreenState extends State<SpotOwnerHomeScreen> {
  late final ProfileController _profileController;
  bool _isLoadingUnread = false;
  int _unreadCount = 0;
  bool _isLoadingEvents = false;
  String? _eventsError;
  List<_SpotOwnerEvent> _runningEvents = const <_SpotOwnerEvent>[];
  bool _isLoadingEarnings = false;
  String _totalEarnings = r'$128.7k';
  String _earningsChange = '+ 36%';

  @override
  void initState() {
    super.initState();
    _profileController = ProfileController.instance();
    _loadUnreadCount();
    _loadRunningEvents();
    _loadEarnings();
  }

  Future<void> _loadUnreadCount() async {
    if (_isLoadingUnread) return;
    setState(() => _isLoadingUnread = true);
    try {
      final response = await Get.find<AuthorizedPigeon>().get(
        ApiEndpoints.getUnreadNotificationCount,
      );
      final responseBody = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};
      final data = responseBody['data'];
      int count = 0;
      if (data is Map) {
        count = _readInt(data['unreadCount']);
      }
      if (!mounted) return;
      setState(() {
        _unreadCount = count;
        _isLoadingUnread = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingUnread = false);
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1200),
      ),
    );
  }

  int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _readString(dynamic value, {String fallback = ''}) {
    final String text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String _displayName() {
    final String name = _readString(_profileController.profile.value.name);
    if (name.isEmpty) return 'Spot Owner';
    return name;
  }

  String _formatLocation(dynamic locationRaw) {
    if (locationRaw is Map) {
      final Map<String, dynamic> location = Map<String, dynamic>.from(
        locationRaw,
      );
      final String address = _readString(location['address']);
      final String city = _readString(location['city']);
      final String country = _readString(location['country']);
      final List<String> parts = <String>[
        address,
        city,
        country,
      ].where((String value) => value.isNotEmpty).toList();
      if (parts.isNotEmpty) {
        return parts.join(', ');
      }
    }
    return 'Unknown location';
  }

  String _pickImageUrl(dynamic imagesRaw) {
    if (imagesRaw is List && imagesRaw.isNotEmpty) {
      final dynamic first = imagesRaw.first;
      if (first is Map && first['url'] != null) {
        return first['url'].toString();
      }
      if (first is String) {
        return first;
      }
    }
    return 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=900&q=80';
  }

  Map<String, int> _slotStats(dynamic availabilityRaw) {
    int total = 0;
    int booked = 0;
    if (availabilityRaw is List) {
      for (final dynamic entry in availabilityRaw) {
        if (entry is Map) {
          final dynamic slotsRaw = entry['slots'];
          if (slotsRaw is List) {
            for (final dynamic slot in slotsRaw) {
              total += 1;
              if (slot is Map && slot['isBooked'] == true) {
                booked += 1;
              }
            }
          }
        }
      }
    }
    return <String, int>{'total': total, 'booked': booked};
  }

  _SpotOwnerEvent _mapSpotToEvent(Map<String, dynamic> spot) {
    final Map<String, int> stats = _slotStats(spot['availability']);
    return _SpotOwnerEvent(
      title: _readString(spot['title'], fallback: 'Spot'),
      location: _formatLocation(spot['location']),
      type: _readString(spot['type'], fallback: 'Spot'),
      slotsFilled: stats['booked'] ?? 0,
      slotsTotal: stats['total'] ?? 0,
      imageUrl: _pickImageUrl(spot['images']),
    );
  }

  Future<void> _loadRunningEvents() async {
    if (_isLoadingEvents) return;
    setState(() {
      _isLoadingEvents = true;
      _eventsError = null;
    });
    try {
      final response = await Get.find<AuthorizedPigeon>().get(
        ApiEndpoints.ownerSpots,
      );
      final responseBody = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};
      final data = responseBody['data'];
      final List<_SpotOwnerEvent> events = <_SpotOwnerEvent>[];
      if (data is List) {
        for (final dynamic item in data) {
          if (item is Map) {
            final Map<String, dynamic> spot = Map<String, dynamic>.from(item);
            final String status = _readString(spot['status']).toLowerCase();
            if (status == 'running') {
              events.add(_mapSpotToEvent(spot));
            }
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _runningEvents = events;
        _isLoadingEvents = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _eventsError = 'Failed to load events';
        _isLoadingEvents = false;
      });
    }
  }

  Future<void> _loadEarnings() async {
    if (_isLoadingEarnings) return;
    setState(() => _isLoadingEarnings = true);
    try {
      final response = await Get.find<AuthorizedPigeon>().get(
        ApiEndpoints.ownerEarnings,
      );
      final statusCode = response.statusCode ?? 0;
      if (statusCode < 200 || statusCode >= 300) {
        if (!mounted) return;
        setState(() => _isLoadingEarnings = false);
        return;
      }

      final responseBody = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};
      final payload = responseBody['data'];
      final data = payload is Map
          ? Map<String, dynamic>.from(payload)
          : responseBody;

      final String totalEarnings = _readString(data['totalEarnings']);
      final String percentageChange = _readString(data['percentageChange']);

      if (!mounted) return;
      setState(() {
        if (totalEarnings.isNotEmpty) {
          _totalEarnings = totalEarnings;
        }
        if (percentageChange.isNotEmpty) {
          _earningsChange = percentageChange;
        }
        _isLoadingEarnings = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingEarnings = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Obx(
              () => Row(
                children: <Widget>[
                  _SpotOwnerAvatar(
                    imageProvider:
                        _profileController.profile.value.avatarImageProvider,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Good Morning',
                        style:
                            TextStyle(fontSize: 14, color: Color(0xFF3A4A5A)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Hello, ${_displayName()}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1D2A36),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () async {
                      await context.push(NotificationRouteNames.notifications);
                      if (mounted) {
                        _loadUnreadCount();
                      }
                    },
                    child: _SpotOwnerNotificationBell(unreadCount: _unreadCount),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            _SpotOwnerSummaryCard(
              title: 'Total Earnings',
              value: _totalEarnings,
              changeText: '$_earningsChange ',
            ),
            const SizedBox(height: 22),
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1D2A36),
              ),
            ),
            const SizedBox(height: 14),
            _SpotOwnerActionCard(
              title: 'Create Event',
              subtitle: 'Schedule a new tournament',
              onTap: () => context.push(SpotOwnerRouteNames.createSpot),
            ),
            const SizedBox(height: 22),
            const Text(
              'Running Events',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1D2A36),
              ),
            ),
            const SizedBox(height: 14),
            if (_isLoadingEvents)
              const Center(child: CircularProgressIndicator())
            else if (_eventsError != null)
              Text(
                _eventsError ?? 'Failed to load events',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6A7B8C),
                ),
              )
            else if (_runningEvents.isEmpty)
              const Text(
                'No running events yet',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6A7B8C),
                ),
              )
            else
              Column(
                children: _runningEvents
                    .map(
                      (_SpotOwnerEvent event) => _SpotOwnerEventCard(
                        data: event,
                        onAnalytics: () =>
                            context.push(SpotOwnerRouteNames.analytics),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _SpotOwnerAvatar extends StatelessWidget {
  final ImageProvider imageProvider;

  const _SpotOwnerAvatar({required this.imageProvider});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
        image: DecorationImage(
          image: imageProvider,
          fit: BoxFit.cover,
          onError: (_, __) {},
        ),
      ),
    );
  }
}

class _SpotOwnerNotificationBell extends StatelessWidget {
  final int unreadCount;

  const _SpotOwnerNotificationBell({this.unreadCount = 0});

  @override
  Widget build(BuildContext context) {
    final String badgeText = unreadCount > 99 ? '99+' : unreadCount.toString();
    return Container(
      width: 46,
      height: 46,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          const Center(
            child: Icon(
              CupertinoIcons.bell_fill,
              color: Color(0xFF1787CF),
              size: 22,
            ),
          ),
          if (unreadCount > 0)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                height: 16,
                constraints: const BoxConstraints(minWidth: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE23A3A),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    badgeText,
                    style: const TextStyle(
                      fontSize: 9,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SpotOwnerSummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String changeText;

  const _SpotOwnerSummaryCard({
    required this.title,
    required this.value,
    required this.changeText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1787CF), width: 1.4),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6A7B8C),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1D2A36),
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: <Widget>[
              Text(
                changeText,
                style: const TextStyle(
                  color: Color(0xFF2FB25D),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Icon(
                CupertinoIcons.arrow_up,
                color: Color(0xFF2FB25D),
                size: 18,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpotOwnerActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SpotOwnerActionCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF1787CF), width: 1.3),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x140F172A),
              blurRadius: 18,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: <Widget>[
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x150F172A),
                    blurRadius: 16,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  CupertinoIcons.plus,
                  color: Color(0xFF1787CF),
                  size: 26,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1D2A36),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6A7B8C),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpotOwnerEventCard extends StatelessWidget {
  final _SpotOwnerEvent data;
  final VoidCallback onAnalytics;

  const _SpotOwnerEventCard({required this.data, required this.onAnalytics});

  double get _progressValue {
    if (data.slotsTotal == 0) return 0;
    return data.slotsFilled / data.slotsTotal;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1787CF), width: 1.2),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              data.imageUrl,
              width: 150,
              height: 100,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 92,
                height: 92,
                color: const Color(0xFFE2E8F1),
                child: const Icon(Icons.photo, size: 32),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  data.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1D2A36),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${data.location} - ${data.type}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6A7B8C),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${data.slotsFilled}/${data.slotsTotal} Slots',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1D2A36),
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    value: _progressValue,
                    backgroundColor: const Color(0xFFE8EFF7),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF1787CF),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 32,
                  child: AppElevatedButton(
                    onPressed: onAnalytics,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1787CF),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Analytics',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SpotOwnerEvent {
  final String title;
  final String location;
  final String type;
  final int slotsFilled;
  final int slotsTotal;
  final String imageUrl;

  const _SpotOwnerEvent({
    required this.title,
    required this.location,
    required this.type,
    required this.slotsFilled,
    required this.slotsTotal,
    required this.imageUrl,
  });
}
