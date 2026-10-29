part of '../main.dart';

// Lightweight native-version check; no additional Flutter dependencies.
const _appUpdateNativeChannel = MethodChannel('com.alejandrocruz.tuktukcontrol/version');
const _appUpdateCacheKey = 'tuktuk_android_update_release_v1';
const _appUpdateDismissedKey = 'tuktuk_android_update_dismissed_v1';

@visibleForTesting
enum AppUpdateDecision { none, optional, mandatory }

@visibleForTesting
int compareAppVersions(String left, String right) {
  final pattern = RegExp(r'^\d+(?:\.\d+){1,3}$');
  if (!pattern.hasMatch(left) || !pattern.hasMatch(right)) return 0;
  final a = left.split('.').map(int.parse).toList();
  final b = right.split('.').map(int.parse).toList();
  for (var index = 0; index < 4; index++) {
    final x = index < a.length ? a[index] : 0;
    final y = index < b.length ? b[index] : 0;
    if (x != y) return x.compareTo(y);
  }
  return 0;
}

@visibleForTesting
AppUpdateDecision evaluateAppUpdate({
  required int installedBuild,
  required int latestBuild,
  required String installedVersion,
  required String latestVersion,
  required String minimumVersion,
  required bool forceUpdate,
  required bool hasValidDownloadUrl,
}) {
  if (installedBuild <= 0 || latestBuild <= installedBuild || !hasValidDownloadUrl ||
      !RegExp(r'^\d+(?:\.\d+){1,3}$').hasMatch(latestVersion)) {
    return AppUpdateDecision.none;
  }
  final minimumValid = RegExp(r'^\d+(?:\.\d+){1,3}$').hasMatch(minimumVersion);
  final canEnforce = forceUpdate && minimumValid &&
      compareAppVersions(minimumVersion, installedVersion) > 0 &&
      compareAppVersions(minimumVersion, latestVersion) <= 0;
  return canEnforce ? AppUpdateDecision.mandatory : AppUpdateDecision.optional;
}

class _InstalledAppVersion {
  const _InstalledAppVersion({required this.name, required this.build});
  final String name;
  final int build;
}

class _AppUpdateRelease {
  const _AppUpdateRelease({
    required this.latestVersion,
    required this.latestBuild,
    required this.notes,
    required this.url,
    required this.minimumVersion,
    required this.forceUpdate,
  });

  final String latestVersion;
  final int latestBuild;
  final String notes;
  final Uri url;
  final String minimumVersion;
  final bool forceUpdate;

  static _AppUpdateRelease? parse(Object? data) {
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);
    if (map['enabled'] != true) return null;
    final url = Uri.tryParse('${map['download_url'] ?? ''}');
    if (url == null || url.scheme != 'https' || url.host.isEmpty ||
        url.userInfo.isNotEmpty) {
      return null;
    }
    final build = map['latest_build'];
    final latestBuild = build is num ? build.toInt() : int.tryParse('$build');
    if (latestBuild == null || latestBuild <= 0) {
      return null;
    }
    return _AppUpdateRelease(
      latestVersion: '${map['latest_version'] ?? ''}'.trim(),
      latestBuild: latestBuild,
      notes: '${map['release_notes'] ?? ''}'.trim(),
      url: url,
      minimumVersion: '${map['minimum_version'] ?? ''}'.trim(),
      forceUpdate: map['force_update'] == true,
    );
  }
}

class AppUpdateGate extends StatefulWidget {
  const AppUpdateGate({required this.child, super.key});
  final Widget child;

