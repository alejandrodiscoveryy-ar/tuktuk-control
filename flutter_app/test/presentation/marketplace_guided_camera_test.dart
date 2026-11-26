import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all three registration photo types use the live WebApp guide', () {
    final ui = File('lib/presentation/marketplace_onboarding.dart')
        .readAsStringSync();
    expect(ui, contains("'driver_photo' => 'driver'"));
    expect(ui, contains("'vehicle_photo' => 'vehicle'"));
    expect(ui, contains("'identity_document' =>"));
    expect(ui, contains('captureGuidedMarketplacePhoto'));
    expect(ui, contains('normalizeMarketplaceImage('));
    expect(ui, contains('_choosePhotoSource()'));
  });

  test('WebApp loads the camera UI, keeps native path separate', () {
    final html = File('web/index.html').readAsStringSync();
    final script = File('web/guided_camera.js').readAsStringSync();
    final stub = File('lib/services/marketplace_guided_capture_stub.dart')
        .readAsStringSync();
    expect(html, contains('guided_camera.css'));
    expect(html, contains('guided_camera.js'));
    expect(script, contains('navigator.mediaDevices.getUserMedia'));
    expect(script, contains('facingMode: { ideal: guide.facing }'));
    expect(script, contains("canvas.toDataURL('image/jpeg', 0.92)"));
    expect(script, contains('stream.getTracks()'));
    expect(script, contains('Repetir foto'));
    expect(stub, contains('=> null'));
    expect(script, contains("event.key === 'Escape' && ready && !usingNative"));
    expect(script, contains("picker.setAttribute('capture', guide.facing)"));
    expect(script, contains("picker.addEventListener('change'"));
  });
}
