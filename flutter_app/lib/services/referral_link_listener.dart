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

  void start() {
    if (_subscription != null) return;
    _subscription = _appLinks.uriLinkStream.listen(
      (uri) => _onUri(uri),
      onError: (_) {},
    );
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
