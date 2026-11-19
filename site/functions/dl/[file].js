// 配布ファイルの中継。閲覧者には /dl/<ファイル名> だけが見え、置き場のURLは出さない。
// 途中で切れたときに再開できるよう Range もそのまま通す。
const TAG = 'v0.8.5';
const ORIGIN = 'https://github.com/yokoyamahayata-cyber/harness-editor-download/releases/download';
const ALLOW = /^Harness-Editor-\d+\.\d+\.\d+-mac-apple-silicon\.(pkg|zip)$/;

export async function onRequest({ params, request }) {
  const file = params.file;
  if (!ALLOW.test(file)) return new Response('not found', { status: 404 });

  const headers = new Headers();
  const range = request.headers.get('range');
  if (range) headers.set('range', range);

  const upstream = await fetch(`${ORIGIN}/${TAG}/${file}`, {
    method: request.method === 'HEAD' ? 'HEAD' : 'GET',
    headers,
    redirect: 'follow',
  });
  if (!upstream.ok && upstream.status !== 206) {
    return new Response('配布ファイルを取得できませんでした', { status: 502 });
  }

  const out = new Headers();
  out.set('content-type', 'application/octet-stream');
  out.set('content-disposition', `attachment; filename="${file}"`);
  out.set('accept-ranges', 'bytes');
  out.set('cache-control', 'public, max-age=3600');
  for (const key of ['content-length', 'content-range', 'etag', 'last-modified']) {
    const value = upstream.headers.get(key);
    if (value) out.set(key, value);
  }
  return new Response(upstream.body, { status: upstream.status, headers: out });
}
