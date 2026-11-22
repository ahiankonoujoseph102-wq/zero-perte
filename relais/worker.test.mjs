// Test du relais : node relais/worker.test.mjs
import assert from 'node:assert/strict';
import relais from './worker.js';
import { createHash } from 'node:crypto';

class KvMemoire {
  constructor() { this.m = new Map(); this.listes = 0; this.lectures = 0; }
  async get(k) { this.lectures++; return this.m.has(k) ? this.m.get(k) : null; }
  async put(k, v) { this.m.set(k, v); this.ecritures = (this.ecritures || 0) + 1; }
  async delete(k) { this.m.delete(k); }
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
  assert.equal(fcm.message.notification.title, 'Zéro Perte : alerte');
}

// --- Ajout d'un vendeur (0.35) ---------------------------------------------
{
  const appelsGoogle = [];
  const fetchOrigine = globalThis.fetch;
  const RT = 'jeton-long-du-vendeur-1';
  globalThis.fetch = async (url, init) => {
    const corps = Object.fromEntries(new URLSearchParams(init.body));
    appelsGoogle.push({ url: String(url), corps });
    if (String(url).includes('/revoke')) return new Response('{}');
    if (corps.grant_type === 'authorization_code') {
      if (corps.code !== 'code-ok') return new Response(JSON.stringify({ error: 'invalid_grant' }), { status: 400 });
      return new Response(JSON.stringify({ refresh_token: RT, access_token: 'a1' }));
    }
    if (corps.refresh_token === RT) return new Response(JSON.stringify({ access_token: 'acces-1h', expires_in: 3599 }));
    return new Response(JSON.stringify({ error: 'invalid_grant' }), { status: 400 });
  };
  const envG = { ALERTES: new KvMemoire(), GOOGLE_WEB_ID: 'id-web.apps.googleusercontent.com', GOOGLE_WEB_SECRET: 'secret-web' };
  const post = (chemin, corps, jeton = J1) => relais.fetch(req('POST', jeton, corps, chemin), envG);

  // Sans les 2 secrets : « non configuré », rien n'est tenté.
  assert.equal((await relais.fetch(req('GET', null, null, '/google/id'), { ALERTES: new KvMemoire() })).status, 503);
  // L'identifiant (public) est donné ; le code secret, JAMAIS.
  let rep = await relais.fetch(req('GET', null, null, '/google/id'), envG);
  const texteId = await rep.text();
  assert.equal(JSON.parse(texteId).id, 'id-web.apps.googleusercontent.com');
  assert.ok(!texteId.includes('secret-web'));

  // Échange : jeton de la boutique obligatoire ; mauvais code refusé.
  assert.equal((await post('/google/echange', { code: 'code-ok' }, null)).status, 401);
  assert.equal((await post('/google/echange', { code: 'faux' })).status, 400);
  rep = await post('/google/echange', { code: 'code-ok' });
  assert.equal(rep.status, 200);
  assert.equal((await rep.json()).jeton_long, RT);
  const echange = appelsGoogle.find((a) => a.corps.code === 'code-ok');
  assert.equal(echange.corps.client_secret, 'secret-web');
  assert.equal(echange.corps.redirect_uri, '');
  // Le relais n'a rien gardé du jeton long.
  assert.ok([...envG.ALERTES.m.values()].every((v) => !String(v).includes(RT)));

  // Accès d'une heure pour le vendeur.
  rep = await post('/google/acces', { jeton_long: RT }, null);
  assert.equal(rep.status, 200);
  assert.equal((await rep.json()).acces, 'acces-1h');
  // Jeton inconnu ou annulé chez Google : refusé (403).
  assert.equal((await post('/google/acces', { jeton_long: 'autre' }, null)).status, 403);

  // Retirer UN appareil : par l'empreinte ; ensuite plus aucun accès.
  const emp = createHash('sha256').update(RT).digest('hex');
  assert.equal((await post('/google/retirer', { empreinte: emp }, null)).status, 401);
  assert.equal((await post('/google/retirer', { empreinte: 'pas-une-empreinte' })).status, 400);
  assert.equal((await post('/google/retirer', { empreinte: emp })).status, 200);
  const avant = appelsGoogle.length;
  assert.equal((await post('/google/acces', { jeton_long: RT }, null)).status, 403);
  assert.equal(appelsGoogle.length, avant, 'appareil retiré : Google n\'est même pas appelé');
  assert.ok(!envG.ALERTES.m.has('x:' + RT));

  // Couper tous les vendeurs : échange puis annulation chez Google.
  rep = await post('/google/couper', { code: 'code-ok' });
  assert.equal(rep.status, 200);
  const annulation = appelsGoogle.at(-1);
  assert.ok(annulation.url.endsWith('/revoke'));
  assert.equal(annulation.corps.token, RT);

  // Boîte aux lettres : 10 minutes, une seule lecture, sans clé ni jeton dedans.
  const id = 'a'.repeat(32);
  const boite = (methode, corps, jeton = null, suite = '') =>
    relais.fetch(req(methode, jeton, corps, '/boite/' + id + suite), envG);
  assert.equal((await boite('PUT', { paquet: 'chiffre' })).status, 401);
  assert.equal((await relais.fetch(req('GET', null, null, '/boite/pas-bon'), envG)).status, 400);
  assert.equal((await boite('PUT', { paquet: 'x'.repeat(9000) }, J1)).status, 400);
  assert.equal((await boite('PUT', { paquet: 'paquet-chiffre' }, J1)).status, 201);
  assert.equal((await (await boite('GET', null, null, '?etat=1')).json()).present, true);
  rep = await boite('GET');
  assert.equal((await rep.json()).paquet, 'paquet-chiffre');
  // Deuxième lecture : déjà utilisé.
  assert.equal((await boite('GET')).status, 404);
  assert.equal((await (await boite('GET', null, null, '?etat=1')).json()).present, false);
  // Après 10 minutes : expiré, même si le KV ne l'a pas encore effacé.
  assert.equal((await boite('PUT', { paquet: 'p2' }, J1)).status, 201);
  const maintenant = Date.now;
  const t0 = Date.now();
  Date.now = () => t0 + 10 * 60 * 1000 + 1000;
  assert.equal((await boite('GET')).status, 404);
  Date.now = maintenant;

  // Code de secours : la demande n'est acceptée que si le patron attend ce code.
  const idc = 'b'.repeat(32);
  const dem = (methode, corps, jeton = null) => relais.fetch(req(methode, jeton, corps, '/demande/' + idc), envG);
  const ecrituresAvant = envG.ALERTES.ecritures;
  assert.equal((await dem('POST', { cle: 'k', appareil: 'Samsung' })).status, 404);
  assert.equal(envG.ALERTES.ecritures, ecrituresAvant, 'code faux : rien n\'est écrit');
  assert.equal((await dem('PUT', {})).status, 401);
  assert.equal((await dem('PUT', {}, J1)).status, 201);
  assert.equal((await dem('POST', { cle: 'cle-publique', appareil: 'Samsung A05' })).status, 201);
  assert.equal((await dem('POST', { cle: 'autre', appareil: 'Pirate' })).status, 409);
  assert.equal((await dem('GET')).status, 401);
  const lu = await (await dem('GET', null, J1)).json();
  assert.equal(lu.demande.appareil, 'Samsung A05');
  assert.equal(lu.demande.cle, 'cle-publique');

  // Les alertes marchent toujours à côté.
  assert.equal((await relais.fetch(req('POST', J1, { type: 't', message: 'x' }), envG)).status, 201);
  globalThis.fetch = fetchOrigine;
}
console.log('relais : tous les tests réussis');
