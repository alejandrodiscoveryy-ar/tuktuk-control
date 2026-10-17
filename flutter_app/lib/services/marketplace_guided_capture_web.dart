import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

// Implemented by web/guided_camera.js. The browser keeps the stream local.
@JS('tuktukGuidedCapturePhoto')
external JSPromise<JSString?> _tuktukGuidedCapturePhoto(JSString kind);

Future<Uint8List?> captureGuidedMarketplacePhoto(String kind) async {
  final result = await _tuktukGuidedCapturePhoto(kind.toJS).toDart;
  if (result == null) return null;
  return base64Decode(result.toDart);
}
