import 'dart:convert';
import 'package:http/http.dart' as http;

import '../session/session_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// طبقة الشبكة — envelope موحد {success,data,message,meta} + توكن اختياري.
class ApiException implements Exception {
  ApiException(this.message, {this.code, this.status});
  final String message;
  final String? code;
  final int? status;
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({required this.baseUrl, this.token});
  final String baseUrl;
  final String? token;

  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    var uri = Uri.parse('$baseUrl$path');
    if (query != null) {
      uri = uri.replace(queryParameters: {
        ...uri.queryParameters,
        ...query,
      });
    }
    return _run(() => http.get(uri, headers: _headers()));
  }

  Future<dynamic> post(String path, {Object? body}) async {
    return _run(() => http.post(Uri.parse('$baseUrl$path'),
        headers: _headers(), body: jsonEncode(body ?? {})));
  }

  Future<dynamic> patch(String path, {Object? body}) async {
    return _run(() => http.patch(Uri.parse('$baseUrl$path'),
        headers: _headers(), body: jsonEncode(body ?? {})));
  }

  Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<dynamic> _run(Future<http.Response> Function() fn, {bool retried = false}) async {
    final res = await fn().timeout(const Duration(seconds: 20));
    if (res.body.isEmpty) throw ApiException('لا يوجد اتصال بالخادم', status: res.statusCode);
    final json = jsonDecode(res.body) as Map<String, dynamic>;

    // 401 → جرّب تجديد الـ access عبر الـ refresh ثم أعد الطلب مرة واحدة
    if (res.statusCode == 401 && !retried) {
      final newToken = await _tryRefresh();
      if (newToken != null) {
        return _run(fn, retried: true);
      }
    }

    if (res.statusCode >= 400 || json['success'] != true) {
      throw ApiException(
        (json['message'] as String?) ?? 'حدث خطأ، أعد المحاولة',
        code: json['code'] as String?,
        status: res.statusCode,
      );
    }
    return json['data'];
  }

  /// تجديد الـ access token عبر refresh token المخزَّن — يحدّث الجلسة ويعيد توكن جديد أو null.
  Future<String?> _tryRefresh() async {
    try {
      final refresh = await SessionService.getRefreshToken();
      if (refresh == null || refresh.isEmpty) return null;
      final res = await http
          .post(Uri.parse('$baseUrl/auth/refresh'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'refreshToken': refresh}))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      if (json['success'] != true || json['data'] is! Map) return null;
      final d = json['data'] as Map<String, dynamic>;
      final access = d['accessToken'] as String?;
      final newRefresh = d['refreshToken'] as String?;
      if (access == null || access.isEmpty) return null;
      await SessionService.saveToken(access);
      if (newRefresh != null && newRefresh.isNotEmpty) {
        await SessionService.saveRefreshToken(newRefresh);
      }
      return access;
    } catch (_) {
      return null;
    }
  }
}

/// توكن الجلسة (مشترك بين الشاشات) — Phase 10: في الذاكرة + حفظ لاحق
final sessionTokenProvider = StateProvider<String?>((ref) => null);

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    baseUrl: 'https://panel.fahd-car.cloud/mp-api/api/v1',
    token: ref.watch(sessionTokenProvider),
  );
});
