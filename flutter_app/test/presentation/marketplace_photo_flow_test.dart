import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String onboarding;
  late String service;
  late String recordStore;
  late String edge;
  late String jobs;

  setUpAll(() {
    onboarding =
        File('lib/presentation/marketplace_onboarding.dart').readAsStringSync();
    service = File('lib/data/marketplace_service.dart').readAsStringSync();
    recordStore = File('lib/data/record_store.dart').readAsStringSync();
    edge = File(
      'supabase/functions/marketplace-driver-google-avatar/index.ts',
    ).readAsStringSync();
    jobs = File('lib/presentation/marketplace_jobs.dart').readAsStringSync();
  });

  test('manual and saved Marketplace photos have priority over Google', () {
    expect(onboarding, contains('if (pendingBytes != null) return image'));
    expect(
      onboarding,
      contains('A private Marketplace asset has priority over the Google fallback'),
    );
    expect(onboarding, contains('fallbackNetworkUrl: _googleDriverPhotoUrl'));
  });

  test('Google avatar is offered as the initial driver photo', () {
    expect(
      onboarding,
      contains('Usaremos tu foto de Google como foto inicial. Puedes cambiarla.'),
    );
    expect(onboarding, contains('_service.adoptGoogleAvatar('));
  });

  test('vehicle photo remains completely independent', () {
    final start = onboarding.indexOf('Future<void> _saveVehicle()');
    final end = onboarding.indexOf('Widget _buildAccessCard', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final saveVehicle = onboarding.substring(start, end);
    expect(saveVehicle, contains("assetKind: 'vehicle_photo'"));
    expect(saveVehicle, isNot(contains('adoptGoogleAvatar')));
  });

  test('MarketplaceService invokes the dedicated Google avatar function', () {
    expect(service, contains('Future<MarketplaceMediaAsset> adoptGoogleAvatar'));
    expect(service, contains("'marketplace-driver-google-avatar'"));
    expect(service, contains("'idempotency_key': idempotencyKey"));
  });

  test('Edge source never accepts an arbitrary avatar URL from the client', () {
    expect(edge, contains('user.user_metadata'));
    expect(edge, contains('metadata.avatar_url'));
    expect(edge, contains('metadata.picture'));
    expect(edge, isNot(contains('body.avatar_url')));
    expect(edge, isNot(contains('body.url')));
    expect(edge, contains('googleusercontent.com'));
    expect(edge, contains('client.auth.getUser(accessToken)'));
  });

  test('Edge source reuses the private Marketplace media contracts', () {
    expect(edge, contains('prepare_my_marketplace_media_upload'));
    expect(edge, contains('finalize_my_marketplace_media_upload'));
    expect(edge, contains('target_asset_kind: "driver_photo"'));
    expect(edge, contains('MAX_BYTES = 5 * 1024 * 1024'));
    expect(edge, contains('upsert: false'));
  });

  test('profile synchronization does not overwrite custom display name', () {
    final start = recordStore.indexOf('Future<void> _ensureRemoteProfile()');
    final end =
        recordStore.indexOf('Future<void> _applyRemoteChanges', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final ensureProfile = recordStore.substring(start, end);
    expect(ensureProfile, contains("updates['avatar_url']"));
    expect(ensureProfile, contains("updates['email']"));
    expect(ensureProfile, isNot(contains("updates['display_name']")));
  });

  test('UI explains when conductor and vehicle photos are uploaded', () {
    expect(onboarding, contains('Se subirá al pulsar Guardar conductor.'));
    expect(onboarding, contains('Se subirá al pulsar Guardar vehículo.'));
    expect(onboarding, contains('MarketplacePhotoException'));
    expect(onboarding, contains('StorageException'));
  });
  test('Trabajos keeps onboarding mounted while the photo picker returns', () {
    expect(
      jobs,
      contains('if (_loading && _onboarding == null)'),
    );
  });

  test('vehicle onboarding is compact and uses brand/model identity', () {
    expect(onboarding, isNot(contains("label: 'Nombre del vehículo'")));
    expect(
      onboarding,
      isNot(contains("labelText: 'Nombre para identificarlo'")),
    );
    expect(onboarding, contains("const draftName = 'Vehículo nuevo';"));
    expect(
      onboarding,
      contains(r"final vehicleName = '$brand $model'.trim();"),
    );
    expect(
      onboarding,
      contains("'Más datos del vehículo (opcional)'"),
    );
    expect(onboarding, contains('final showPassengerCapacity ='));
    expect(onboarding, contains('final showCargoCapacity ='));
  });
}
