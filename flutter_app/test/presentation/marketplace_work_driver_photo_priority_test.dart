import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/presentation/marketplace_jobs.dart').readAsStringSync();
  final registration = File('lib/presentation/marketplace_onboarding.dart')
      .readAsStringSync();

  test('Trabajo prioriza foto TUKTUK y conserva Google como alternativa', () {
    final first = source.indexOf('Future<Uint8List>? _registeredWorkDriverPhoto()');
    final last = source.indexOf('Widget _workPremiumAvailability(', first);
    expect(first, greaterThan(0));
    expect(last, greaterThan(first));
    final avatar = source.substring(first, last);
    expect(avatar, contains('asset.id != photoId'));
    expect(avatar, contains("asset.storageBucket != 'marketplace-media'"));
    expect(avatar, contains('.download(asset.storagePath!)'));
    expect(avatar, contains('FutureBuilder<Uint8List>('));
    expect(avatar, contains('if (snapshot.hasData)'));
    expect(avatar, contains('return Image.memory('));
    expect(avatar, contains('return fallback();'));
    expect(avatar, contains('Image.network('));
    expect(avatar, contains('webHtmlElementStrategy: WebHtmlElementStrategy.fallback'));
  });

  test('Cambio de foto o usuario invalida foto privada anterior', () {
    expect(source, contains('final cacheKey ='));
    expect(source, contains('_workDriverPhotoKey != cacheKey'));
    expect(source, contains('_workOnboardingUserId != userId'));
    expect(source, contains('_workOnboardingUserId = userId;'));
    expect(source, contains('_workOnboardingUserId = null;'));
    expect(source, contains('onManagementChanged: _onManagementChanged'));
    expect(source, contains('unawaited(_load())'));
  });

  test('Mapa y menu usan la misma foto de conductor sin alterar acciones', () {
    final mapAvatar = source.indexOf('Widget _workPremiumAvatar(String? photo)');
    final menuAvatar = source.indexOf('Widget _workDrawerDriverHeader()');
    expect(mapAvatar, greaterThan(0));
    expect(menuAvatar, greaterThan(0));
    expect(source.substring(mapAvatar, mapAvatar + 1500),
        contains('_workDriverAvatarImage('));
    expect(source.substring(menuAvatar, menuAvatar + 1400),
        contains('_workDriverAvatarImage('));
    expect(source, contains("ValueKey('work-map-open-menu')"));
    expect(source, contains('_workDrawerOpen = true'));
  });

  test('El alta sigue exigiendo foto propia o importada de Google', () {
    expect(registration, contains('_service.adoptGoogleAvatar('));
    expect(registration, contains("_pickPhoto('driver_photo')"));
    expect(registration, contains('Añade una foto del conductor para completar el perfil.'));
    expect(source, contains('_marketplaceDriverNeedsSetup(onboarding)'));
  });
}