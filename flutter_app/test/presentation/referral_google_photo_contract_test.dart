import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('referidos usa foto Google con alternativa HTML web y avatar neutro', () {
    final screens = File('lib/presentation/screens.dart').readAsStringSync();
    final start = screens.indexOf('class _ReferralEntryTile extends StatelessWidget');
    final end = screens.indexOf('class _ReferralMetric extends StatelessWidget', start);
    expect(start, greaterThan(0));
    expect(end, greaterThan(start));
    final tile = screens.substring(start, end);
    expect(tile, contains('final imageUrl = entry.avatarUrl;'));
    expect(tile, contains('WebHtmlElementStrategy.fallback'));
    expect(tile, contains('errorBuilder: (_, __, ___) => fallbackIcon'));
  });

  test('migracion mantiene contratos del RPC y solo incorpora avatar_url', () {
    final sql = File('supabase/migrations/20261020010000_referral_google_avatar_wallet.sql')
        .readAsStringSync();
    expect(sql, contains('pg_get_functiondef'));
    expect(sql, contains('r.referrer_user_id=actor'));
    expect(sql, contains('v_old_count = 2 and v_existing_count = 1'));
    expect(sql, contains("'''qualified_at'',r.qualified_at,''avatar_url'',p.avatar_url)"));
    expect(sql, isNot(contains('update public.referral_relationships')));
  });
}
