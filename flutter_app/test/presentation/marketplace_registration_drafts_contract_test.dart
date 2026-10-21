import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('onboarding sends incremental drafts without bypassing final validation', () {
    final screen = File('lib/presentation/marketplace_onboarding.dart').readAsStringSync();
    final service = File('lib/data/marketplace_service.dart').readAsStringSync();
    final migration = File(
      'supabase/migrations/20261020230000_marketplace_registration_drafts.sql',
    ).readAsStringSync();
    expect(screen, contains('_queueDraftField('));
    expect(screen, contains('_flushDraftFields()'));
    expect(screen, contains('_registrationErrors()'));
    expect(screen, contains('_service.clearRegistrationDrafts('));
    expect(screen, contains('Documento privado guardado.'));
    expect(service, contains('get_my_marketplace_registration_drafts'));
    expect(service, contains('save_my_marketplace_registration_draft_field'));
    expect(migration, contains('owner_user_id = actor'));
    expect(migration, contains('enable row level security'));
    expect(migration, contains('DRIVER_SUSPENDED'));
  });
}
