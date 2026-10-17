import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('identity documents have private bucket and owner-scoped RPC', () {
    final sql = File(
            'supabase/migrations/20261017180000_driver_identity_documents_private.sql')
        .readAsStringSync();
    expect(sql, contains("'marketplace-identity'"));
    expect(sql, contains('owner_user_id = actor'));
    expect(sql, contains('identity_docs_required=false or'));
    expect(
        sql, contains('alter column identity_docs_required set default true'));
    expect(sql, contains('from public, anon'));
    expect(sql, contains('to authenticated'));
  });
  test('front and back upload exposed only in driver onboarding', () {
    final ui =
        File('lib/presentation/marketplace_onboarding.dart').readAsStringSync();
    final service =
        File('lib/data/marketplace_service.dart').readAsStringSync();
    expect(ui, contains("_identityDocumentTile('front'"));
    expect(ui, contains("_identityDocumentTile('back'"));
    expect(ui, contains('documents[\'required\'] == true'));
    expect(service, contains("'prepare_my_marketplace_identity_upload'"));
    expect(service, contains("from('marketplace-identity')"));
  });
}
