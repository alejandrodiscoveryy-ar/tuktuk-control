import 'package:control_tuk_tuk/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const projectId = 'dfb41cea-a812-46f2-b511-7a60bd3d78af';

  Map<String, dynamic> remoteSettings({
    bool supportEnabled = true,
    bool paymentEnabled = true,
    String supportNumber = '+5355511111',
    String paymentNumber = '+5355522222',
  }) =>
      {
        'project_id': projectId,
        'application': 'TukTuk Control',
        'support': {
          'enabled': supportEnabled,
          'number': supportNumber,
          'button_text': 'Atención al cliente',
          'template':
              'Hola, necesito ayuda con {{aplicacion}}. Mi nombre es {{nombre}} y mi correo es {{correo}}.',
        },
        'payment': {
          'enabled': paymentEnabled,
          'number': paymentNumber,
          'button_text': 'Pagar, activar o renovar',
          'template':
              'Hola, deseo {{tipo_solicitud}} en {{aplicacion}}. Nombre: {{nombre}}. Correo: {{correo}}. Licencia: {{licencia}}. Plan actual: {{plan_actual}}. Plan solicitado: {{plan_solicitado}}. Vencimiento: {{fecha_vencimiento}}.',
        },
        'version': 3,
        'updated_at': '2026-08-08T20:02:13Z',
      };

  test('usa canales, números, etiquetas y plantillas remotas separados', () {
    final settings = WhatsAppSettings.tryFromMap(remoteSettings())!;
    final variables = {
      'customer_name': 'Pedro Alejandro Cruz',
      'customer_email': 'pedro@example.com',
      'license_key': 'TUK-123',
      'current_plan': 'personal',
      'requested_plan': 'propietario',
      'expires_at': '2026-09-01',
      'contact_reason': 'renovar',
    };

    final support = buildWhatsAppContactAction(
      settings: settings,
      channel: WhatsAppChannel.support,
      variables: variables,
    )!;
    final payment = buildWhatsAppContactAction(
      settings: settings,
      channel: WhatsAppChannel.payment,
      variables: variables,
    )!;

    expect(support.buttonText, 'Atención al cliente');
    expect(support.uri.path, '/5355511111');
    expect(support.uri.queryParameters['text'], contains('pedro@example.com'));
    expect(payment.buttonText, 'Pagar, activar o renovar');
    expect(payment.uri.path, '/5355522222');
    expect(payment.uri.queryParameters['text'], contains('TUK-123'));
    expect(payment.uri.queryParameters['text'], contains('propietario'));
    expect(payment.uri.toString(), isNot(contains(' ')));
  });

  test('elimina cláusulas con datos ausentes y nunca muestra placeholders', () {
    final settings = WhatsAppSettings.tryFromMap(remoteSettings())!;
    final action = buildWhatsAppContactAction(
      settings: settings,
      channel: WhatsAppChannel.payment,
      variables: const {
        'customer_name': 'Ana',
        'customer_email': 'ana@example.com',
        'current_plan': 'trial',
        'contact_reason': 'activar',
      },
    )!;
    final message = action.uri.queryParameters['text']!;

    expect(message, isNot(contains('{{')));
    expect(message, isNot(contains('Licencia:')));
    expect(message, isNot(contains('Plan solicitado:')));
    expect(message, isNot(contains('Vencimiento:')));
    expect(message, contains('Ana'));
  });

  test('no crea acciones para canales deshabilitados', () {
    final settings = WhatsAppSettings.tryFromMap(
      remoteSettings(supportEnabled: false, paymentEnabled: false),
    )!;

    expect(
      buildWhatsAppContactAction(
        settings: settings,
        channel: WhatsAppChannel.support,
        variables: const {'customer_name': 'Ana'},
      ),
      isNull,
    );
    expect(
      buildWhatsAppContactAction(
        settings: settings,
        channel: WhatsAppChannel.payment,
        variables: const {'customer_name': 'Ana'},
      ),
      isNull,
    );
  });

  test(
    'actualiza desde remoto y conserva la última configuración offline',
    () async {
      final cache = _MemoryWhatsAppSettingsCache();
      final online = WhatsAppSettingsService(
        projectId: projectId,
        cache: cache,
        loadRemote: (_) async => remoteSettings(),
      );
      final fetched = await online.refresh();

      expect(fetched.version, 3);
      expect(fetched.support.number, '+5355511111');

      final offline = WhatsAppSettingsService(
        projectId: projectId,
        cache: cache,
        loadRemote: (_) => Future.error(Exception('offline')),
      );
      final restored = offline.cachedSettings();
      final refreshedOffline = await offline.refresh();

      expect(restored.version, 3);
      expect(refreshedOffline.payment.number, '+5355522222');
    },
  );

  test('un remoto inválido no reemplaza la caché válida', () async {
    final cache = _MemoryWhatsAppSettingsCache();
    final online = WhatsAppSettingsService(
      projectId: projectId,
      cache: cache,
      loadRemote: (_) async => remoteSettings(),
    );
    await online.refresh();
    final invalid = WhatsAppSettingsService(
      projectId: projectId,
      cache: cache,
      loadRemote: (_) async => {'project_id': projectId},
    );

    expect((await invalid.refresh()).version, 3);
  });
}

class _MemoryWhatsAppSettingsCache implements WhatsAppSettingsCache {
  final Map<String, Object> values = {};

  @override
  Object? read(String key) => values[key];

  @override
  Future<void> write(String key, Object value) async {
    values[key] = value;
  }
}
