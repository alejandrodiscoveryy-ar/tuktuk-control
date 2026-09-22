import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'los builds de cliente y prestador conservan bases y artefactos aislados',
      () {
    final provider = File('tool/build_web.ps1').readAsStringSync();
    final customer = File('tool/build_customer_web.ps1').readAsStringSync();

    expect(provider, contains('--base-href "/tuktuk/app/"'));
    expect(provider, isNot(contains('/cliente/tuk/')));
    expect(customer, contains('sync_project_branding.dart --web'));
    expect(customer, contains('--base-href "/cliente/tuk/"'));
    expect(customer, contains('--output build/customer-web'));
  });
}
