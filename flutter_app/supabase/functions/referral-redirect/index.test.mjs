import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { stripTypeScriptTypes } from 'node:module';
import vm from 'node:vm';
import test from 'node:test';

// Execute the unchanged deployed handler. Only the type-only runtime import is
// removed for Node; Deno.serve is intercepted rather than opening a server.
const source = await readFile(new URL('./index.ts', import.meta.url), 'utf8');
let handler;
vm.runInNewContext(stripTypeScriptTypes(source.replace(
  'import "jsr:@supabase/functions-js/edge-runtime.d.ts";', '')),
  { URL, Response, Deno: { serve: (value) => { handler = value; } } });

const unescape = (value) => value.replaceAll('&amp;', '&').replaceAll('&quot;', '"')
  .replaceAll('&#39;', "'").replaceAll('&lt;', '<').replaceAll('&gt;', '>');

for (const [query, code] of [
  ['ref=TUK-QC59', 'TUK-QC59'], ['ref=tuk-qc59', 'TUK-QC59'],
  ['ref=PEDRO-7K4P', 'PEDRO-7K4P'], ['ref=ABC_123', 'ABC_123'],
  ['utm_source=whatsapp&ref=TUK%2DQC59&extra=value', 'TUK-QC59'],
  ['ref=%20TUK-QC59%20', 'TUK-QC59'], ['ref=%22%3E%3Cscript%3E', null],
  ['ref=', null], ['', null], ['ref=AB', null], ['ref=' + 'A'.repeat(65), null],
]) {
  test(`redirect ${query || '(absent)'}`, async () => {
    const request = new Request('https://example.com/?' + query);
    const response = handler(request);
    assert.equal(response.status, 200);
    assert.equal(response.headers.get('cache-control'), 'no-store, max-age=0');
    const html = await response.text();
    const links = [...html.matchAll(/href="([^"]+)"/g)].map((m) => unescape(m[1]));
    const [intent, play, app] = links;
    assert.equal(new URL(app).searchParams.get('ref'), code);
    assert.equal(new URL(play).searchParams.get('id'), 'com.alejandrocruz.tuktukcontrol');
    assert.equal(new URL(play).searchParams.get('referrer'), code ? `ref=${code}` : null);
    assert.equal(decodeURIComponent(intent.match(/S.browser_fallback_url=([^;]+);/)[1]), play);
    assert.equal(new URL(intent.split('#')[0]).searchParams.get('ref'), code);
    const script = html.match(/<script>([\s\S]*?)<\/script>/)[1];
    for (const userAgent of ['Android Chrome', 'Windows Chrome']) {
      const element = {href: intent};
      vm.runInNewContext(script, {navigator: {userAgent}, document: {getElementById: () => element}});
      assert.equal(element.href, userAgent.includes('Android') ? intent : app);
    }
  });
}
