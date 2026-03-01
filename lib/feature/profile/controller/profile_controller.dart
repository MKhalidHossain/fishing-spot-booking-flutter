import 'package:app_pigeon/app_pigeon.dart';
import 'package:dio/dio.dart' as dio;
import 'package:get/get.dart';
import 'package:get/get.dart' hide FormData, MultipartFile;
import 'package:image_picker/image_picker.dart';
import 'package:xocobaby13/core/constants/api_endpoints.dart';
import 'package:xocobaby13/feature/profile/model/activity_item_model.dart';
import 'package:xocobaby13/feature/profile/model/activity_status_model.dart';
import 'package:xocobaby13/feature/profile/model/user_profile_data_model.dart';

class ProfileController extends GetxController {
  final Rx<ActivityStatusModel> selectedActivityStatus =
      ActivityStatusModel.ongoing.obs;

  final RxBool isLoadingActivities = false.obs;
  final RxnString activitiesError = RxnString();
  final AuthorizedPigeon _appPigeon = Get.find<AuthorizedPigeon>();
  bool _isFetchingProfile = false;
  XFile? _pendingAvatarFile;

  final Rx<UserProfileDataModel> profile = const UserProfileDataModel(
    name: 'Unknown User',
    email: 'you@gmail.com',
    phone: '(000) 000-0000',
    description: 'I am a new user.',
    avatarAssetPath: 'assets/images/Profile_avatar_placeholder_large.png',
    avatarUrl: '',
    avatarBytes: null,
  ).obs;

  final RxList<ActivityItemModel> _activityItems = <ActivityItemModel>[].obs;

  void setActivityStatus(ActivityStatusModel status) {
    selectedActivityStatus.value = status;
  }

  @override
  void onInit() {
    super.onInit();
    fetchProfile();
    loadActivities();
  }

  Future<void> fetchProfile() async {
    if (_isFetchingProfile) {
      return;
    }
    _isFetchingProfile = true;

    try {
      final response = await _appPigeon.get(ApiEndpoints.getCurrentProfile);
      final statusCode = response.statusCode ?? 0;
      if (statusCode < 200 || statusCode >= 300) {
        return;
      }

      final data = _extractProfileData(response.data);
      if (data.isNotEmpty) {
        _applyProfileData(data);
      }
    } catch (_) {
      // Keep existing profile data on error.
    } finally {
      _isFetchingProfile = false;
    }
  }

  List<ActivityItemModel> get filteredActivityItems {
    return _activityItems
        .where(
          (ActivityItemModel item) =>
              item.status == selectedActivityStatus.value,
        )
        .toList();
  }

  Future<void> loadActivities() async {
    if (isLoadingActivities.value) return;
    isLoadingActivities.value = true;
    activitiesError.value = null;
    try {
      final List<ActivityItemModel> items = <ActivityItemModel>[];
      final List<_StatusRequest> requests = <_StatusRequest>[
        _StatusRequest('Confirmed', ActivityStatusModel.ongoing),
        _StatusRequest('Pending', ActivityStatusModel.upcoming),
        _StatusRequest('Completed', ActivityStatusModel.completed),
        _StatusRequest('Cancelled', ActivityStatusModel.canceled),
      ];

      final results = await Future.wait(
        requests.map(
          (_StatusRequest request) =>
              _fetchBookingsForStatus(request.apiStatus, request.uiStatus),
        ),
      );

      for (final List<ActivityItemModel> batch in results) {
        items.addAll(batch);
      }

      _activityItems.assignAll(items);
    } catch (e) {
      activitiesError.value = 'Failed to load activities';
    } finally {
      isLoadingActivities.value = false;
    }
  }

  Future<List<ActivityItemModel>> _fetchBookingsForStatus(
    String status,
    ActivityStatusModel uiStatus,
  ) async {
    final response = await Get.find<AuthorizedPigeon>().get(
      ApiEndpoints.getMyBookings,
      queryParameters: <String, dynamic>{'status': status},
    );
    final responseBody = response.data is Map
        ? Map<String, dynamic>.from(response.data as Map)
        : <String, dynamic>{};
    final data = responseBody['data'];
    final List<ActivityItemModel> items = <ActivityItemModel>[];
    if (data is List) {
      for (final item in data) {
        if (item is Map) {
          items.add(
            _mapBookingToActivity(Map<String, dynamic>.from(item), uiStatus),
          );
        }
      }
    }
    return items;
  }

  ActivityItemModel _mapBookingToActivity(
    Map<String, dynamic> booking,
    ActivityStatusModel status,
  ) {
    final Map<String, dynamic> spot = booking['spot'] is Map
        ? Map<String, dynamic>.from(booking['spot'])
        : <String, dynamic>{};
    final Map<String, dynamic> owner = booking['owner'] is Map
        ? Map<String, dynamic>.from(booking['owner'])
        : <String, dynamic>{};
    final Map<String, dynamic> slot = booking['slot'] is Map
        ? Map<String, dynamic>.from(booking['slot'])
        : <String, dynamic>{};
    final String title = spot['title']?.toString().trim().isNotEmpty == true
        ? spot['title'].toString()
        : 'Spot Booking';
    final String ownerName =
        owner['fullName']?.toString().trim().isNotEmpty == true
        ? owner['fullName'].toString()
        : 'Spot Owner';
    final String imagePath = _pickImageUrl(spot['images']);
    final String dateLabel = _formatDate(booking['date']?.toString());
    final String timeRange = _formatTimeRange(slot);
    final String location = _formatLocation(spot['location']);
    final int price = _readInt(spot['price'] ?? booking['totalAmount']);
    final String? spotId = spot['_id']?.toString();

    return ActivityItemModel(
      title: title,
      dateLabel: dateLabel,
      rating: 0,
      status: status,
      imagePath: imagePath,
      timeRange: timeRange,
      location: location,
      ownerName: ownerName,
      reviewsCount: 0,
      pricePerDay: price,
      spotId: spotId,
    );
  }

