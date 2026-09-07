import 'dart:async';

import 'package:app_links/app_links.dart';

typedef ReferralUriCallback = FutureOr<void> Function(Uri uri);

class ReferralLinkListener {
  ReferralLinkListener({
    required ReferralUriCallback onUri,
    AppLinks? appLinks,
  })  : _onUri = onUri,
        _appLinks = appLinks ?? AppLinks();

  final ReferralUriCallback _onUri;
  final AppLinks _appLinks;
  StreamSubscription<Uri>? _subscription;

  Future<void> start() async {
    if (_subscription != null) return;
    _subscription = _appLinks.uriLinkStream.listen(
      (uri) => unawaited(_deliver(uri)),
      onError: (_) {},
    );
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null && _subscription != null) await _deliver(uri);
    } catch (_) {
      // The live stream remains available if the platform initial read fails.
    }
  }

  Future<void> _deliver(Uri uri) async {
    try {
      await _onUri(uri);
    } catch (_) {
      // A platform event must not escape as an unhandled asynchronous error.
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
