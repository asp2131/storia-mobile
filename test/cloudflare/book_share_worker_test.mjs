import assert from 'node:assert/strict';
import { test } from 'node:test';
import { createBookShareWorker } from '../../cloudflare/book-share-worker.mjs';

const config = { supabaseUrl: 'https://catalog.example.com', supabaseAnonKey: 'public-anon' };
const shell = '<html><head><base href="/"><title>Loratone</title></head><body><script src="flutter_bootstrap.js"></script></body></html>';
const assets = { ASSETS: { fetch: async () => new Response(shell) } };
const book = { id: 68, title: 'The Harbor', author: 'A. Writer', cover_url: 'https://images.example.com/68.jpg' };

test('published book returns crawlable metadata and Flutter on both hosts', async () => {
  for (const host of ['app.loratone.com', '53e3f17e.loratone-app.pages.dev']) {
    const worker = createBookShareWorker(config, async (url, options) => {
      assert.equal(url.searchParams.get('id'), 'eq.68');
      assert.equal(url.searchParams.get('is_published'), 'eq.true');
      assert.equal(url.searchParams.get('select'), 'id,title,author,cover_url');
      assert.equal(options.headers.Authorization, 'Bearer public-anon');
      assert.equal(options.headers.Cookie, undefined);
      return Response.json([book]);
    });
    const response = await worker.fetch(new Request(`https://${host}/book/68?utm_source=reddit`, {
      headers: { Cookie: 'private-session=secret', Authorization: 'Bearer private-user' },
    }), assets);
    assert.equal(response.status, 200);
    const html = await response.text();
    assert.match(html, /property="og:title" content="The Harbor \| Loratone"/);
    assert.match(html, /property="og:image" content="https:\/\/images.example.com\/68.jpg"/);
    assert.match(html, /href="https:\/\/app.loratone.com\/book\/68"/);
    assert.match(html, /name="twitter:card" content="summary_large_image"/);
    assert.match(html, /flutter_bootstrap.js/);
    assert.equal((html.match(/<title>/g) || []).length, 1);
    assert.equal(response.headers.get('Cache-Control'), 'no-store');
  }
});

test('drafts and unknown books return 404 without title/cover data', async () => {
  const worker = createBookShareWorker(config, async () => Response.json([]));
  const response = await worker.fetch(new Request('https://app.loratone.com/book/69'), assets);
  assert.equal(response.status, 404);
  const html = await response.text();
  assert.match(html, /noindex/);
  assert.doesNotMatch(html, /og:image/);
  assert.match(html, /flutter_bootstrap.js/);
});

test('invalid identifiers never query the database', async () => {
  const worker = createBookShareWorker(config, () => assert.fail('unexpected metadata query'));
  for (const path of ['/book/draft', '/book/68/extra', '/book/68%27or%271']) {
    const response = await worker.fetch(new Request(`https://app.loratone.com${path}`), assets);
    assert.equal(response.status, 404);
  }
});

test('escapes titles/authors/covers and rejects executable cover URLs', async () => {
  const worker = createBookShareWorker(config, async () => Response.json([{
    ...book, title: '<script>alert("x")</script>', author: '" onload="evil', cover_url: 'javascript:alert(1)',
  }]));
  const response = await worker.fetch(new Request('https://app.loratone.com/book/68'), assets);
  const html = await response.text();
  assert.match(html, /&lt;script&gt;/);
  assert.doesNotMatch(html, /<script>alert/);
  assert.doesNotMatch(html, /javascript:|og:image/);
});

test('upstream failure returns retryable HTML without caching an error preview', async () => {
  const worker = createBookShareWorker(config, async () => new Response('down', { status: 503 }));
  const response = await worker.fetch(new Request('https://app.loratone.com/book/68'), assets);
  assert.equal(response.status, 503);
  assert.equal(response.headers.get('Retry-After'), '30');
  assert.match(await response.text(), /flutter_bootstrap.js/);
});

test('HEAD, unsupported methods, trailing slash and normal assets', async () => {
  const worker = createBookShareWorker(config, async () => Response.json([book]));
  const head = await worker.fetch(new Request('https://app.loratone.com/book/68', { method: 'HEAD' }), assets);
  assert.equal(head.status, 200);
  assert.equal(await head.text(), '');
  const post = await worker.fetch(new Request('https://app.loratone.com/book/68', { method: 'POST' }), assets);
  assert.equal(post.status, 405);
  const slash = await worker.fetch(new Request('https://app.loratone.com/book/68/?ref=discord'), assets);
  assert.equal(slash.status, 308);
  assert.equal(slash.headers.get('Location'), 'https://app.loratone.com/book/68?ref=discord');
  const asset = await worker.fetch(new Request('https://app.loratone.com/flutter_bootstrap.js'), assets);
  assert.equal(await asset.text(), shell);
});