  String _formatDate(String? value) {
    if (value == null || value.isEmpty) return 'Available';
    final DateTime? dateTime = DateTime.tryParse(value);
    if (dateTime == null) return 'Available';
    const List<String> months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final String month = months[dateTime.month - 1];
    return '$month ${dateTime.day}, ${dateTime.year}';
  }

  String _pickImageUrl(dynamic images) {
    if (images is List && images.isNotEmpty) {
      final dynamic first = images.first;
      if (first is Map && first['url'] != null) {
        return first['url'].toString();
      }
      if (first is String) return first;
    }
    return 'https://images.unsplash.com/photo-1482192596544-9eb780fc7f66?auto=format&fit=crop&w=1200&q=80';
  }

  String _formatLocation(dynamic location) {
    if (location is Map) {
      final String address = location['address']?.toString() ?? '';
      final String city = location['city']?.toString() ?? '';
      final String country = location['country']?.toString() ?? '';
      final parts = <String>[
        if (address.isNotEmpty) address,
        if (city.isNotEmpty) city,
        if (country.isNotEmpty) country,
      ];
      if (parts.isNotEmpty) {
        return parts.join(', ');
      }
    }
    return 'Unknown location';
  }

  String _formatTimeRange(Map<String, dynamic> slot) {
    final String start = slot['start']?.toString().trim() ?? '';
    final String end = slot['end']?.toString().trim() ?? '';
    if (start.isEmpty || end.isEmpty) return 'Time not set';
    return '${_formatTime(start)} - ${_formatTime(end)}';
  }

  String _formatTime(String value) {
    final List<String> parts = value.split(':');
    if (parts.length < 2) return value;
    final int? hour = int.tryParse(parts[0]);
    final int? minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return value;
    final int hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final String suffix = hour >= 12 ? 'PM' : 'AM';
    final String minuteText = minute.toString().padLeft(2, '0');
    return '$hour12:$minuteText $suffix';
  }

  int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  void updateProfile(UserProfileDataModel updatedProfile) {
    profile.value = updatedProfile;
  }

  Future<void> pickAvatarFromGallery() async {
    final XFile? picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 92,
    );
    if (picked == null) {
      return;
    }

    _pendingAvatarFile = picked;
    final UserProfileDataModel current = profile.value;
    profile.value = current.copyWith(avatarBytes: await picked.readAsBytes());
  }

  Future<bool> updateProfileRemote({
    required String fullName,
    required String email,
    required String phone,
    required String bio,
  }) async {
    try {
      final formData = dio.FormData.fromMap(<String, dynamic>{
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'bio': bio,
        if (_pendingAvatarFile != null)
          'avatar': await dio.MultipartFile.fromFile(
            _pendingAvatarFile!.path,
            filename: _pendingAvatarFile!.name,
          ),
      });

      final response = await _appPigeon.put(
        ApiEndpoints.getCurrentProfile,
        data: formData,
        options: dio.Options(contentType: 'multipart/form-data'),
      );
      final statusCode = response.statusCode ?? 0;
      if (statusCode < 200 || statusCode >= 300) {
        return false;
      }

      final data = _extractProfileData(response.data);
      if (data.isNotEmpty) {
        _applyProfileData(data);
      }
      _pendingAvatarFile = null;
      return true;
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic> _extractProfileData(dynamic responseData) {
    final responseBody = responseData is Map
        ? Map<String, dynamic>.from(responseData)
        : <String, dynamic>{};
    final payload = responseBody['data'];
    return payload is Map ? Map<String, dynamic>.from(payload) : responseBody;
  }

  void _applyProfileData(Map<String, dynamic> data) {
    final avatarPayload = data['avatar'];
    final avatarData = avatarPayload is Map
        ? Map<String, dynamic>.from(avatarPayload)
        : <String, dynamic>{};

    String readString(dynamic value) => value?.toString().trim() ?? '';
    String pickFirstString(List<dynamic> values) {
      for (final value in values) {
        final candidate = readString(value);
        if (candidate.isNotEmpty) {
          return candidate;
        }
      }
      return '';
    }

    final fullName = pickFirstString(<dynamic>[
      data['fullName'],
      data['name'],
      data['username'],
    ]);
    final email = readString(data['email']);
    final phone = pickFirstString(<dynamic>[
      data['phone'],
      data['phoneNumber'],
    ]);
    final description = pickFirstString(<dynamic>[
      data['bio'],
      data['description'],
      data['about'],
    ]);
    final avatarUrl = pickFirstString(<dynamic>[
      avatarData['url'],
      data['avatarUrl'],
      data['avatar'],
    ]);

    final UserProfileDataModel current = profile.value;
    profile.value = current.copyWith(
      name: fullName.isNotEmpty ? fullName : current.name,
      email: email.isNotEmpty ? email : current.email,
      phone: phone.isNotEmpty ? phone : current.phone,
      description: description.isNotEmpty ? description : current.description,
      avatarUrl: avatarUrl.isNotEmpty ? avatarUrl : current.avatarUrl,
    );
  }

  static ProfileController instance() {
    if (Get.isRegistered<ProfileController>()) {
      return Get.find<ProfileController>();
    }
    return Get.put<ProfileController>(ProfileController());
  }
}

class _StatusRequest {
  final String apiStatus;
  final ActivityStatusModel uiStatus;

  const _StatusRequest(this.apiStatus, this.uiStatus);
}
