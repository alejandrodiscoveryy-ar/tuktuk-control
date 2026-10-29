import 'package:flutter_test/flutter_test.dart';
import 'package:control_tuk_tuk/main.dart';

void main() {
  test('no aviso para la compilación actual', () {
    expect(evaluateAppUpdate(
      installedBuild: 22, latestBuild: 22,
      installedVersion: '1.0.20', latestVersion: '1.0.20',
      minimumVersion: '', forceUpdate: true, hasValidDownloadUrl: true,
    ), AppUpdateDecision.none);
  });

  test('aviso opcional al encontrar una nueva build', () {
    expect(evaluateAppUpdate(
      installedBuild: 22, latestBuild: 23,
      installedVersion: '1.0.20', latestVersion: '1.0.21',
      minimumVersion: '', forceUpdate: true, hasValidDownloadUrl: true,
    ), AppUpdateDecision.optional);
  });

  test('obligatoria solo si el mínimo válido supera la versión local', () {
    expect(evaluateAppUpdate(
      installedBuild: 22, latestBuild: 23,
      installedVersion: '1.0.20', latestVersion: '1.0.21',
      minimumVersion: '1.0.21', forceUpdate: true, hasValidDownloadUrl: true,
    ), AppUpdateDecision.mandatory);
  });

  test('mínimo imposible no bloquea usuarios', () {
    expect(evaluateAppUpdate(
      installedBuild: 22, latestBuild: 23,
      installedVersion: '1.0.20', latestVersion: '1.0.21',
      minimumVersion: '9.0.0', forceUpdate: true, hasValidDownloadUrl: true,
    ), AppUpdateDecision.optional);
  });

  test('no propone enlaces de descarga inválidos', () {
    expect(evaluateAppUpdate(
      installedBuild: 22, latestBuild: 23,
      installedVersion: '1.0.20', latestVersion: '1.0.21',
      minimumVersion: '1.0.21', forceUpdate: true, hasValidDownloadUrl: false,
    ), AppUpdateDecision.none);
  });

  test('la comparación numérica distingue 1.0.10 de 1.0.9', () {
    expect(compareAppVersions('1.0.10', '1.0.9'), greaterThan(0));
    expect(compareAppVersions('1.0.20', '1.0.20'), 0);
  });
}
