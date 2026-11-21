// Test du relais : node relais/worker.test.mjs
import assert from 'node:assert/strict';
import relais from './worker.js';

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
console.log('relais : tous les tests réussis');
