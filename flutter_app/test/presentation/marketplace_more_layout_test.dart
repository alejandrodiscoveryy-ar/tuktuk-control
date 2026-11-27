import 'package:control_tuk_tuk/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MoreStore extends Fake implements RecordStore {
  @override
  User? get user => null;
}

void main() {
  testWidgets('More menu has equal spacious tiles and larger icons', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: MarketplaceMoreScreen(store: _MoreStore())),
    ));
    final tiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
    expect(tiles, hasLength(5));
    for (final tile in tiles) {
      expect(tile.minTileHeight, 82);
      expect(tile.horizontalTitleGap, 18);
      expect(tile.onTap, isNotNull);
      expect(tile.titleTextStyle?.fontSize, 16);
      expect(tile.titleTextStyle?.fontWeight, FontWeight.w700);
    }
    final cards = tester.widgetList<GlassCard>(find.byType(GlassCard)).toList();
    expect(cards.map((card) => card.accent).toList(), const [
      Color(0xFF2DD4A3), Color(0xFF55A7FF), Color(0xFFFB923C),
      Color(0xFF9A7BFF), Color(0xFFFFB547),
    ]);
    for (final icon in [
      Icons.work_outline_rounded,
      Icons.account_circle_outlined,
      Icons.campaign_outlined,
      Icons.redeem_outlined,
      Icons.support_agent_rounded,
    ]) {
      final finder = find.byIcon(icon);
      expect(finder, findsOneWidget);
      expect(tester.widget<Icon>(finder).size, 34);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('More menu remains scrollable on narrow phones with larger text', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 540));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(size: Size(320, 540),
          textScaler: TextScaler.linear(1.3)),
        child: Scaffold(body: MarketplaceMoreScreen(store: _MoreStore())),
      ),
    ));
    expect(find.text('Conviértete en conductor'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('more-direct-support')), 180,
    );
    expect(find.byKey(const ValueKey('more-direct-support')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
