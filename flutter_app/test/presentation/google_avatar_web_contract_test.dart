import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String screens;

  setUpAll(() {
    screens = File('lib/presentation/screens.dart').readAsStringSync();
  });

  group('Google avatar · Web', () {
    test('keeps Google metadata sources', () {
      expect(screens, contains("['avatar_url', 'picture']"));
    });

    test('uses Image.network with HTML fallback for cross-origin avatars', () {
      expect(screens, contains('Image.network('));
      expect(screens, contains('WebHtmlElementStrategy.fallback'));
      expect(
        screens,
        isNot(contains('backgroundImage: photoUrl == null')),
      );
    });
  });
}
