part of '../main.dart';

class SyncCoordinator {
  const SyncCoordinator({
    required SyncQueueRepository queue,
    required RemoteSyncGateway gateway,
  })  : _queue = queue,
        _gateway = gateway;

  final SyncQueueRepository _queue;
  final RemoteSyncGateway _gateway;

  /// Envia varios lotes en una misma sincronizacion, con limite de trabajo
  /// para no bloquear la UI ni agotar bateria con colas excepcionalmente largas.
  /// Los cambios no enviados permanecen en la cola persistente para continuar.
  Future<SyncRunReport> pushPendingBatches({
    required String userId,
    int batchSize = 500,
    int maxBatches = 4,
    Set<String> excludedOperationIds = const <String>{},
    required Future<void> Function(List<SyncOperation>) onCompletedBatch,
  }) async {
    if (batchSize < 1 || maxBatches < 1) {
      throw ArgumentError('El tamaño y el número de lotes deben ser positivos.');
    }
    var attempted = 0;
    var completed = 0;
    var failed = 0;
    var skipped = false;
    final completedOperationIds = <String>{};

    for (var batch = 0; batch < maxBatches; batch++) {
      final pending = _queue.pendingForUser(
        userId,
        limit: batchSize,
        excludedOperationIds: excludedOperationIds,
      );
      if (pending.isEmpty) break;

      final report = await pushPending(
        userId: userId,
        batchSize: batchSize,
        excludedOperationIds: excludedOperationIds,
      );
      attempted += report.attempted;
      completed += report.completed;
      failed += report.failed;
      skipped = skipped || report.skippedBecauseUnconfigured;
      completedOperationIds.addAll(report.completedOperationIds);

      final accepted = pending.where(
        (operation) => report.completedOperationIds.contains(operation.id),
      ).toList();
      if (accepted.isNotEmpty) await onCompletedBatch(accepted);

      // Nunca insistir en bucle sobre un fallo o una respuesta sin progreso.
      if (report.failed > 0 ||
          report.skippedBecauseUnconfigured ||
          report.completed == 0) {
        break;
      }
    }

    return SyncRunReport(
      attempted: attempted,
      completed: completed,
      failed: failed,
      completedOperationIds: completedOperationIds,
      skippedBecauseUnconfigured: skipped,
      pendingRemaining: _queue.pendingForUser(userId, limit: 1).isNotEmpty,
      sendablePendingRemaining: _queue.pendingForUser(
        userId,
        limit: 1,
        excludedOperationIds: excludedOperationIds,
      ).isNotEmpty,
    );
  }

  Future<SyncRunReport> pushPending({
    required String userId,
    int batchSize = 50,
    Set<String> excludedOperationIds = const <String>{},
  }) async {
    if (!_gateway.isConfigured) {
      return const SyncRunReport(
        attempted: 0,
        completed: 0,
        failed: 0,
        skippedBecauseUnconfigured: true,
      );
    }
    final pending = _queue.pendingForUser(
      userId,
      limit: batchSize,
      excludedOperationIds: excludedOperationIds,
    );
    if (pending.isEmpty) {
      return const SyncRunReport(attempted: 0, completed: 0, failed: 0);
    }

    try {
      final result = await _gateway.push(pending);
      final acceptedOperations = pending.where(
        (operation) => result.acceptedOperationIds.contains(operation.id),
      );
      final completedIds = await _queue.completeIfUnchanged(acceptedOperations);
      for (final rejection in result.rejectedOperations.entries) {
        await _queue.markFailed([rejection.key], rejection.value);
      }
      return SyncRunReport(
        attempted: pending.length,
        completed: completedIds.length,
        failed: result.rejectedOperations.length,
        completedOperationIds: completedIds,
      );
    } catch (error) {
      await _queue.markFailed(
        pending.map((operation) => operation.id),
        '$error',
      );
      return SyncRunReport(
        attempted: pending.length,
        completed: 0,
        failed: pending.length,
      );
    }
  }
}
