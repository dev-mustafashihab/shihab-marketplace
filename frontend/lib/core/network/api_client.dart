import 'dart:convert';
import 'package:http/http.dart' as http;
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

  Future<dynamic> _run(Future<http.Response> Function() fn) async {
    final res = await fn().timeout(const Duration(seconds: 20));
    if (res.body.isEmpty) throw ApiException('لا يوجد اتصال بالخادم', status: res.statusCode);
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400 || json['success'] != true) {
      throw ApiException(
        (json['message'] as String?) ?? 'حدث خطأ، أعد المحاولة',
        code: json['code'] as String?,
        status: res.statusCode,
      );
    }
    return json['data'];
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
