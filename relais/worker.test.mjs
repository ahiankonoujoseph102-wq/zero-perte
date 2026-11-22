// Test du relais : node relais/worker.test.mjs
import assert from 'node:assert/strict';
import relais from './worker.js';
import { createHash } from 'node:crypto';

class KvMemoire {
  constructor() { this.m = new Map(); this.listes = 0; this.lectures = 0; }
  async get(k) { this.lectures++; return this.m.has(k) ? this.m.get(k) : null; }
  async put(k, v) { this.m.set(k, v); }
  // Comme Cloudflare : pages de « limit » clés, avec un curseur.
  async list({ prefix, limit = 1000, cursor }) {
    this.listes++;
    const toutes = [...this.m.keys()].filter((k) => k.startsWith(prefix)).sort();
    const debut = cursor ? parseInt(cursor, 10) : 0;
    const keys = toutes.slice(debut, debut + limit).map((name) => ({ name }));
    const fini = debut + limit >= toutes.length;
    return fini ? { keys, list_complete: true } : { keys, list_complete: false, cursor: String(debut + limit) };
  }
}
const env = { ALERTES: new KvMemoire() };
const J1 = 'jeton-boutique-un-0123456789';
const J2 = 'jeton-boutique-deux-0123456789';
const req = (methode, jeton, corps, chemin = '/alertes') =>
  new Request('https://relais.exemple' + chemin, {
    method: methode,
    headers: jeton ? { authorization: 'Bearer ' + jeton } : {},
    body: corps ? JSON.stringify(corps) : undefined,
  });

let r = await relais.fetch(req('POST', J1, { type: 'ecart', message: 'Il manque 2 000 F', appareil: 'B' }), env);
assert.equal(r.status, 201);
r = await relais.fetch(req('GET', J1), env);
let d = await r.json();
assert.equal(d.alertes.length, 1);
assert.equal(d.alertes[0].message, 'Il manque 2 000 F');

// Une autre boutique ne voit rien.
d = await (await relais.fetch(req('GET', J2), env)).json();
assert.equal(d.alertes.length, 0);

// Sans jeton : refusé. Le jeton en clair n'est jamais stocké.
assert.equal((await relais.fetch(req('GET', null), env)).status, 401);
assert.ok([...env.ALERTES.m.keys()].every((k) => !k.includes(J1)));

// « depuis » : seulement les nouvelles.
const t = d.alertes[0]?.heure ?? Date.now();
d = await (await relais.fetch(req('GET', J1, null, '/alertes?depuis=' + Date.now()), env)).json();
assert.equal(d.alertes.length, 0);

// « Dernière alerte » : sans nouveauté, une seule lecture et AUCUNE liste.
{
  const listes = env.ALERTES.listes;
  const lectures = env.ALERTES.lectures;
  const vide = await (await relais.fetch(req('GET', J1, null, '/alertes?depuis=' + Date.now()), env)).json();
  assert.equal(vide.alertes.length, 0);
  assert.equal(env.ALERTES.listes, listes);
  assert.equal(env.ALERTES.lectures, lectures + 1);
  // Boutique sans aucune alerte : pareil.
  await relais.fetch(req('GET', J2), env);
  assert.equal(env.ALERTES.listes, listes);
}

// Limite : 60 par heure.
for (let i = 0; i < 59; i++) await relais.fetch(req('POST', J1, { type: 't', message: 'x' }), env);
assert.equal((await relais.fetch(req('POST', J1, { type: 't', message: 'x' }), env)).status, 429);

// Plus de 100 alertes : la plus récente n'est jamais perdue (pages suivies).
{
  const env3 = { ALERTES: new KvMemoire() };
  const heureOrigine = Date.now;
  let h = 1_800_000_000_000;
  Date.now = () => (h += 3_600_000); // une alerte par heure : pas de limite
  for (let i = 0; i < 150; i++) {
    assert.equal((await relais.fetch(req('POST', J1, { type: 't', message: 'n' + i }), env3)).status, 201);
  }
  Date.now = heureOrigine;
  const tout = await (await relais.fetch(req('GET', J1), env3)).json();
  assert.equal(tout.alertes.length, 150);
  assert.equal(tout.alertes.at(-1).message, 'n149');
}
// Notification Firebase : appel du jeton Google puis de FCM, sur le bon canal.
{
  const { generateKeyPairSync } = await import('node:crypto');
  const { privateKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
  const pem = privateKey.export({ type: 'pkcs8', format: 'pem' });
  const appels = [];
  const fetchOrigine = globalThis.fetch;
  globalThis.fetch = async (url, init) => {
    appels.push({ url: String(url), corps: init.body });
    if (String(url).includes('oauth2')) return new Response(JSON.stringify({ access_token: 'jeton-google' }));
    return new Response('{}');
  };
  const env2 = {
    ALERTES: new KvMemoire(),
    FCM_COMPTE: JSON.stringify({ client_email: 'relais@projet.iam.gserviceaccount.com', private_key: pem, project_id: 'zero-perte-test' }),
  };
  const attentes = [];
  const ctx = { waitUntil: (p) => attentes.push(p) };
  const r2 = await relais.fetch(req('POST', J2, { type: 'ecart', message: 'Il manque 1 500 F' }), env2, ctx);
  assert.equal(r2.status, 201);
  await Promise.all(attentes);
  globalThis.fetch = fetchOrigine;
  assert.equal(appels.length, 2);
  assert.ok(appels[0].url.startsWith('https://oauth2.googleapis.com/token'));
  const fcm = JSON.parse(appels[1].corps);
  assert.ok(appels[1].url.includes('/projects/zero-perte-test/messages:send'));
  const attendu = 'zp-' + createHash('sha256').update(J2).digest('hex').slice(0, 32);
  assert.equal(fcm.message.topic, attendu);
  assert.equal(fcm.message.notification.body, 'Il manque 1 500 F');
}
console.log('relais : tous les tests réussis');
