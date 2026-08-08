part of '../main.dart';

class SyncCoordinator {
  const SyncCoordinator({
    required SyncQueueRepository queue,
    required RemoteSyncGateway gateway,
  })  : _queue = queue,
        _gateway = gateway;

  final SyncQueueRepository _queue;
  final RemoteSyncGateway _gateway;

  Future<SyncRunReport> pushPending({
    required String userId,
    int batchSize = 50,
  }) async {
    if (!_gateway.isConfigured) {
      return const SyncRunReport(
        attempted: 0,
        completed: 0,
        failed: 0,
        skippedBecauseUnconfigured: true,
      );
    }
    final pending = _queue.pendingForUser(userId, limit: batchSize);
    if (pending.isEmpty) {
      return const SyncRunReport(attempted: 0, completed: 0, failed: 0);
    }

    try {
      final result = await _gateway.push(pending);
      final acceptedOperations = pending.where(
        (operation) => result.acceptedOperationIds.contains(operation.id),
      );
      final completedIds =
          await _queue.completeIfUnchanged(acceptedOperations);
      for (final rejection in result.rejectedOperations.entries) {
        await _queue.markFailed([rejection.key], rejection.value);
      }
      return SyncRunReport(
        attempted: pending.length,
        completed: completedIds.length,
        failed: result.rejectedOperations.length,
        completedOperationIds: completedIds,
      );
    } on LicenseWriteRejectedException {
      final blockedIds = pending.map((operation) => operation.id).toSet();
      await _queue.complete(blockedIds);
      return SyncRunReport(
        attempted: pending.length,
        completed: 0,
        failed: pending.length,
        blockedByLicense: true,
        blockedOperationIds: blockedIds,
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
