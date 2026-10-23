// El código nativo y la dependencia de cámara no se cargan en la WebApp.
export 'marketplace_identity_capture_stub.dart'
    if (dart.library.io) 'marketplace_identity_capture_io.dart';
