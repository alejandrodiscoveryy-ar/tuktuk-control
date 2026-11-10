import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const androidManifest = 'android/app/src/main/AndroidManifest.xml';
  const legacyRules = 'android/app/src/main/res/xml/tuktuk_legacy_backup_rules.xml';
  const modernRules = 'android/app/src/main/res/xml/tuktuk_data_extraction_rules.xml';
  const domains = <String>[
    'root',
    'file',
    'database',
    'sharedpref',
    'device_root',
    'device_file',
    'device_database',
    'device_sharedpref',
    'external',
  ];

  test('Conductor desactiva copia automatica y referencia ambas reglas', () {
    final manifest = File(androidManifest).readAsStringSync();
    expect(manifest, contains('android:allowBackup="false"'));
    expect(
      manifest,
      contains('android:fullBackupContent="@xml/tuktuk_legacy_backup_rules"'),
    );
    expect(
      manifest,
      contains('android:dataExtractionRules="@xml/tuktuk_data_extraction_rules"'),
    );
  });

  test('Android 11- excluye todos los dominios de datos persistentes', () {
    final xml = File(legacyRules).readAsStringSync();
    expect(xml, contains('<full-backup-content>'));
    for (final domain in domains) {
      expect(xml, contains('<exclude domain="$domain" path="." />'));
    }
    expect(xml, isNot(contains('<include')));
  });

  test('Android 12+ excluye nube y transferencia entre dispositivos', () {
    final xml = File(modernRules).readAsStringSync();
    for (final block in ['cloud-backup', 'device-transfer']) {
      final match = RegExp('<$block>[\\s\\S]*?</$block>').firstMatch(xml);
      expect(match, isNotNull, reason: '$block necesita reglas propias');
      final content = match!.group(0)!;
      for (final domain in domains) {
        expect(content, contains('<exclude domain="$domain" path="." />'));
      }
      expect(content, isNot(contains('<include')));
    }
  });
}
