import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tarjeta asignada extraída se mantiene dentro de la biblioteca Dart', () {
    final main = File('lib/main.dart').readAsStringSync();
    final jobs = File('lib/presentation/marketplace_jobs.dart').readAsStringSync();
    final card = File(
      'lib/presentation/marketplace_assigned_job_card.dart',
    ).readAsStringSync();

    expect(main, contains("part 'presentation/marketplace_jobs.dart';"));
    expect(main, contains("part 'presentation/marketplace_assigned_job_card.dart';"));
    expect(card, startsWith("part of '../main.dart';"));
    expect(card, contains('class _AssignedJobCard extends StatelessWidget'));
    expect(jobs, isNot(contains('class _AssignedJobCard extends StatelessWidget')));
    expect(jobs, contains('_AssignedJobCard('));
    expect(jobs, contains('class _AvailableJobCard extends StatefulWidget'));
  });
}
