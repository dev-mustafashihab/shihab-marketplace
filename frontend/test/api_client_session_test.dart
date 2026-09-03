import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:marketplace_app/core/network/api_client.dart';
import 'package:marketplace_app/core/session/session_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({'sm_refresh': 'refresh-old'});
  });

  test('refreshes once and retries with the new access token', () async {
    final protectedAuthHeaders = <String>[];
    final calls = <String>[];

    final client = MockClient((request) async {
      calls.add('${request.method} ${request.url.path}');
      final auth = request.headers['authorization'] ?? request.headers['Authorization'] ?? '';

      if (request.url.path == '/protected') {
        protectedAuthHeaders.add(auth);
        if (protectedAuthHeaders.length == 1) {
          return Response(
            jsonEncode({'success': false, 'message': 'expired'}),
            401,
            headers: {'content-type': 'application/json'},
          );
        }
        return Response(
          jsonEncode({'success': true, 'data': {'value': 'ok'}}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      if (request.url.path == '/auth/refresh') {
        expect(auth, isEmpty);
        return Response(
          jsonEncode({
            'success': true,
            'data': {
              'accessToken': 'access-fresh',
              'refreshToken': 'refresh-new',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      return Response('{}', 404, headers: {'content-type': 'application/json'});
    });

    final api = ApiClient(
      baseUrl: 'https://example.test',
      token: 'access-expired',
      client: client,
    );

    final result = await api.get('/protected');

    expect(result, {'value': 'ok'});
    expect(calls, [
      'GET /protected',
      'POST /auth/refresh',
      'GET /protected',
    ]);
    expect(protectedAuthHeaders, ['Bearer access-expired', 'Bearer access-fresh']);
    expect(await SessionService.getRefreshToken(), 'refresh-new');
  });
}
