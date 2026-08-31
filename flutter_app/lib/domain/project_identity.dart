part of '../main.dart';

class ProjectIdentity {
  const ProjectIdentity({
    required this.projectId,
    required this.name,
    required this.primaryColorHex,
    required this.secondaryColorHex,
    this.logoUrl,
    this.iconUrl,
    this.updatedAt,
  });

  static const fallback = ProjectIdentity(
    projectId: _projectId,
    name: 'TukTuk Control',
    primaryColorHex: '#2DD4A3',
    secondaryColorHex: '#00CFA0',
  );

  final String projectId;
  final String name;
  final String? logoUrl;
  final String? iconUrl;
  final String primaryColorHex;
  final String secondaryColorHex;
  final DateTime? updatedAt;

  static ProjectIdentity? fromRpc(Object? response) {
    Object? row = response;
    if (response is List) {
      if (response.isEmpty) return null;
      row = response.first;
    }
    if (row is! Map) return null;
    return _fromMap(Map<String, dynamic>.from(row));
  }

  static ProjectIdentity? fromCache(Map<String, dynamic> values) =>
      _fromMap(values, fallbackProjectId: _projectId);

  static ProjectIdentity? _fromMap(
    Map<String, dynamic> values, {
    String? fallbackProjectId,
  }) {
    final projectId =
        '${values['project_id'] ?? values['projectId'] ?? fallbackProjectId ?? ''}'
            .trim();
    final name = '${values['name'] ?? ''}'.trim();
    if (projectId.isEmpty || name.isEmpty) return null;

    final rawUpdatedAt = values['updated_at'] ?? values['updatedAt'];
    final updatedText = rawUpdatedAt?.toString().trim();
    final updatedAt = updatedText == null || updatedText.isEmpty
        ? null
        : DateTime.tryParse(updatedText);
    if (updatedText != null && updatedText.isNotEmpty && updatedAt == null) {
      return null;
    }

    return ProjectIdentity(
      projectId: projectId,
      name: name,
      logoUrl: _validHttpsUrl(values['logo_url'] ?? values['logoUrl']),
      iconUrl: _validHttpsUrl(values['icon_url'] ?? values['iconUrl']),
      primaryColorHex: _validColor(
        values['primary_color'] ?? values['primaryColor'],
        fallback.primaryColorHex,
      ),
      secondaryColorHex: _validColor(
        values['secondary_color'] ?? values['secondaryColor'],
        fallback.secondaryColorHex,
      ),
      updatedAt: updatedAt?.toUtc(),
    );
  }

  Map<String, dynamic> toCacheMap() => {
        'projectIdentity:name': name,
        'projectIdentity:logoUrl': logoUrl,
        'projectIdentity:iconUrl': iconUrl,
        'projectIdentity:primaryColor': primaryColorHex,
        'projectIdentity:secondaryColor': secondaryColorHex,
        'projectIdentity:updatedAt': updatedAt?.toIso8601String(),
      };

  static String? _validHttpsUrl(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty
        ? uri.toString()
        : null;
  }

  static String _validColor(Object? value, String fallbackValue) {
    final text = value?.toString().trim().toUpperCase();
    return text != null && RegExp(r'^#[0-9A-F]{6}$').hasMatch(text)
        ? text
        : fallbackValue;
  }
}
