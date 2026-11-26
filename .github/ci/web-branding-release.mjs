import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const web = 'flutter_app/web';
const assets = [
  'favicon.png',
  'icons/Icon-192.png',
  'icons/Icon-512.png',
  'icons/Icon-maskable-192.png',
  'icons/Icon-maskable-512.png',
  'icons/Icon-shortcut-192.png',
];
const allowed = new Set([...assets, 'manifest.json'].map(path => join(web, path)));
const manifestPath = join(web, 'manifest.json');
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
const read = path => readFileSync(path);
const git = (...args) => execFileSync('git', args, { encoding: 'utf8' });
const entries = value => value.split('\0').filter(Boolean);

function guardSources() {
  const tracked = entries(git('diff', '--name-only', '-z', 'HEAD'));
  const untracked = entries(git('ls-files', '--others', '--exclude-standard', '-z'));
  const unexpected = [...tracked.filter(path => !allowed.has(path)), ...untracked];
  if (unexpected.length) throw new Error('Unexpected source changes: ' + unexpected.join(', '));
}
function validateManifest(manifest, approved) {
  const normalize = value => ({
    ...value,
    name: approved.name,
    short_name: approved.short_name,
    theme_color: approved.theme_color,
    icons: value.icons.map(icon => ({ ...icon, src: icon.src.split('?')[0] })),
  });
  if (JSON.stringify(normalize(manifest)) !== JSON.stringify(approved)) {
    throw new Error('Unexpected manifest configuration changes');
  }
  if (typeof manifest.name !== 'string' || !manifest.name.trim() ||
      manifest.short_name !== approved.short_name ||
      !/^#[0-9a-f]{6}$/i.test(manifest.theme_color)) {
    throw new Error('Invalid branding metadata');
  }
}
function snapshot() {
  return Object.fromEntries([...allowed].map(path => [path, hash(read(path))]));
}
const [mode, statePath] = process.argv.slice(2);
if (!statePath || !['prepare', 'verify'].includes(mode)) throw new Error('Usage: prepare|verify snapshot-path');
guardSources();
if (mode === 'prepare') {
  const approved = JSON.parse(git('show', 'HEAD:' + manifestPath));
  const manifest = JSON.parse(read(manifestPath));
  validateManifest(manifest, approved);
  for (const icon of manifest.icons) {
    const path = icon.src.split('?')[0];
    if (!assets.includes(path)) throw new Error('Unknown PWA icon: ' + path);
    icon.src = path + '?v=' + hash(read(join(web, path))).slice(0, 16);
  }
  writeFileSync(manifestPath, JSON.stringify(manifest, null, 2) + '\n');
  writeFileSync(statePath, JSON.stringify(snapshot()));
  console.log('BRANDING_ASSETS_VERIFIED=7');
} else {
  const expected = JSON.parse(read(statePath));
  if (JSON.stringify(snapshot()) !== JSON.stringify(expected)) {
    throw new Error('Generated branding changed after validation');
  }
  console.log('BRANDING_ASSETS_UNCHANGED=OK');
}
