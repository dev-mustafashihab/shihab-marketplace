import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' show Response;
import 'package:http/testing.dart';
import 'package:marketplace_app/core/network/api_client.dart';
import 'package:marketplace_app/core/theme/app_theme.dart';
import 'package:marketplace_app/features/notifications/notifications_screen.dart';

void main() {
  testWidgets('notifications screen renders rows from the API envelope', (tester) async {
    final api = ApiClient(
      baseUrl: 'https://example.test',
      token: 'access-token',
      client: MockClient((request) async {
        if (request.url.path == '/notifications') {
          return Response(
            jsonEncode({
              'success': true,
              'data': [
                1,
                [
                  {
                    'id': 'notification-1',
                    'type': 'BOOKING_CONFIRMED',
                    'title': 'Booking confirmed',
                    'body': 'Your booking is confirmed',
                    'readAt': null,
                    'createdAt': '2026-09-03T10:00:00.000Z',
                  },
                ],
              ],
              'message': null,
              'meta': {},
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/notifications/unread-count') {
          return Response(
            jsonEncode({'success': true, 'data': 1, 'message': null, 'meta': {}}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return Response('{}', 404, headers: {'content-type': 'application/json'});
      }),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionTokenProvider.overrideWith((ref) => 'access-token'),
          apiClientProvider.overrideWithValue(api),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const NotificationsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Booking confirmed'), findsOneWidget);
    expect(find.text('Your booking is confirmed'), findsOneWidget);
  });
}
