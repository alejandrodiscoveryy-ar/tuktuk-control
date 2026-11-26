import test from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';

const script = fileURLToPath(new URL('./web-branding-release.mjs', import.meta.url));
const assets = ['favicon.png', 'icons/Icon-192.png', 'icons/Icon-512.png',
  'icons/Icon-maskable-192.png', 'icons/Icon-maskable-512.png', 'icons/Icon-shortcut-192.png'];

function fixture(t) {
  const dir = mkdtempSync(join(tmpdir(), 'tuktuk-branding-'));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  const cwd = join(dir, 'repo');
  mkdirSync(cwd);
  const git = (...args) => execFileSync('git', args, { cwd, stdio: 'ignore' });
  git('init');
  git('config', 'user.name', 'Test');
  git('config', 'user.email', 'test@example.com');
  const web = join(cwd, 'flutter_app/web');
  function write(path, data) {
    const dest = join(web, path);
    mkdirSync(dirname(dest), { recursive: true });
    writeFileSync(dest, data);
  }
  for (const asset of assets) write(asset, 'original ' + asset);
  const manifest = {
    name: 'TukTuk Conductor', short_name: 'TukTuk Conductor',
    start_url: './', scope: './', display: 'standalone',
    theme_color: '#06B6D4',
    icons: assets.slice(1, 5).map(src => ({ src, type: 'image/png' }))
  };
  write('manifest.json', JSON.stringify(manifest));
  write('index.html', '<base href="$FLUTTER_BASE_HREF"><img src="icons/Icon-192.png" alt="">');
  write('other.js', 'approved');
  git('add', '.');
  git('commit', '-m', 'approved');
  const run = mode => spawnSync(process.execPath, [script, mode, join(dir, 'snapshot.json')],
    { cwd, encoding: 'utf8' });
  const read = path => readFileSync(join(web, path), 'utf8');
  return { manifest, write, read, run };
}

test('release versions generated assets and rejects later mutation', t => {
  const f = fixture(t);
  f.write('icons/Icon-192.png', 'updated icon');
  const result = f.run('prepare');
  assert.equal(result.status, 0, result.stderr);
  const manifest = JSON.parse(f.read('manifest.json'));
  const digest = createHash('sha256').update('updated icon').digest('hex').slice(0, 16);
  assert.equal(manifest.icons[0].src, 'icons/Icon-192.png?v=' + digest);
  assert.ok(f.read('index.html').includes('src="icons/Icon-192.png?v=' + digest + '"'));
  assert.equal(f.run('verify').status, 0);
  f.write('icons/Icon-192.png', 'modified after validation');
  assert.notEqual(f.run('verify').status, 0);
});

test('release rejects unauthorized source changes', t => {
  const f = fixture(t);
  f.write('other.js', 'unapproved');
  assert.notEqual(f.run('prepare').status, 0);
});

test('release rejects unauthorized executable HTML changes', t => {
  const f = fixture(t);
  f.write('index.html', f.read('index.html') + '<script>unexpected()</script>');
  assert.notEqual(f.run('prepare').status, 0);
});

test('release rejects manifest scope and start URL changes', t => {
  const f = fixture(t);
  f.write('manifest.json', JSON.stringify({ ...f.manifest, start_url: '/other/' }));
  assert.notEqual(f.run('prepare').status, 0);
});
