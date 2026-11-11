part of '../main.dart';

class _AssignedJobCard extends StatelessWidget {
  const _AssignedJobCard({
    required this.job,
    required this.scope,
    required this.busy,
    required this.showMap,
    this.cancellationDetail,
    this.onContact,
    this.onAdvance,
    this.onCancel,
    this.onRating,
  });

  final MarketplaceJob job;
  final String scope;
  final bool busy;
  final bool showMap;
  final MarketplaceJobCancellationDetail? cancellationDetail;
  final VoidCallback? onContact;
  final VoidCallback? onAdvance;
  final VoidCallback? onCancel;
  final VoidCallback? onRating;

  @override
  Widget build(BuildContext context) {
    final origin =
        job.originText?.trim().isNotEmpty == true ? job.originText! : 'Origen';

    final destination = job.destinationText?.trim().isNotEmpty == true
        ? job.destinationText!
        : 'Destino';

    final cancelled = job.status == 'cancelled_by_driver' ||
        job.status == 'cancelled_by_customer';

    final completed = job.status == 'completed' || job.status == 'settled';

    final executing = job.status == 'accepted' ||
        job.status == 'en_route' ||
        job.status == 'pickup' ||
        job.status == 'in_progress';

    final statusColor = scope == 'scheduled'
        ? Colors.blue
        : cancelled
            ? kDanger
            : completed
                ? Colors.green
                : executing
                    ? Colors.orange
                    : _marketplaceJobStatusColor(context, job.status);

    final statusLabel = cancelled
        ? cancellationDetail?.cancelledBy == 'customer'
            ? 'Cancelado por el cliente'
            : cancellationDetail?.cancelledBy == 'driver'
                ? 'Cancelado por el conductor'
                : _marketplaceJobStatusLabel(job.status)
        : _marketplaceJobStatusLabel(job.status);

    final lastEvent = cancellationDetail?.cancelledAt ??
        job.completedAt ??
        job.cancelledAt ??
        job.acceptedAt ??
        job.updatedAt ??
        job.createdAt;

    final progressIndex = _marketplaceJobProgressIndex(job.status);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  _marketplaceJobServiceLabel(job.serviceCode),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _marketplaceMoneyLabel(job.finalPrice, job.currency),
                style: TextStyle(
                  color: appPrimaryColor(context),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: statusColor.withValues(alpha: .60),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: .18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _marketplaceJobStatusIcon(job.status),
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _marketplaceJobStatusMessage(job.status),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (onAdvance != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: busy ? null : onAdvance,
                icon: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(_marketplaceJobStatusIcon(job.status)),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text(
                    _marketplaceJobCanFinish(job)
                        ? 'Finalizar carrera'
                        : (_marketplaceJobActionLabel(job.nextAction) ??
                            'Continuar'),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ),
          ],
          if (onContact != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: busy ? null : onContact,
                icon: const Icon(Icons.contact_phone_rounded),
                label: const Text(
                  'Contactar cliente',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
          if (scope != 'history' && job.status != 'incident') ...[
            const SizedBox(height: 14),
            Row(
              children: List.generate(2, (index) {
                const labels = ['En camino', 'Finalizado'];

                final active = progressIndex >= index;

                return Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: active
                              ? statusColor
                              : appMutedColor(context).withValues(alpha: .15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          active ? Icons.check_rounded : Icons.circle_outlined,
                          size: 14,
                          color: active ? Colors.white : appMutedColor(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        labels[index],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight:
                              active ? FontWeight.w800 : FontWeight.w500,
                          color: active ? statusColor : appMutedColor(context),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.trip_origin_rounded, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(origin)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_outlined, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(destination)),
            ],
          ),
          if (showMap &&
              job.status != 'completed' &&
              job.originPoint != null &&
              job.destinationPoint != null) ...[
            const SizedBox(height: 14),
            SizedBox(height: 265, child: MarketplaceDriverMap(job: job)),
          ],
          if (job.scheduledFor != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.event_outlined, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Programado: ${_marketplaceJobDateLabel(job.scheduledFor)}',
                  ),
                ),
              ],
            ),
          ],
          if (job.passengerCount != null) ...[
            const SizedBox(height: 8),
            Text('${job.passengerCount} pasajero(s)'),
          ],
          if (job.cargoWeightKg != null) ...[
            const SizedBox(height: 8),
            Text('Carga: ${job.cargoWeightKg!.toStringAsFixed(0)} kg'),
          ],
          const SizedBox(height: 12),
          Text(
            _marketplaceJobBillingLabel(job),
            style: TextStyle(
              color: appMutedColor(context),
              fontWeight: FontWeight.w700,
            ),
          ),
          if (cancelled) ...[
            const SizedBox(height: 10),
            Text(
              cancellationDetail?.cancellationReason?.trim().isNotEmpty == true
                  ? 'Motivo: ${cancellationDetail!.cancellationReason}'
                  : 'Motivo no disponible',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            if (cancellationDetail?.cancelledAt != null) ...[
              const SizedBox(height: 4),
              Text(
                'Fecha: ${_marketplaceJobDateLabel(cancellationDetail!.cancelledAt)}',
                style: TextStyle(color: appMutedColor(context), fontSize: 12),
              ),
            ],
          ] else if (lastEvent != null) ...[
            const SizedBox(height: 6),
            Text(
              'Actualizado: ${_marketplaceJobDateLabel(lastEvent)}',
              style: TextStyle(color: appMutedColor(context), fontSize: 12),
            ),
          ],
          if (job.incidentReason?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: kTertiary,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text('Incidencia: ${job.incidentReason}')),
              ],
            ),
          ],
          if (onCancel != null) ...[
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: busy ? null : onCancel,
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Cancelar'),
                ),
              ],
            ),
          ],
          if (onRating != null) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: busy ? null : onRating,
              icon: const Icon(Icons.star_outline_rounded),
              label: const Text('Valorar cliente'),
            ),
          ],
        ],
      ),
    );
  }
}

