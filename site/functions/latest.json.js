// install.sh が見るバージョン情報。GitHub API を中継して置き場のURLを出さない。
const API = 'https://api.github.com/repos/yokoyamahayata-cyber/harness-editor-download/releases/latest';

export async function onRequest() {
  const res = await fetch(API, { headers: { 'user-agent': 'harness-editor-download' }, cf: { cacheTtl: 300 } });
  if (!res.ok) return Response.json({ error: 'unavailable' }, { status: 502 });
  const data = await res.json();
  const version = String(data.tag_name ?? '').replace(/^v/, '');
  const names = (data.assets ?? []).map((a) => a.name);
  return Response.json(
    { version, pkg: names.find((n) => n.endsWith('.pkg')) ?? null, zip: names.find((n) => n.endsWith('.zip')) ?? null },
    { headers: { 'cache-control': 'public, max-age=300' } },
  );
}
