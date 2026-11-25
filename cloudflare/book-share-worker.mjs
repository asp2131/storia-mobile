const canonicalOrigin = 'https://app.loratone.com';

const escapeHtml = (value) => String(value).replace(/[&<>"']/g, (char) => ({
  '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
})[char]);

function bookMetadata(book, bookId) {
  const title = `${book.title} | Loratone`;
  const description = `Read ${book.title}${book.author ? ` by ${book.author}` : ''} on Loratone. Explore stories with immersive music and soundscapes. No account needed to read this story.`;
  const url = `${canonicalOrigin}/book/${bookId}`;
  const meta = (name, value, property = false) =>
    `<meta ${property ? 'property' : 'name'}="${name}" content="${escapeHtml(value)}">`;
  const tags = [
    `<title>${escapeHtml(title)}</title>`,
    `<link rel="canonical" href="${url}">`,
    meta('description', description),
    meta('og:type', 'book', true),
    meta('og:site_name', 'Loratone', true),
    meta('og:title', title, true),
    meta('og:description', description, true),
    meta('og:url', url, true),
    meta('twitter:title', title),
    meta('twitter:description', description),
  ];
  // Only absolute public HTTP(S) covers are useful to social preview crawlers.
  let cover;
  try {
    const parsed = new URL(book.cover_url);
    if (['https:', 'http:'].includes(parsed.protocol)) cover = parsed.href;
  } catch { /* A story without a cover can still be shared. */ }
  tags.push(meta('twitter:card', cover ? 'summary_large_image' : 'summary'));
  if (cover) {
    tags.push(meta('og:image', cover, true), meta('og:image:alt', book.title, true));
    tags.push(meta('twitter:image', cover));
  }
  return tags.join('\n');
}

/// Uses only the same public anon credentials as Flutter. RLS still applies.
/// No session cookies, Authorization headers, or profile data are forwarded.
export function createBookShareWorker(config, fetchMetadata = fetch) {
  return {
    async fetch(request, env) {
      const url = new URL(request.url);
      if (!url.pathname.startsWith('/book/')) return env.ASSETS.fetch(request);
      if (!['GET', 'HEAD'].includes(request.method)) {
        return new Response(null, { status: 405, headers: { Allow: 'GET, HEAD' } });
      }
      const match = /^\/book\/([0-9]+)\/?$/.exec(url.pathname);
      if (match && url.pathname.endsWith('/')) {
        url.pathname = url.pathname.slice(0, -1);
        return Response.redirect(url.href, 308);
      }
      const shell = await env.ASSETS.fetch(new URL('/index.html', url));
      if (!shell.ok) return shell;
      let status = 404;
      let metadata = '<title>Story unavailable | Loratone</title><meta name="robots" content="noindex">';
      if (match) {
        try {
          const endpoint = new URL('/rest/v1/books', config.supabaseUrl);
          endpoint.search = new URLSearchParams({
            select: 'id,title,author,cover_url',
            id: `eq.${match[1]}`,
            is_published: 'eq.true',
            limit: '1',
          }).toString();
          const result = await fetchMetadata(endpoint, {
            headers: {
              apikey: config.supabaseAnonKey,
              Authorization: `Bearer ${config.supabaseAnonKey}`,
            },
            signal: AbortSignal.timeout(5000),
          });
          if (!result.ok) throw new Error('Catalog unavailable');
          const books = await result.json();
          if (!Array.isArray(books)) throw new Error('Invalid catalog response');
          if (books[0]?.title && String(books[0].id) === match[1]) {
            metadata = bookMetadata(books[0], match[1]);
            status = 200;
          }
        } catch {
          // Still serve Flutter so visitors can retry reading if previews fail.
          status = 503;
          metadata = '<title>Loratone — stories with sound</title><meta name="robots" content="noindex">';
          console.warn(JSON.stringify({ event: 'book_preview_unavailable', bookId: match[1] }));
        }
      }
      const html = (await shell.text())
        .replace(/<title>[\s\S]*?<\/title>/i, '')
        .replace('</head>', `${metadata}\n</head>`);
      return new Response(request.method === 'HEAD' ? null : html, {
        status,
        headers: {
          'Content-Type': 'text/html; charset=utf-8',
          // Recheck publication on every request; no stale preview for drafts.
          'Cache-Control': 'no-store',
          ...(status === 503 ? { 'Retry-After': '30' } : {}),
        },
      });
    },
  };
}
