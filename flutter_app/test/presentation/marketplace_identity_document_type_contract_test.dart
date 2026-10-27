import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('new drivers choose a document and supply both sides', () {
    final screen = File('lib/presentation/marketplace_onboarding.dart')
        .readAsStringSync();
    expect(screen, contains("issues['identityType']"));
    expect(screen, contains('_identityTypeRequired'));
    expect(screen, contains("documents['document_type_required']"));
    expect(screen, contains("_identityPhotoValid('front')"));
    expect(screen, contains("_identityPhotoValid('back')"));
    expect(screen, contains('ChoiceChip('));
    expect(screen, contains("'national_id', 'driver_license'"));
    expect(screen, contains("_queueDraftField('identity_document_type', kind)"));
    expect(screen, contains('documentType: _identityDocumentType'));
  });

  test('document type is private, persisted and v1 remains available', () {
    final service = File('lib/data/marketplace_service.dart')
        .readAsStringSync();
    final sql = File(
      'supabase/migrations/20261027020000_marketplace_identity_document_type.sql',
    ).readAsStringSync();
    expect(service, contains('save_my_marketplace_identity_documents_v2'));
    expect(service, contains('save_my_marketplace_identity_documents'));
    expect(service, contains('save_my_marketplace_identity_document_type_draft'));
    expect(sql, contains('identity_document_type text'));
    expect(sql, contains('identity_document_type_required boolean'));
    expect(sql, contains('set identity_document_type_required = false'));
    expect(sql, contains('identity_document_type_required = false or'));
    expect(sql, contains('DOCUMENT_PHOTOS_MUST_BE_REPLACED'));
    expect(sql, contains("d.identity_document_type in ('national_id', 'driver_license')"));
    expect(sql, contains('IDENTITY_DOCUMENT_BOTH_SIDES_REQUIRED'));
    expect(sql, contains('actor uuid := auth.uid()'));
    expect(sql, contains('revoke all on function'));
    expect(sql, contains('to authenticated'));
  });
}
