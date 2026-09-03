import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marketplace_app/core/session/session_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeLocationGateway implements LocationGateway {
  LocationPermissionState permission = LocationPermissionState.foreground;
  LocationPermissionState requestedPermission = LocationPermissionState.foreground;
  bool serviceEnabled = true;
  LocationFix? currentFix = const LocationFix(latitude: 33.51, longitude: 36.27, accuracy: 8);
  LocationFix? lastFix;
  Object? currentError;
  int requestPermissionCalls = 0;
  int currentPositionCalls = 0;
  int lastPositionCalls = 0;

  @override
  Future<LocationPermissionState> checkPermission() async => permission;

  @override
  Future<LocationPermissionState> requestPermission() async {
    requestPermissionCalls++;
    return requestedPermission;
  }

  @override
  Future<bool> isServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationFix> getCurrentPosition() async {
    currentPositionCalls++;
    if (currentError != null) throw currentError!;
    return currentFix!;
  }

  @override
  Future<LocationFix?> getLastKnownPosition() async {
    lastPositionCalls++;
    return lastFix;
  }

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
}

void main() {
  test('returns deniedForever without attempting GPS', () async {
    final gateway = _FakeLocationGateway()
      ..permission = LocationPermissionState.deniedForever;

    final result = await LocationService(gateway: gateway).locate();

    expect(result.isSuccess, isFalse);
    expect(result.reason, LocationFailureReason.permissionDeniedForever);
    expect(gateway.currentPositionCalls, 0);
  });

  test('reports disabled location service instead of using a network fallback', () async {
    final gateway = _FakeLocationGateway()..serviceEnabled = false;

    final result = await LocationService(gateway: gateway).locate();

    expect(result.isSuccess, isFalse);
    expect(result.reason, LocationFailureReason.serviceDisabled);
    expect(gateway.currentPositionCalls, 0);
  });

  test('returns a real GPS fix and preserves its accuracy', () async {
    final gateway = _FakeLocationGateway()
      ..currentFix = const LocationFix(latitude: 35.13, longitude: 36.75, accuracy: 12.5);

    final result = await LocationService(gateway: gateway).locate();

    expect(result.isSuccess, isTrue);
    expect(result.source, LocationSource.gps);
    expect(result.fix?.latitude, 35.13);
    expect(result.fix?.accuracy, 12.5);
  });

  test('uses last known GPS fix when the current reading fails', () async {
    final gateway = _FakeLocationGateway()
      ..currentError = Exception('GPS timeout')
      ..currentFix = null
      ..lastFix = const LocationFix(latitude: 36.20, longitude: 37.13, accuracy: 40);

    final result = await LocationService(gateway: gateway).locate();

    expect(result.isSuccess, isTrue);
    expect(result.source, LocationSource.gps);
    expect(result.fix?.latitude, 36.20);
    expect(gateway.lastPositionCalls, 1);
  });

  test('does not restore a legacy network location as current GPS', () async {
    SharedPreferences.setMockInitialValues({
      'sm_lat': 33.51,
      'sm_lng': 36.27,
      'sm_city': 'موقعي الحالي',
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await SessionService.restore(container);

    expect(container.read(userLocationProvider), isNull);
    expect(container.read(userCityProvider), 'دمشق');
  });
}
