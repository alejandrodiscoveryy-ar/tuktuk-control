import 'package:share_plus/share_plus.dart';

Future<bool> shareReferralLink({
  required String title,
  required String text,
  required String url,
}) async {
  try {
    final result = await SharePlus.instance.share(
      ShareParams(
        title: title,
        text: '$text\n$url',
      ),
    );
    return result.status != ShareResultStatus.unavailable;
  } catch (_) {
    return false;
  }
}
