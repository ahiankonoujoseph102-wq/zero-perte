// Zéro Perte — relais d'alertes graves (Cloudflare Workers, offre gratuite).
//
// Rôle : un appareil de la boutique dépose une alerte (écart de caisse,
// grosse annulation, code faux répété) ; le téléphone du patron la relève
// dans la minute. Rien d'autre ne passe ici : ni ventes, ni clients.
//
// Sécurité : chaque boutique a un jeton secret (créé par l'application et
// rangé dans le Google Drive de la boutique). Le relais ne garde que
// l'empreinte SHA-256 de ce jeton : sans le jeton, on ne peut ni lire ni
// écrire les alertes d'une boutique. Les alertes sont effacées après 7 jours.
//
// Déploiement : voir docs/etapes-proprietaire.md (espace KV nommé ALERTES).

const SEPT_JOURS = 7 * 24 * 3600;
const MAX_MESSAGE = 300;
const MAX_PAR_HEURE = 60;

async function empreinte(jeton) {
  const octets = new TextEncoder().encode(jeton);
  const h = await crypto.subtle.digest('SHA-256', octets);
  return [...new Uint8Array(h)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

function reponse(statut, corps) {
  return new Response(JSON.stringify(corps), {
    status: statut,
    headers: { 'content-type': 'application/json; charset=utf-8' },
  });
}

function jetonDe(requete) {
  const a = requete.headers.get('authorization') || '';
  const m = a.match(/^Bearer ([A-Za-z0-9_-]{20,100})$/);
  return m ? m[1] : null;
}

export default {
  async fetch(requete, env) {
    const url = new URL(requete.url);
    if (url.pathname !== '/alertes') return reponse(404, { erreur: 'introuvable' });
    const jeton = jetonDe(requete);
    if (!jeton) return reponse(401, { erreur: 'jeton absent' });
    const boutique = await empreinte(jeton);

    if (requete.method === 'POST') {
      // Limite : 60 alertes par heure et par boutique.
      const heure = Math.floor(Date.now() / 3600000);
      const cleCompte = `n:${boutique}:${heure}`;
      const n = parseInt((await env.ALERTES.get(cleCompte)) || '0', 10);
      if (n >= MAX_PAR_HEURE) return reponse(429, { erreur: 'trop d\'alertes' });
      await env.ALERTES.put(cleCompte, String(n + 1), { expirationTtl: 7200 });

      let a;
      try {
        a = await requete.json();
      } catch (_) {
        return reponse(400, { erreur: 'json' });
      }
      const alerte = {
        type: String(a.type || '').slice(0, 40),
        message: String(a.message || '').slice(0, MAX_MESSAGE),
        appareil: String(a.appareil || '').slice(0, 40),
        heure: Date.now(),
      };
      const cle = `a:${boutique}:${String(alerte.heure).padStart(15, '0')}:${crypto.randomUUID()}`;
      await env.ALERTES.put(cle, JSON.stringify(alerte), { expirationTtl: SEPT_JOURS });
      return reponse(201, { ok: true });
    }

    if (requete.method === 'GET') {
      const depuis = parseInt(url.searchParams.get('depuis') || '0', 10) || 0;
      const liste = await env.ALERTES.list({ prefix: `a:${boutique}:`, limit: 100 });
      const alertes = [];
      for (const k of liste.keys) {
        const heure = parseInt(k.name.split(':')[2], 10);
        if (heure <= depuis) continue;
        const v = await env.ALERTES.get(k.name);
        if (v) alertes.push(JSON.parse(v));
      }
      return reponse(200, { alertes });
    }

    return reponse(405, { erreur: 'méthode' });
  },
};
