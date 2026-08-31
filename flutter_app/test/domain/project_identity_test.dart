import 'package:control_tuk_tuk/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const projectId = 'dfb41cea-a812-46f2-b511-7a60bd3d78af';

  test('parsea una respuesta RPC válida', () {
    final identity = ProjectIdentity.fromRpc([
      {
        'project_id': projectId,
        'name': 'TukTuk Dinámico',
        'logo_url': 'https://cdn.example.com/logo.png',
        'icon_url': 'https://cdn.example.com/icon.png',
        'primary_color': '#12ABEF',
        'secondary_color': '#123456',
        'updated_at': '2026-08-30T12:00:00Z',
      }
    ]);

    expect(identity, isNotNull);
    expect(identity!.name, 'TukTuk Dinámico');
    expect(identity.logoUrl, 'https://cdn.example.com/logo.png');
    expect(identity.iconUrl, 'https://cdn.example.com/icon.png');
    expect(identity.primaryColorHex, '#12ABEF');
    expect(identity.updatedAt, DateTime.utc(2026, 8, 30, 12));
  });

  test('respuesta ausente conserva un fallback local utilizable', () {
    expect(ProjectIdentity.fromRpc(null), isNull);
    expect(ProjectIdentity.fallback.name, 'TukTuk Control');
    expect(ProjectIdentity.fallback.logoUrl, isNull);
    expect(ProjectIdentity.fallback.iconUrl, isNull);
  });

  test('URLs vacías o no HTTPS se descartan', () {
    final identity = ProjectIdentity.fromRpc({
      'project_id': projectId,
      'name': 'TukTuk Control',
      'logo_url': '',
      'icon_url': 'http://inseguro.example.com/icon.png',
      'primary_color': '#2DD4A3',
      'secondary_color': '#00CFA0',
    });

    expect(identity, isNotNull);
    expect(identity!.logoUrl, isNull);
    expect(identity.iconUrl, isNull);
  });

  test('colores inválidos usan los colores fallback', () {
    final identity = ProjectIdentity.fromRpc({
      'project_id': projectId,
      'name': 'TukTuk Control',
      'primary_color': 'verde',
      'secondary_color': '#12345',
    });

    expect(identity!.primaryColorHex, ProjectIdentity.fallback.primaryColorHex);
    expect(
      identity.secondaryColorHex,
      ProjectIdentity.fallback.secondaryColorHex,
    );
  });

  test('restaura valores válidos desde el formato de caché', () {
    final original = ProjectIdentity.fromRpc({
      'project_id': projectId,
      'name': 'Identidad cacheada',
      'logo_url': 'https://cdn.example.com/logo.png',
      'icon_url': 'https://cdn.example.com/icon.png',
      'primary_color': '#ABCDEF',
      'secondary_color': '#FEDCBA',
      'updated_at': '2026-08-30T12:00:00Z',
    })!;

    final restored = ProjectIdentity.fromCache({
      'name': original.toCacheMap()['projectIdentity:name'],
      'logoUrl': original.toCacheMap()['projectIdentity:logoUrl'],
      'iconUrl': original.toCacheMap()['projectIdentity:iconUrl'],
      'primaryColor': original.toCacheMap()['projectIdentity:primaryColor'],
      'secondaryColor': original.toCacheMap()['projectIdentity:secondaryColor'],
      'updatedAt': original.toCacheMap()['projectIdentity:updatedAt'],
    });

    expect(restored, isNotNull);
    expect(restored!.name, original.name);
    expect(restored.logoUrl, original.logoUrl);
    expect(restored.iconUrl, original.iconUrl);
    expect(restored.primaryColorHex, original.primaryColorHex);
    expect(restored.secondaryColorHex, original.secondaryColorHex);
    expect(restored.updatedAt, original.updatedAt);
  });

  test('updated_at inválido rechaza la respuesta remota', () {
    expect(
      ProjectIdentity.fromRpc({
        'project_id': projectId,
        'name': 'TukTuk Control',
        'updated_at': 'fecha-inválida',
      }),
      isNull,
    );
  });
}
