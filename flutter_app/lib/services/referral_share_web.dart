import 'dart:js_interop';

@JS('navigator.share')
external JSPromise<JSAny?> _share(JSAny options);

Future<bool> shareReferralLink({
  required String title,
  required String text,
  required String url,
}) async {
  try {
    final options = <String, dynamic>{
      'title': title,
      'text': text,
      'url': url,
    }.jsify();
    if (options == null) return false;
    await _share(options).toDart;
    return true;
  } catch (_) {
    return false;
  }
}
