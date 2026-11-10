import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const androidManifest = 'android/app/src/main/AndroidManifest.xml';
  const legacyRules = 'android/app/src/main/res/xml/tuktuk_legacy_backup_rules.xml';
  const modernRules = 'android/app/src/main/res/xml/tuktuk_data_extraction_rules.xml';

  test('Conductor desactiva la copia automatica de datos privados', () {
    final manifest = File(androidManifest).readAsStringSync();
    expect(manifest, contains('android:allowBackup="false"'));
    expect(manifest, contains('android:fullBackupContent="@xml/tuktuk_legacy_backup_rules"'));
    expect(manifest, contains('android:dataExtractionRules="@xml/tuktuk_data_extraction_rules"'));
  });

  test('Android anterior a 12 excluye almacenamientos privados', () {
    final xml = File(legacyRules).readAsStringSync();
    expect(xml, contains('<full-backup-content>'));
    for (final domain in ['root', 'device_root', 'external']) {
      expect(xml, contains('<exclude domain="$domain" path="." />'));
    }
  });

  test('Android 12+ excluye datos tanto de nube como entre dispositivos', () {
    final xml = File(modernRules).readAsStringSync();
    for (final block in ['cloud-backup', 'device-transfer']) {
      final match = RegExp('<$block>[\\s\\S]*?</$block>').firstMatch(xml);
      expect(match, isNotNull, reason: '$block debe tener reglas explicitas');
      final content = match!.group(0)!;
      for (final domain in ['root', 'device_root', 'external']) {
        expect(content, contains('<exclude domain="$domain" path="." />'));
      }
    }
  });
}
