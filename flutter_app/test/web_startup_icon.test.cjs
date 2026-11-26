const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const { runInNewContext } = require('node:vm');
const assert = require('node:assert/strict');
const test = require('node:test');

const html = readFileSync(join(__dirname, '../web/index.html'), 'utf8');
const script = html.match(/<script>\s*([\s\S]*?)<\/script>/)[1];
const key = 'tuktuk-conductor:startup-icon:v1:/tuktuk/app/';
const original = 'icons/Icon-192.png';
const png = 'data:image/png;base64,iVBORw0KGgo=';
const a = 'https://example.com/icon-a.png';
const b = 'https://example.com/icon-b.png';

function boot(storage = new Map(), bundledIcon = original) {
  const logo = { src: bundledIcon, getAttribute: () => bundledIcon };
  const note = {};
  const images = [];
  const timers = [];
  const window = {};
  let removed = false;
  const splash = {
    querySelector: (selector) => selector === 'img' ? logo : note,
    classList: { add() {} },
    remove() { removed = true; }
  };
  runInNewContext(script, {
    window,
    URL,
    location: { pathname: '/tuktuk/app/' },
    localStorage: {
      getItem: k => storage.get(k) ?? null,
      setItem: (k, v) => storage.set(k, v),
      removeItem: k => storage.delete(k)
    },
    document: {
      getElementById: () => splash,
      createElement: () => ({
        getContext: () => ({ drawImage() {} }),
        toDataURL: () => png
      })
    },
    Image: class {
      constructor() {
        this.naturalWidth = this.naturalHeight = 1024;
        images.push(this);
      }
    },
    requestAnimationFrame: fn => fn(),
    setTimeout: (fn, delay) => timers.push({ fn, delay })
  });
  return {
    logo, images, storage, window,
    flush: delay => {
      const pending = timers.filter(t => t.delay === delay);
      for (const timer of pending) {
        timers.splice(timers.indexOf(timer), 1);
        timer.fn();
      }
    },
    removed: () => removed
  };
}

test('first launch shows the built-in icon and never waits for identity', () => {
  const app = boot();
  assert.equal(app.logo.src, original);
  assert.equal(app.images.length, 0);
  app.window.tuktukApplyStartupIcon(a);
  assert.equal(app.logo.src, original);
  app.window.tuktukFinishStartup();
  app.flush(240);
  assert.equal(app.removed(), true);
  app.images[0].onload();
  app.flush(0);
  assert.equal(app.logo.src, original);
  assert.equal(JSON.parse(app.storage.get(key)).url, a);
});

test('configured image loads and survives a subsequent offline startup', () => {
  const app = boot();
  app.window.tuktukApplyStartupIcon(a);
  app.images[0].onload();
  app.flush(0);
  assert.equal(app.logo.src, a);
  assert.deepEqual(JSON.parse(app.storage.get(key)), { url: a, snapshot: png });
  const offline = boot(app.storage);
  assert.equal(offline.logo.src, png);
  offline.window.tuktukApplyStartupIcon(a);
  assert.equal(offline.images.length, 0);
});

test('new image replaces cached icon; failed image keeps last good image', () => {
  const storage = new Map([[key, JSON.stringify({ url: a, snapshot: png })]]);
  const app = boot(storage);
  app.window.tuktukApplyStartupIcon(b);
  app.images[0].onerror();
  app.images[1].onerror();
  assert.equal(app.logo.src, png);
  assert.equal(JSON.parse(storage.get(key)).url, a);
  app.window.tuktukApplyStartupIcon(b);
  app.images[2].onload();
  app.flush(0);
  assert.equal(app.logo.src, b);
  assert.equal(JSON.parse(storage.get(key)).url, b);
});

test('outdated request cannot overwrite newer or explicitly cleared identity', () => {
  const app = boot();
  app.window.tuktukApplyStartupIcon(a);
  app.window.tuktukApplyStartupIcon(b);
  app.images[1].onload();
  app.images[0].onload();
  app.flush(0);
  assert.equal(app.logo.src, b);
  assert.equal(JSON.parse(app.storage.get(key)).url, b);
  app.window.tuktukApplyStartupIcon('');
  assert.equal(app.logo.src, original);
  assert.equal(app.storage.has(key), false);
});

test('invalid URL never triggers a request', () => {
  const app = boot();
  app.window.tuktukApplyStartupIcon('http://example.com/insecure.png');
  assert.equal(app.images.length, 0);
  assert.equal(app.logo.src, original);
});

test('new bundled icon revision does not show the previous cached startup logo', () => {
  const storage = new Map([[key, JSON.stringify({ url: a, snapshot: png })]]);
  const newIcon = original + '?v=1234567890abcdef';
  const app = boot(storage, newIcon);
  assert.equal(app.logo.src, newIcon);
  assert.equal(app.images.length, 0);
});
