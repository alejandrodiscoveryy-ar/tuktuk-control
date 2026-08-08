part of '../main.dart';

enum WhatsAppChannel { support, payment }

class WhatsAppChannelSettings {
  const WhatsAppChannelSettings({
    required this.enabled,
    required this.number,
    required this.buttonText,
    required this.template,
  });

  final bool enabled;
  final String? number;
  final String buttonText;
  final String template;

  bool get isUsable =>
      enabled &&
      number != null &&
      RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(number!) &&
      buttonText.trim().isNotEmpty &&
      template.trim().isNotEmpty;

  Map<String, dynamic> toMap() => {
        'enabled': enabled,
        'number': number,
        'button_text': buttonText,
        'template': template,
      };

  static WhatsAppChannelSettings? tryFromMap(Object? raw) {
    if (raw is! Map) return null;
    final number = raw['number']?.toString().trim();
    final value = WhatsAppChannelSettings(
      enabled: raw['enabled'] == true,
      number: number == null || number.isEmpty ? null : number,
      buttonText: '${raw['button_text'] ?? ''}'.trim(),
      template: '${raw['template'] ?? ''}'.trim(),
    );
    if (value.buttonText.isEmpty || value.template.isEmpty) return null;
    if (value.number != null &&
        !RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(value.number!)) {
      return null;
    }
    return value;
  }
}

class WhatsAppSettings {
  const WhatsAppSettings({
    required this.projectId,
    required this.applicationName,
    required this.support,
    required this.payment,
    required this.version,
    this.updatedAt,
  });

  final String projectId;
  final String applicationName;
  final WhatsAppChannelSettings support;
  final WhatsAppChannelSettings payment;
  final int version;
  final DateTime? updatedAt;

  static const unavailable = WhatsAppSettings(
    projectId: '',
    applicationName: 'TukTuk Control',
    support: WhatsAppChannelSettings(
      enabled: false,
      number: null,
      buttonText: '',
      template: '',
    ),
    payment: WhatsAppChannelSettings(
      enabled: false,
      number: null,
      buttonText: '',
      template: '',
    ),
    version: 0,
  );

  WhatsAppChannelSettings channel(WhatsAppChannel value) =>
      value == WhatsAppChannel.support ? support : payment;

  Map<String, dynamic> toMap() => {
        'project_id': projectId,
        'application': applicationName,
        'support': support.toMap(),
        'payment': payment.toMap(),
        'version': version,
        'updated_at': updatedAt?.toIso8601String(),
      };

  static WhatsAppSettings? tryFromMap(Object? raw) {
    if (raw is! Map) return null;
    final projectId = '${raw['project_id'] ?? ''}'.trim();
    final application = '${raw['application'] ?? ''}'.trim();
    final support = WhatsAppChannelSettings.tryFromMap(raw['support']);
    final payment = WhatsAppChannelSettings.tryFromMap(raw['payment']);
    final version = (raw['version'] as num?)?.toInt();
    if (projectId.isEmpty ||
        application.isEmpty ||
        support == null ||
        payment == null ||
        version == null ||
        version < 1) {
      return null;
    }
    return WhatsAppSettings(
      projectId: projectId,
      applicationName: application,
      support: support,
      payment: payment,
      version: version,
      updatedAt: DateTime.tryParse('${raw['updated_at'] ?? ''}')?.toUtc(),
    );
  }
}

class WhatsAppContactAction {
  const WhatsAppContactAction({required this.buttonText, required this.uri});

  final String buttonText;
  final Uri uri;
}

abstract interface class WhatsAppSettingsCache {
  Object? read(String key);
  Future<void> write(String key, Object value);
}

class HiveWhatsAppSettingsCache implements WhatsAppSettingsCache {
  const HiveWhatsAppSettingsCache(this.box);

  final Box box;

  @override
  Object? read(String key) => box.get(key);

  @override
  Future<void> write(String key, Object value) => box.put(key, value);
}

typedef WhatsAppSettingsRemoteLoader = Future<Object?> Function(
    String projectId);

class WhatsAppSettingsService {
  WhatsAppSettingsService({
    required this.projectId,
    required WhatsAppSettingsCache cache,
    required WhatsAppSettingsRemoteLoader loadRemote,
  })  : _cache = cache,
        _loadRemote = loadRemote;

  static const _cachePrefix = 'publicWhatsAppSettings:';

  final String projectId;
  final WhatsAppSettingsCache _cache;
  final WhatsAppSettingsRemoteLoader _loadRemote;

  String get _cacheKey => '$_cachePrefix$projectId';

  WhatsAppSettings cachedSettings() {
    final cached = WhatsAppSettings.tryFromMap(_cache.read(_cacheKey));
    return cached?.projectId == projectId
        ? cached!
        : WhatsAppSettings.unavailable;
  }

  Future<WhatsAppSettings> refresh() async {
    final cached = cachedSettings();
    try {
      final remote = WhatsAppSettings.tryFromMap(await _loadRemote(projectId));
      if (remote == null || remote.projectId != projectId) return cached;
      await _cache.write(_cacheKey, remote.toMap());
      return remote;
    } catch (_) {
      return cached;
    }
  }
}

WhatsAppContactAction? buildWhatsAppContactAction({
  required WhatsAppSettings settings,
  required WhatsAppChannel channel,
  required Map<String, String?> variables,
}) {
  final config = settings.channel(channel);
  if (!config.isUsable) return null;
  final aliases = <String, String?>{
    'nombre': variables['customer_name'],
    'customer_name': variables['customer_name'],
    'correo': variables['customer_email'],
    'customer_email': variables['customer_email'],
    'licencia': variables['license_key'],
    'license_key': variables['license_key'],
    'aplicacion': variables['application_name'] ?? settings.applicationName,
    'application_name':
        variables['application_name'] ?? settings.applicationName,
    'plan_actual': variables['current_plan'],
    'current_plan': variables['current_plan'],
    'plan_solicitado': variables['requested_plan'],
    'requested_plan': variables['requested_plan'],
    'fecha_vencimiento': variables['expires_at'],
    'expires_at': variables['expires_at'],
    'tipo_solicitud': variables['contact_reason'],
    'contact_reason': variables['contact_reason'],
  };
  final message = renderWhatsAppTemplate(config.template, aliases);
  if (message.isEmpty) return null;
  final digits = config.number!.substring(1);
  return WhatsAppContactAction(
    buttonText: config.buttonText,
    uri: Uri.https('wa.me', '/$digits', {'text': message}),
  );
}

String renderWhatsAppTemplate(String template, Map<String, String?> variables) {
  final placeholder = RegExp(r'\{\{([a-z_]+)\}\}');
  final clauses =
      template.trim().split(RegExp(r'(?<=[.!?])\s+|\n+')).where((clause) {
    final matches = placeholder.allMatches(clause);
    return matches.every((match) {
      final value = variables[match.group(1)]?.trim();
      return value != null && value.isNotEmpty;
    });
  }).map((clause) {
    return clause.replaceAllMapped(
      placeholder,
      (match) => variables[match.group(1)]?.trim() ?? '',
    );
  }).join(' ');
  return clauses
      .replaceAll(placeholder, '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAllMapped(
        RegExp(r'\s+([,.;:!?])'),
        (match) => match.group(1)!,
      )
      .trim();
}
