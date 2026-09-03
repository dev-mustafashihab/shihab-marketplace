import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/api_client.dart';

enum LocationSource { gps, manual }

enum LocationPermissionState { denied, deniedForever, foreground, always }

enum LocationFailureReason {
  permissionDenied,
  permissionDeniedForever,
  serviceDisabled,
  timeout,
  unavailable,
}

class LocationFix {
  const LocationFix({required this.latitude, required this.longitude, required this.accuracy});

  final double latitude;
  final double longitude;
  final double accuracy;
}

class LocationResult {
  const LocationResult.success(this.fix)
      : source = LocationSource.gps,
        reason = null;

  const LocationResult.failure(this.reason)
      : fix = null,
        source = null;

  final LocationFix? fix;
  final LocationSource? source;
  final LocationFailureReason? reason;
  bool get isSuccess => fix != null;
}

abstract class LocationGateway {
  Future<LocationPermissionState> checkPermission();
  Future<LocationPermissionState> requestPermission();
  Future<bool> isServiceEnabled();
  Future<LocationFix> getCurrentPosition();
  Future<LocationFix?> getLastKnownPosition();
  Future<bool> openAppSettings();
  Future<bool> openLocationSettings();
}

class GeolocatorLocationGateway implements LocationGateway {
  @override
  Future<LocationPermissionState> checkPermission() async {
    return _mapPermission(await Geolocator.checkPermission());
  }

  @override
  Future<LocationPermissionState> requestPermission() async {
    return _mapPermission(await Geolocator.requestPermission());
  }

  @override
  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationFix> getCurrentPosition() async {
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 25),
      ),
    );
    return LocationFix(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
    );
  }

  @override
  Future<LocationFix?> getLastKnownPosition() async {
    final position = await Geolocator.getLastKnownPosition();
    if (position == null) return null;
    return LocationFix(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
    );
  }

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  LocationPermissionState _mapPermission(LocationPermission permission) {
    switch (permission) {
      case LocationPermission.deniedForever:
        return LocationPermissionState.deniedForever;
      case LocationPermission.whileInUse:
        return LocationPermissionState.foreground;
      case LocationPermission.always:
        return LocationPermissionState.always;
      case LocationPermission.denied:
      default:
        return LocationPermissionState.denied;
    }
  }
}

class LocationService {
  LocationService({LocationGateway? gateway}) : _gateway = gateway ?? GeolocatorLocationGateway();

  final LocationGateway _gateway;

  Future<LocationResult> locate() async {
    var permission = await _gateway.checkPermission();
    if (permission == LocationPermissionState.denied) {
      permission = await _gateway.requestPermission();
    }
    if (permission == LocationPermissionState.deniedForever) {
      return const LocationResult.failure(LocationFailureReason.permissionDeniedForever);
    }
    if (permission == LocationPermissionState.denied) {
      return const LocationResult.failure(LocationFailureReason.permissionDenied);
    }
    if (!await _gateway.isServiceEnabled()) {
      return const LocationResult.failure(LocationFailureReason.serviceDisabled);
    }

    var failure = LocationFailureReason.unavailable;
    try {
      return LocationResult.success(
        await _gateway.getCurrentPosition().timeout(const Duration(seconds: 25)),
      );
    } on TimeoutException {
      failure = LocationFailureReason.timeout;
    } catch (_) {
      failure = LocationFailureReason.unavailable;
    }

    // آخر موقع GPS معروف أفضل من تحويل موقع الشبكة إلى GPS وهمي.
    try {
      final last = await _gateway.getLastKnownPosition().timeout(const Duration(seconds: 3));
      if (last != null) return LocationResult.success(last);
    } catch (_) {
      // نرجع سبب الفشل الأساسي للواجهة.
    }
    return LocationResult.failure(failure);
  }
}

/// خدمة الجلسة الدائمة: حفظ التوكن + نقطة الموقع — الواجهة الموحدة للتبعية.
class SessionService {
  static const _kToken = 'sm_token';
  static const _kRefresh = 'sm_refresh';
  static const _kLat = 'sm_lat';
  static const _kLng = 'sm_lng';
  static const _kCity = 'sm_city';
  static const _kLocationSource = 'sm_location_source';

