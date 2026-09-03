import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../network/api_client.dart';

/// خدمة الجلسة الدائمة: حفظ التوكن + نقطة الموقع — الواجهة الموحدة للتبعية.
class SessionService {
  static const _kToken = 'sm_token';
  static const _kRefresh = 'sm_refresh';
  static const _kLat = 'sm_lat';
  static const _kLng = 'sm_lng';
  static const _kCity = 'sm_city';

  /// حمّل الجلسة المحفوظة عند إقلاع التطبيق.
  static Future<void> restore(ProviderContainer container) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_kToken);
      if (token != null && token.isNotEmpty) {
        container.read(sessionTokenProvider.notifier).state = token;
      }
      final lat = prefs.getDouble(_kLat);
      final lng = prefs.getDouble(_kLng);
      if (lat != null && lng != null) {
        container.read(userLocationProvider.notifier).state = LatLng(lat: lat, lng: lng);
      }
      final city = prefs.getString(_kCity);
      if (city != null) {
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

  static Future<void> saveLocation(double? lat, double? lng, String? city) async {
    final prefs = await SharedPreferences.getInstance();
    if (lat == null || lng == null) {
      await prefs.remove(_kLat);
      await prefs.remove(_kLng);
    } else {
      await prefs.setDouble(_kLat, lat);
      await prefs.setDouble(_kLng, lng);
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

/// جلب الموقع التقريبي عبر IP (يعمل بلا صلاحيات على كل المنصات)
Future<bool> acquireLocation(WidgetRef ref) async {
  try {
    final res = await http.get(
      Uri.parse('https://ipapi.co/json/'),
      headers: {'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return false;
    final d = jsonDecode(res.body) as Map<String, dynamic>;
    final lat = d['latitude'];
    final lng = d['longitude'];
    if (lat is num && lng is num) {
      ref.read(userLocationProvider.notifier).state = LatLng(lat: lat.toDouble(), lng: lng.toDouble());
      await SessionService.saveLocation(lat.toDouble(), lng.toDouble(), null);
      return true;
    }
    return false;
  } catch (_) {
    return false;
  }
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
