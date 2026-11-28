import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('presence heartbeat is independent from GPS and respects rest', () {
    final screen = File('lib/presentation/marketplace_jobs.dart').readAsStringSync();
    final service = File('lib/data/marketplace_service.dart').readAsStringSync();
    final start = screen.indexOf('Future<void> _sendPresenceHeartbeat()');
    final end = screen.indexOf('void _refreshAvailability()', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final heartbeat = screen.substring(start, end);
    expect(heartbeat, contains('vehicle?.acceptingJobs != true'));
    expect(heartbeat, contains('AppLifecycleState.resumed'));
    expect(heartbeat, contains('_presenceHeartbeatInFlight'));
    expect(heartbeat, contains('_lastPresenceHeartbeatUserId == userId'));
    expect(heartbeat, contains('_lastPresenceHeartbeatVehicleId == vehicleId'));
    expect(heartbeat, contains('age < const Duration(seconds: 30)'));
    expect(heartbeat, contains('if (working && mounted'));
    expect(screen, contains('final keepIdleWebSample = kIsWeb && !refreshHistory'));
    expect(screen, contains('_operationalLocationTimer?.isActive == true && gpsAge != null'));
    expect(screen, contains('!wasActiveService && _operationalActiveJob() == null'));
    expect(screen, contains('immediate: !keepIdleWebSample'));
    expect(heartbeat, contains('await _load();'));
    expect(heartbeat, isNot(contains('setAcceptingJobs(')));
    expect(heartbeat, isNot(contains('Geolocator')));
    expect(screen, contains('_presenceHeartbeatTimer?.cancel()'));
    expect(screen, contains('Timer.periodic(const Duration(minutes: 2)'));
    expect(service, contains("'marketplace_driver_presence_heartbeat_v2'"));
    expect(service, contains("'target_vehicle_id': vehicleId"));
  });
}