  @override
  State<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends State<AppUpdateGate>
    with WidgetsBindingObserver {
  _AppUpdateRelease? _release;
  AppUpdateDecision _decision = AppUpdateDecision.none;
  bool _checking = false;
  DateTime? _lastCheck;

  bool get _android => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    if (!_android) return;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_checkForUpdates()));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _android) {
      unawaited(_checkForUpdates());
    }
  }

  @override
  void dispose() {
    if (_android) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool _dismissedRecently(int build) {
    final raw = Hive.box(_metaBox).get(_appUpdateDismissedKey);
    if (raw is! Map || raw['build'] != build) return false;
    final until = DateTime.tryParse('${raw['until'] ?? ''}');
    return until != null && DateTime.now().isBefore(until);
  }

  Future<_InstalledAppVersion?> _installedVersion() async {
    try {
      final raw = await _appUpdateNativeChannel
          .invokeMapMethod<String, dynamic>('getInstalledVersion');
      if (raw == null) return null;
      final version = '${raw['name'] ?? ''}';
      final build = raw['build'];
      if (build is num && build > 0) {
        return _InstalledAppVersion(name: version, build: build.toInt());
      }
    } catch (_) {
      // Missing platform channel: do not show false update warnings.
    }
    return null;
  }

  void _applyRelease(_AppUpdateRelease? release, _InstalledAppVersion installed,
      {required bool fresh}) {
    if (!mounted) return;
    if (release == null) {
      setState(() { _release = null; _decision = AppUpdateDecision.none; });
      return;
    }
    final decision = evaluateAppUpdate(
      installedBuild: installed.build,
      latestBuild: release.latestBuild,
      installedVersion: installed.name,
      latestVersion: release.latestVersion,
      minimumVersion: release.minimumVersion,
      forceUpdate: fresh && release.forceUpdate,
      hasValidDownloadUrl: true,
    );
    setState(() {
      _release = release;
      _decision = decision == AppUpdateDecision.optional &&
              _dismissedRecently(release.latestBuild)
          ? AppUpdateDecision.none : decision;
    });
  }

  Future<void> _checkForUpdates() async {
    if (!_android || !mounted || _checking) return;
    final now = DateTime.now();
    if (_lastCheck != null && now.difference(_lastCheck!) < const Duration(minutes: 15)) return;
    _checking = true;
    _lastCheck = now;
    try {
      final installed = await _installedVersion();
      if (installed == null || !mounted) return;
      try {
        final remote = await Supabase.instance.client.rpc(
          'get_public_app_release',
          params: {'target_project_id': _projectId, 'target_platform': 'android'},
        ).timeout(const Duration(seconds: 7));
        final release = _AppUpdateRelease.parse(remote);
        if (release == null) {
          await Hive.box(_metaBox).delete(_appUpdateCacheKey);
        } else {
          await Hive.box(_metaBox).put(_appUpdateCacheKey, jsonEncode({
            'saved_at': DateTime.now().toUtc().toIso8601String(),
            'release': remote,
          }));
        }
        _applyRelease(release, installed, fresh: true);
      } catch (_) {
        // Offline or API not yet migrated: cached information is optional only.
        final saved = Hive.box(_metaBox).get(_appUpdateCacheKey);
        if (saved is String) {
          try {
            final map = jsonDecode(saved) as Map<String, dynamic>;
            final when = DateTime.tryParse('${map['saved_at'] ?? ''}');
            if (when != null && DateTime.now().difference(when) < const Duration(hours: 24)) {
              _applyRelease(_AppUpdateRelease.parse(map['release']), installed,
                  fresh: false);
              return;
            }
          } catch (_) { /* Ignore malformed legacy cache. */ }
        }
        _applyRelease(null, installed, fresh: false);
      }
    } finally {
      _checking = false;
    }
  }

  Future<void> _openUpdate() async {
    final release = _release;
    if (release == null) return;
    try {
      await launchUrl(release.url, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Android will handle unavailable browser/store without crashing the app.
    }
  }

  Future<void> _postpone() async {
    if (_decision != AppUpdateDecision.optional || _release == null) return;
    await Hive.box(_metaBox).put(_appUpdateDismissedKey, {
      'build': _release!.latestBuild,
      'until': DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
    });
    if (mounted) setState(() => _decision = AppUpdateDecision.none);
  }

  @override
  Widget build(BuildContext context) {
    final isRequired = _decision == AppUpdateDecision.mandatory;
    final visible = _decision != AppUpdateDecision.none && _release != null;
    return PopScope(
      canPop: !isRequired,
      child: Stack(children: [
        widget.child,
        if (visible) ...[
          const Positioned.fill(child: ModalBarrier(dismissible: false, color: Color(0xD9080D14))),
          Positioned.fill(child: SafeArea(child: Center(child: Padding(
            padding: const EdgeInsets.all(20),
            child: Material(
              color: const Color(0xFF111923),
              elevation: 20,
              borderRadius: BorderRadius.circular(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 410),
                child: Padding(padding: const EdgeInsets.all(22), child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.system_update_alt_rounded, color: kPrimary, size: 46),
                    const SizedBox(height: 12),
                    Text(isRequired ? 'Actualización necesaria' : 'Nueva versión disponible',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: kText, fontSize: 21, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text('TukTuk Conductor ${_release!.latestVersion}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: kPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 16),
                    if (_release!.notes.isNotEmpty)
                      Flexible(child: SingleChildScrollView(child: Text(_release!.notes,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: kMuted, fontSize: 14, height: 1.45)))),
                    if (_release!.notes.isEmpty)
                      const Text('Mejoras de estabilidad y experiencia de uso.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: kMuted, fontSize: 14)),
                    if (isRequired) ...[
                      const SizedBox(height: 12),
                      const Text('Para continuar necesitas instalar la versión más reciente.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: kTertiary, fontSize: 12)),
                    ],
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _openUpdate,
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Actualizar ahora'),
                    ),
                    if (!isRequired) ...[
                      const SizedBox(height: 8),
                      TextButton(onPressed: _postpone,
                        child: const Text('Más tarde')),
                    ],
                  ],
                )),
              ),
            ),
          )))),
        ],
      ]),
    );
  }
}
