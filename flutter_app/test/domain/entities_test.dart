import 'package:control_tuk_tuk/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DailyRecord conserva todos sus campos al serializar', () {
    final createdAt = DateTime.utc(2026, 7, 15, 10, 30);
    final updatedAt = DateTime.utc(2026, 7, 15, 11, 45);
    final record = DailyRecord(
      id: 'record-1',
      date: DateTime(2026, 7, 15),
      earnings: 4250,
      odometer: 4300,
      batteryPercent: 82,
      chargeTo80v: true,
      note: 'Prueba de integridad',
      createdAt: createdAt,
      updatedAt: updatedAt,
      deviceId: 'device-1',
    );

    final restored = DailyRecord.fromMap(record.toMap());

    expect(restored.id, record.id);
    expect(restored.date, record.date);
    expect(restored.earnings, record.earnings);
    expect(restored.odometer, record.odometer);
    expect(restored.batteryPercent, record.batteryPercent);
    expect(restored.chargeTo80v, isTrue);
    expect(restored.note, record.note);
    expect(restored.createdAt, createdAt);
    expect(restored.updatedAt, updatedAt);
    expect(restored.deviceId, record.deviceId);
    expect(restored.isDeleted, isFalse);
  });

  test('MaintenanceRecord conserva el borrado lógico', () {
    final deletedAt = DateTime.utc(2026, 7, 15, 12);
    final record = MaintenanceRecord(
      id: 'maintenance-1',
      dateTime: DateTime.utc(2026, 3, 14, 9),
      odometer: 526,
      type: 'General',
      description: 'Mantenimiento general',
      cost: 15000,
      deletedAt: deletedAt,
      deviceId: 'device-1',
    );

    final restored = MaintenanceRecord.fromMap(record.toMap());

    expect(restored.id, record.id);
    expect(restored.deletedAt, deletedAt);
    expect(restored.isDeleted, isTrue);
    expect(restored.cost, 15000);
  });
}
