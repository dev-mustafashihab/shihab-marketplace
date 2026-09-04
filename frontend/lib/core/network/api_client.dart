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
  ApiClient({
    required this.baseUrl,
    String? token,
    this.onAuthLost,
    this.onTokenRefreshed,
    http.Client? client,
  })  : _client = client ?? http.Client(),
        _currentToken = token;
  final String baseUrl;
  final http.Client _client;
  String? _currentToken;

  /// توافق مع الشاشات التي تعرض حالة تسجيل الدخول.
  String? get token => _currentToken;

  /// يُستدعى مرة عند موت الجلسة (401 + فشل التجديد) ليعود التطبيق لحالة «سجّل الدخول».
  final void Function()? onAuthLost;

  /// يُستدعى بعد تدوير التوكن حتى تتحدث حالة Riverpod أيضاً.
  final void Function(String token)? onTokenRefreshed;

  /// قفل منع سباق التجديد: كل 401s المتزامنة تشارك Future واحدة بدل إطلاق عدة /auth/refresh
  /// (الـ backend يدوّر الـ refresh — الثاني بالقديم سيفشل ويمسح الجلسة بغير داعٍ)
  static Future<String?>? _refreshInFlight;

  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    var uri = Uri.parse('$baseUrl$path');
    if (query != null) {
      uri = uri.replace(queryParameters: {
        ...uri.queryParameters,
        ...query,
      });
    }
    return _run(() => _client.get(uri, headers: _headers()), path: path);
  }

  Future<dynamic> post(String path, {Object? body}) async {
    return _run(() => _client.post(Uri.parse('$baseUrl$path'),
        headers: _headers(), body: jsonEncode(body ?? {})), path: path);
  }

  Future<dynamic> patch(String path, {Object? body}) async {
    return _run(() => _client.patch(Uri.parse('$baseUrl$path'),
        headers: _headers(), body: jsonEncode(body ?? {})), path: path);
  }

  /// رفع صورة (multipart) — يُستخدم لصور الهوية. يرجع حقل url من الخادم.
  Future<String> uploadImage(String path, String filePath, {String field = 'file'}) async {
    final req = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'));
    if (_currentToken != null) req.headers['Authorization'] = 'Bearer $_currentToken';
    req.files.add(await http.MultipartFile.fromPath(field, filePath));
    final streamed = await req.send().timeout(const Duration(seconds: 30));
    final res = await http.Response.fromStream(streamed);
    if (res.body.isEmpty) throw ApiException('لا يوجد اتصال بالخادم', status: res.statusCode);
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400 || json['success'] == false) {
      final data = json['data'];
      final url = (data is Map && data['url'] is String) ? data['url'] as String : null;
      if (url != null && res.statusCode < 400) return url;
      throw ApiException((json['message'] as String?) ?? 'تعذر رفع الصورة',
          code: json['code'] as String?, status: res.statusCode);
    }
    final data = json['data'] ?? json;
    if (data is Map && data['url'] is String) return data['url'] as String;
    throw ApiException('استجابة رفع غير متوقعة', status: res.statusCode);
  }

  Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        if (_currentToken != null) 'Authorization': 'Bearer $_currentToken',
      };

  Future<dynamic> _run(Future<http.Response> Function() fn, {String path = '', bool retried = false}) async {
    final res = await fn().timeout(const Duration(seconds: 20));
    if (res.body.isEmpty) throw ApiException('لا يوجد اتصال بالخادم', status: res.statusCode);
    final json = jsonDecode(res.body) as Map<String, dynamic>;

    // 401 → جرّب تجديد الـ access عبر الـ refresh ثم أعد الطلب مرة واحدة
    // (طلب الدخول/التسجيل نفسه مستثنى — 401 فيه معناه بيانات خاطئة لا جلسة ميتة)
    if (res.statusCode == 401 && !retried && token != null && !path.startsWith('/auth/')) {
      final newToken = await _tryRefresh();
      if (newToken != null) {
        // قد تكون عملية التجديد بدأت من ApiClient آخر؛ حدّث هذا الكائن أيضاً.
        _currentToken = newToken;
        return _run(fn, path: path, retried: true);
      }
      // الجلسة ميتة فعلاً (لا refresh أو منتهي) → نظّفها كي تظهر شاشات «سجّل الدخول»
      _currentToken = null;
      await SessionService.saveToken(null);
      await SessionService.saveRefreshToken(null);
      onAuthLost?.call();
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

  /// تجديد الـ access token — بقفل مشترك يمنع سباق الدوران
  Future<String?> _tryRefresh() {
    if (_refreshInFlight != null) return _refreshInFlight!;
    _refreshInFlight = _doRefresh().whenComplete(() => _refreshInFlight = null);
    return _refreshInFlight!;
  }

  Future<String?> _doRefresh() async {
    try {
      final refresh = await SessionService.getRefreshToken();
      if (refresh == null || refresh.isEmpty) return null;
      final res = await _client
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
      _currentToken = access;
      await SessionService.saveToken(access);
      if (newRefresh != null && newRefresh.isNotEmpty) {
        await SessionService.saveRefreshToken(newRefresh);
      }
      onTokenRefreshed?.call(access);
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
    onAuthLost: () => ref.read(sessionTokenProvider.notifier).state = null,
    onTokenRefreshed: (token) => ref.read(sessionTokenProvider.notifier).state = token,
  );
});
