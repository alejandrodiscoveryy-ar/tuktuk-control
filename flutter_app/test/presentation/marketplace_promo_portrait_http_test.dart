import 'dart:typed_data';

import 'package:control_tuk_tuk/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('authorized signed portrait is downloaded without changing its URL', () async {
    final url = Uri.parse('https://example.com/portrait.jpg?token=signed-test');
    final bytes = Uint8List.fromList([255, 216, 255, 217]);
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url, url);
      expect(request.headers.containsKey('authorization'), isFalse);
      return http.Response.bytes(bytes, 200);
    });
    addTearDown(client.close);
    expect(await downloadMarketplacePromoPortrait(url, client: client), bytes);
  });

  test('expired signed portrait and unsafe URLs are rejected', () async {
    final client = MockClient((request) async => http.Response('expired', 403));
    addTearDown(client.close);
    await expectLater(
      downloadMarketplacePromoPortrait(Uri.parse('https://example.com/photo.jpg'), client: client),
      throwsStateError,
    );
    await expectLater(
      downloadMarketplacePromoPortrait(Uri.parse('http://example.com/photo.jpg'), client: client),
      throwsStateError,
    );
  });
}
