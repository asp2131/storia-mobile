import { readFile, writeFile } from 'node:fs/promises';

const root = new URL('../', import.meta.url);
// Read the built public asset, never the server-only .env file.
const clientEnv = await readFile(new URL('build/web/assets/.env.client', root), 'utf8');
function setting(name) {
  const line = clientEnv.split(/\r?\n/).find((line) => line.trim().startsWith(`${name}=`));
  const value = line?.trim().slice(name.length + 1).trim().replace(/^(['"])(.*)\1$/, '$2');
  if (!value) throw new Error(`Missing public client setting: ${name}`);
  return value;
}
const config = {
  supabaseUrl: setting('SUPABASE_URL'),
  supabaseAnonKey: setting('SUPABASE_ANON_KEY'),
};
if (new URL(config.supabaseUrl).protocol !== 'https:') {
  throw new Error('SUPABASE_URL must use HTTPS');
}
const source = await readFile(new URL('cloudflare/book-share-worker.mjs', root), 'utf8');
await writeFile(
  new URL('build/web/_worker.js', root),
  `${source}\nexport default createBookShareWorker(${JSON.stringify(config)});\n`,
);
await writeFile(
  new URL('build/web/_routes.json', root),
  await readFile(new URL('web/_routes.json', root)),
);
console.log('Prepared Cloudflare book previews using public client configuration.');
