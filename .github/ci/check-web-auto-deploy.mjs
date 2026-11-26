import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const deploy = readFileSync('.github/workflows/deploy-web-production.yml', 'utf8');
const android = readFileSync('.github/workflows/flutter-android.yml', 'utf8');

test('solo push a main o workflow_dispatch confirmado en main', () => {
  assert.match(deploy, /^on:\r?\n  push:\r?\n    branches: \[main\]\r?\n  workflow_dispatch:/m);
  assert.match(deploy, /github\.ref == 'refs\/heads\/main' && \(github\.event_name == 'push' \|\| \(github\.event_name == 'workflow_dispatch' && inputs\.confirm_production == true\)\)/);
});

test('push a main requiere PR fusionado y permisos minimos', () => {
  assert.match(deploy, /^  pull-requests: read$/m);
  assert.match(deploy, /if: \$\{\{ github\.event_name == 'push' \}\}/);
  assert.match(deploy, /GH_TOKEN: \$\{\{ github\.token \}\}/);
  assert.match(deploy, /commits\/\$\{GITHUB_SHA\}\/pulls/);
  assert.match(deploy, /pr\.merged_at/);
  assert.match(deploy, /pr\.base\?\.ref === 'main'/);
  assert.match(deploy, /pr\.merge_commit_sha === process\.env\.GITHUB_SHA/);
  assert.match(deploy, /AUTO_DEPLOY_REJECTED/);
});

test('no se publica codigo superado y se comprueba el artefacto web', () => {
  const beforeUpload = deploy.indexOf('- name: Reject stale main commit before upload');
  const upload = deploy.indexOf('- name: Upload exact build to existing Worker');
  const beforeActivation = deploy.indexOf('- name: Reject stale main commit before activation');
  const activate = deploy.indexOf('- name: Promote uploaded version to 100 percent');
  assert.ok(beforeUpload >= 0 && beforeUpload < upload);
  assert.ok(beforeActivation >= 0 && beforeActivation < activate);
  assert.match(deploy, /PRODUCTION_INTEGRITY=OK/);
  assert.match(deploy, /flutter test/);
  assert.match(deploy, /CLOUDFLARE_API_TOKEN/);
  assert.doesNotMatch(deploy, /flutter build (?:apk|appbundle)/);
});

test('Android solo se inicia manualmente o mediante solicitud expresa de version', () => {
  const triggers = android.match(/^on:\r?\n([\s\S]*?)^permissions:/m)?.[1];
  assert.ok(triggers, 'Sección de disparadores Android');
  assert.match(triggers, /^  workflow_dispatch:$/m);
  const push = triggers.match(/^  push:\r?\n((?:^ {4,}.*\r?\n)+)/m)?.[1];
  assert.ok(push, 'Disparador de solicitud de versión');
  assert.match(push, /^    branches: \[main\]\r?\n    paths:\r?\n      - 'flutter_app\/tool\/android_release_request\.txt'\r?\n$/);
  assert.doesNotMatch(triggers, /^  pull_request:$/m);
  assert.deepEqual([...triggers.matchAll(/^  (\w+):$/gm)].map(m => m[1]).sort(),
    ['push', 'workflow_dispatch']);
  assert.match(android, /EXPECTED_VERSION_CODE="\$\(head -n 1 tool\/android_release_request\.txt\)"/);
  assert.match(android, /test "\$VERSION_CODE" = "\$EXPECTED_VERSION_CODE"/);
});
