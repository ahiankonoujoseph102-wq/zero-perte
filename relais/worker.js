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

// --- Notifications Firebase (facultatif) -----------------------------------
// Si le secret FCM_COMPTE (fichier JSON du « compte de service » Firebase) est
// présent, chaque alerte est aussi envoyée en notification au téléphone du
// patron, même application fermée. Canal = « zp- » + début de l'empreinte du
// jeton (calculé de la même façon par l'application).

function b64url(octets) {
  let s = '';
  for (const b of new Uint8Array(octets)) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

async function jetonGoogle(compte) {
  const maintenant = Math.floor(Date.now() / 1000);
  const entete = b64url(new TextEncoder().encode(JSON.stringify({ alg: 'RS256', typ: 'JWT' })));
  const charge = b64url(new TextEncoder().encode(JSON.stringify({
    iss: compte.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: maintenant,
    exp: maintenant + 3600,
  })));
  const pem = compte.private_key.replace(/-----[^-]+-----/g, '').replace(/\s+/g, '');
  const cle = await crypto.subtle.importKey(
    'pkcs8',
    Uint8Array.from(atob(pem), (c) => c.charCodeAt(0)),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    cle,
    new TextEncoder().encode(`${entete}.${charge}`),
  );
  const r = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${entete}.${charge}.${b64url(signature)}`,
  });
  return (await r.json()).access_token;
}

async function notifier(env, boutique, alerte) {
  if (!env.FCM_COMPTE) return;
  const compte = JSON.parse(env.FCM_COMPTE);
  const jeton = await jetonGoogle(compte);
  await fetch(`https://fcm.googleapis.com/v1/projects/${compte.project_id}/messages:send`, {
    method: 'POST',
    headers: { authorization: `Bearer ${jeton}`, 'content-type': 'application/json' },
    body: JSON.stringify({
      message: {
        topic: `zp-${boutique.slice(0, 32)}`,
        notification: {
          title: alerte.type === 'resume_soir' ? 'Zéro Perte : résumé du soir' : 'Zéro Perte : alerte',
          body: alerte.message,
        },
        android: { priority: 'high' },
      },
    }),
  });
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
  async fetch(requete, env, ctx) {
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
      // Case « dernière alerte » : les consultations la lisent d'abord (lecture
      // simple) et ne listent les alertes que s'il y a du nouveau.
      await env.ALERTES.put(`d:${boutique}`, String(alerte.heure), { expirationTtl: SEPT_JOURS });
      // Notification (sans faire attendre l'appareil qui envoie l'alerte).
      const envoi = notifier(env, boutique, alerte).catch(() => {});
      if (ctx && ctx.waitUntil) ctx.waitUntil(envoi);
      return reponse(201, { ok: true });
    }

    if (requete.method === 'GET') {
      const depuis = parseInt(url.searchParams.get('depuis') || '0', 10) || 0;
      // Rien de nouveau depuis la dernière consultation : une seule lecture,
      // pas de liste (les listes sont comptées à part et bien plus limitées).
      const derniere = parseInt((await env.ALERTES.get(`d:${boutique}`)) || '0', 10) || 0;
      const alertes = [];
      if (derniere <= depuis) return reponse(200, { alertes });
      // Les clés sont rangées par heure : on suit les pages jusqu'au bout
      // (au plus 5 pages de 100) pour ne jamais manquer les plus récentes.
      let curseur;
      for (let page = 0; page < 5; page++) {
        const liste = await env.ALERTES.list({ prefix: `a:${boutique}:`, limit: 100, cursor: curseur });
        for (const k of liste.keys) {
          const heure = parseInt(k.name.split(':')[2], 10);
          if (heure <= depuis) continue;
          const v = await env.ALERTES.get(k.name);
          if (v) alertes.push(JSON.parse(v));
        }
        if (liste.list_complete !== false || !liste.cursor) break;
        curseur = liste.cursor;
      }
      return reponse(200, { alertes });
    }

    return reponse(405, { erreur: 'méthode' });
  },
};
