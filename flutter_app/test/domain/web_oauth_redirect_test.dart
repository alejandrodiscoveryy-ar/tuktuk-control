import 'package:control_tuk_tuk/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web OAuth redirect preserves subpath and removes transient parts', () {
    final redirect = webOAuthRedirect(
      Uri.parse('https://www.vrixora.com/tuktuk/?preview=welcome#section'),
    );

    expect(redirect, 'https://www.vrixora.com/tuktuk/');
  });

  test('web OAuth redirect supports local development origins', () {
    final redirect = webOAuthRedirect(
      Uri.parse('http://127.0.0.1:8090/?debug=true'),
    );

    expect(redirect, 'http://127.0.0.1:8090/');
  });
}
