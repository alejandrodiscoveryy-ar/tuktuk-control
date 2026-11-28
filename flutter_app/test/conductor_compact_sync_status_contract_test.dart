import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cloud status opens live details and explicit manual sync', () {
    final source = File('lib/presentation/screens.dart').readAsStringSync();
    final start = source.indexOf('Future<void> _showSyncStatus(');
    final end = source.indexOf('void _registrationFinished(', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final sheet = source.substring(start, end);
    expect(sheet, contains('showModalBottomSheet<void>'));
    expect(sheet, contains('animation: store'));
    expect(sheet, contains('store.financialHistoryNotice'));
    expect(sheet, contains('store.lastSyncAt'));
    expect(sheet, contains('store.pendingSyncCount'));
    expect(sheet, contains('store.pendingConflictCount'));
    expect(sheet, contains('busy || store.user == null ? null : store.syncNow'));
    expect(source, contains('onPressed: () => _showSyncStatus(context)'));
  });

  test('home hides routine notice, keeps discrepancies and offline banner', () {
    final source = File('lib/presentation/screens.dart').readAsStringSync();
    expect(source, isNot(contains('if (widget.store.financialHistoryNotice != null)')));
    expect(source, contains('if (widget.store.financialHistoryMismatch)'));
    expect(source, contains('Historial local por conciliar'));
    expect(source, contains('Modo sin conexión'));
    expect(source, isNot(contains('if (store.financialHistoryNotice != null)')));
    expect(source, contains('if (store.financialHistoryMismatch)'));
    expect(RegExp(r'store\.financialHistoryNotice').allMatches(source).length, 1);
  });
}
