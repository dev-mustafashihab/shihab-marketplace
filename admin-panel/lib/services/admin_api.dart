import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _baseUrl = 'http://127.0.0.1:5400/api/v1';

final adminTokenProvider = StateProvider<String?>((ref) => null);

final adminApiProvider = Provider((ref) => AdminApi(ref));

class AdminApi {
  final Ref _ref;
  AdminApi(this._ref);

  String? get _token => _ref.read(adminTokenProvider);

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  Future<Map<String, dynamic>> login(String email, String password) async {
    final r = await http.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final d = jsonDecode(r.body);
    if (r.statusCode != 200) throw Exception(d['message'] ?? 'خطأ في الدخول');
    final token = d['accessToken'] as String;
    _ref.read(adminTokenProvider.notifier).state = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('admin_token', token);
    return d;
  }

  Future<void> logout() async {
    _ref.read(adminTokenProvider.notifier).state = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('admin_token');
  }

  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('admin_token');
    if (token != null) _ref.read(adminTokenProvider.notifier).state = token;
  }

  Future<dynamic> get(String path) async {
    final r = await http.get(Uri.parse('$_baseUrl$path'), headers: _headers);
    if (r.statusCode == 401) { logout(); throw Exception('انتهت الجلسة'); }
    return jsonDecode(r.body);
  }

  Future<dynamic> patch(String path, {Map<String, dynamic>? body}) async {
    final r = await http.patch(Uri.parse('$_baseUrl$path'), headers: _headers, body: jsonEncode(body ?? {}));
    if (r.statusCode == 401) { logout(); throw Exception('انتهت الجلسة'); }
    return jsonDecode(r.body);
  }

  Future<dynamic> post(String path, {Map<String, dynamic>? body}) async {
    final r = await http.post(Uri.parse('$_baseUrl$path'), headers: _headers, body: jsonEncode(body ?? {}));
    if (r.statusCode == 401) { logout(); throw Exception('انتهت الجلسة'); }
    return jsonDecode(r.body);
  }

  Future<dynamic> delete(String path) async {
    final r = await http.delete(Uri.parse('$_baseUrl$path'), headers: _headers);
    if (r.statusCode == 401) { logout(); throw Exception('انتهت الجلسة'); }
    return jsonDecode(r.body);
  }
}
