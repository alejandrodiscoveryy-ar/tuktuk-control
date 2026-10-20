import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('firma musical oficial y canal exclusivo Android', () {
    final web = File('web/index.html').readAsStringSync();
    final push = File('lib/services/push_notification_service.dart').readAsStringSync();
    expect(File('web/sounds/tuktuk_nueva_carrera.mp3').lengthSync(), greaterThan(10000));
    expect(File('android/app/src/main/res/raw/tuktuk_nueva_carrera.ogg').lengthSync(), greaterThan(10000));
    expect(web, contains("fetch('sounds/tuktuk_nueva_carrera.mp3')"));
    expect(web, contains('source.buffer = jobAudioBuffer'));
    expect(push, contains('tuktuk_nuevas_carreras_v1'));
    expect(push, contains("RawResourceAndroidNotificationSound('tuktuk_nueva_carrera')"));
    expect(push, contains('marketplaceJobIdFromPush(message.data) != null'));
  });
}