  /// حمّل الجلسة المحفوظة عند إقلاع التطبيق.
  static Future<void> restore(ProviderContainer container) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_kToken);
      if (token != null && token.isNotEmpty) {
        container.read(sessionTokenProvider.notifier).state = token;
      }
      final city = prefs.getString(_kCity);
      final source = prefs.getString(_kLocationSource);
      final lat = prefs.getDouble(_kLat);
      final lng = prefs.getDouble(_kLng);
      final isKnownLocation = source == LocationSource.gps.name ||
          source == LocationSource.manual.name ||
          (source == null && city != null && city != 'موقعي الحالي');
      if (lat != null && lng != null && isKnownLocation) {
        container.read(userLocationProvider.notifier).state = LatLng(lat: lat, lng: lng);
      }
      if (city != null && !(source == null && city == 'موقعي الحالي')) {
        container.read(userCityProvider.notifier).state = city;
      }
    } catch (_) {
      // فشل الاسترجاع غير قاتل — جلسة جديدة
    }
  }

  static Future<void> saveToken(String? token) async {
    final prefs = await SharedPreferences.getInstance();
    if (token == null || token.isEmpty) {
      await prefs.remove(_kToken);
    } else {
      await prefs.setString(_kToken, token);
    }
  }

  /// توكن التجديد (7 أيام) — يُحفظ مع الدخول ويُستخدم عند انتهاء الـ access.
  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kRefresh);
  }

  static Future<void> saveRefreshToken(String? token) async {
    final prefs = await SharedPreferences.getInstance();
    if (token == null || token.isEmpty) {
      await prefs.remove(_kRefresh);
    } else {
      await prefs.setString(_kRefresh, token);
    }
  }

  static Future<void> saveLocation(
    double? lat,
    double? lng,
    String? city, {
    LocationSource source = LocationSource.manual,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (lat == null || lng == null) {
      await prefs.remove(_kLat);
      await prefs.remove(_kLng);
      await prefs.remove(_kLocationSource);
    } else {
      await prefs.setDouble(_kLat, lat);
      await prefs.setDouble(_kLng, lng);
      await prefs.setString(_kLocationSource, source.name);
    }
    if (city == null) {
      await prefs.remove(_kCity);
    } else {
      await prefs.setString(_kCity, city);
    }
  }
}

class LatLng {
  const LatLng({required this.lat, required this.lng});
  final double lat;
  final double lng;
}

/// موقع المستخدم الحالي (null = غير محدد → دمشق افتراضياً)
final userLocationProvider = StateProvider<LatLng?>((ref) => null);

/// اسم المدينة المعروض في الشريط العلوي
final userCityProvider = StateProvider<String>((ref) => 'دمشق');

/// طلب موقع GPS من الواجهة بعد ضغط المستخدم، بلا طلب صامت عند الإقلاع.
Future<LocationResult> acquireLocationResult(WidgetRef ref, {LocationService? service}) async {
  final result = await (service ?? LocationService()).locate();
  final fix = result.fix;
  if (fix != null) {
    ref.read(userLocationProvider.notifier).state = LatLng(lat: fix.latitude, lng: fix.longitude);
    await SessionService.saveLocation(fix.latitude, fix.longitude, null, source: LocationSource.gps);
  }
  return result;
}

Future<bool> acquireLocation(WidgetRef ref) async {
  return (await acquireLocationResult(ref)).isSuccess;
}

/// إحداثيات مدن سوريا الرئيسية — للاختيار اليدوي
const SYRIA_CITIES = <String, LatLng>{
  'دمشق': LatLng(lat: 33.5138, lng: 36.2765),
  'ريف دمشق': LatLng(lat: 33.4700, lng: 36.3000),
  'حلب': LatLng(lat: 36.2021, lng: 37.1343),
  'حمص': LatLng(lat: 34.7324, lng: 36.7137),
  'حماة': LatLng(lat: 35.1318, lng: 36.7580),
  'اللاذقية': LatLng(lat: 35.5184, lng: 35.7955),
  'طرطوس': LatLng(lat: 34.8890, lng: 35.8866),
  'درعا': LatLng(lat: 32.6253, lng: 36.1025),
  'السويداء': LatLng(lat: 32.7057, lng: 36.8714),
  'قنيطرة': LatLng(lat: 33.1250, lng: 35.8250),
  'دير الزور': LatLng(lat: 35.3360, lng: 40.1420),
  'الحسكة': LatLng(lat: 36.5020, lng: 40.7480),
  'الرقة': LatLng(lat: 35.9500, lng: 38.9970),
  'إدلب': LatLng(lat: 35.9330, lng: 36.6330),
};
