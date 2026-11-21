// Test du relais : node relais/worker.test.mjs
import assert from 'node:assert/strict';
import relais from './worker.js';
import { createHash } from 'node:crypto';

class KvMemoire {
  constructor() { this.m = new Map(); }
  async get(k) { return this.m.has(k) ? this.m.get(k) : null; }
  async put(k, v) { this.m.set(k, v); }
  async list({ prefix }) {
    return { keys: [...this.m.keys()].filter((k) => k.startsWith(prefix)).sort().map((name) => ({ name })) };
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

// Limite : 60 par heure.
for (let i = 0; i < 59; i++) await relais.fetch(req('POST', J1, { type: 't', message: 'x' }), env);
assert.equal((await relais.fetch(req('POST', J1, { type: 't', message: 'x' }), env)).status, 429);
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
