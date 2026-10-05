import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String migration;

  setUpAll(() {
    migration = File(
      'supabase/migrations/'
      '20261005093553_tuktuk_2_0_driver_topups_api.sql',
    ).readAsStringSync();
  });

  test('driver payment methods expose only active TUKTUK methods', () {
    expect(
      migration,
      contains(
        'create or replace function '
        'public.list_my_marketplace_payment_methods()',
      ),
    );
    expect(migration, contains("and p.slug='tuktuk-control'"));
    expect(migration, contains('where m.active'));
    expect(migration, contains('to authenticated'));
  });

  test('driver topup history is restricted to the authenticated actor', () {
    expect(
      migration,
      contains('create or replace function public.list_my_marketplace_topups('),
    );
    expect(migration, contains('actor uuid:=auth.uid()'));
    expect(migration, contains('where t.user_id=actor'));
    expect(migration, contains('INVALID_PAGINATION_CURSOR'));
    expect(migration, contains('order by t.requested_at desc,t.id desc'));
  });

  test('Step 2C read API does not confirm, reject or mutate topups', () {
    expect(migration, isNot(contains('admin_confirm_marketplace_topup(')));
    expect(migration, isNot(contains('admin_reject_marketplace_topup(')));
    expect(migration, isNot(contains('update public.topups')));
    expect(migration, isNot(contains('insert into public.topups')));
    expect(
      migration,
      isNot(contains('insert into public.wallet_transactions')),
    );
  });
}
