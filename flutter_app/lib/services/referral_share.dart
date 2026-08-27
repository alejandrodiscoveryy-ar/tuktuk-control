export 'referral_share_stub.dart'
    if (dart.library.io) 'referral_share_native.dart'
    if (dart.library.js_interop) 'referral_share_web.dart';
