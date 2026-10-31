import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
void main() {
  test('Web trabajando avisa GPS no confirmado y permite reintentar', () {
    final source = File('lib/presentation/marketplace_jobs.dart').readAsStringSync();
    expect(source, contains("ValueKey('work-gps-readiness-warning')"));
    expect(source, contains('kIsWeb && available && !onRide'));
    expect(source, contains('requestPermission: true'));
    expect(source, contains('if (mounted && kIsWeb) setState(() {})'));
  });
}
