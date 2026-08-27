import 'package:flutter/services.dart';

enum InstallReferrerStatus {
  ok,
  featureNotSupported,
  serviceUnavailable,
  serviceDisconnected,
  platformError,
}

class InstallReferrerResult {
  const InstallReferrerResult({
    required this.status,
    this.installReferrer,
  });

  final InstallReferrerStatus status;
  final String? installReferrer;

  bool get isDefinitive => switch (status) {
        InstallReferrerStatus.ok ||
        InstallReferrerStatus.featureNotSupported ||
        InstallReferrerStatus.platformError =>
          true,
        InstallReferrerStatus.serviceUnavailable ||
        InstallReferrerStatus.serviceDisconnected =>
          false,
      };

  factory InstallReferrerResult.fromMap(Map<dynamic, dynamic> map) {
    final status = switch ('${map['status'] ?? ''}') {
      'ok' => InstallReferrerStatus.ok,
      'feature_not_supported' => InstallReferrerStatus.featureNotSupported,
      'service_unavailable' => InstallReferrerStatus.serviceUnavailable,
      'service_disconnected' => InstallReferrerStatus.serviceDisconnected,
      _ => InstallReferrerStatus.platformError,
    };
    final raw = map['installReferrer']?.toString();
    return InstallReferrerResult(
      status: status,
      installReferrer: raw == null || raw.isEmpty ? null : raw,
    );
  }
}

class AndroidInstallReferrerService {
  const AndroidInstallReferrerService();

  static const _channel = MethodChannel(
    'com.alejandrocruz.tuktukcontrol/referrals',
  );

  Future<InstallReferrerResult> read() async {
    try {
      final response = await _channel.invokeMapMethod<dynamic, dynamic>(
        'getInstallReferrer',
      );
      return InstallReferrerResult.fromMap(response ?? const {});
    } catch (_) {
      return const InstallReferrerResult(
        status: InstallReferrerStatus.platformError,
      );
    }
  }
}
