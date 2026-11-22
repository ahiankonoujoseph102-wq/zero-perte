// Zéro Perte — relais d'alertes graves (Cloudflare Workers, offre gratuite).
//
// Rôle : un appareil de la boutique dépose une alerte (écart de caisse,
// grosse annulation, code faux répété) ; le téléphone du patron la relève
// dans la minute. Rien d'autre ne passe ici : ni ventes, ni clients.
// Depuis la 0.35 : ajout d'un vendeur par QR code (plus bas).
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

// --- Ajout d'un vendeur par QR code (voir docs/conception-ajout-vendeur.md) ---
//
// Le téléphone du vendeur n'a ni compte Google ni mot de passe : il reçoit du
// patron (dans un paquet chiffré) un « jeton de longue durée » Google limité au
// dossier caché de Zéro Perte (drive.appdata). Le CODE SECRET de l'identifiant
// « Application Web » est seulement ici (secrets Cloudflare GOOGLE_WEB_ID et
// GOOGLE_WEB_SECRET) : jamais dans l'application.
//
// Le relais ne garde AUCUN jeton Google : il échange et transmet, c'est tout.
// Il garde seulement :
// - la liste noire des appareils retirés (empreinte SHA-256 du jeton) ;
// - les paquets chiffrés des invitations, 10 minutes au plus, lus une seule fois
//   (le relais ne peut pas les ouvrir : la clé est dans le QR code).

const DIX_MINUTES_MS = 10 * 60 * 1000;
const UN_AN = 400 * 24 * 3600;
const MAX_PAQUET = 8000;
const GOOGLE_JETON = 'https://oauth2.googleapis.com/token';
const GOOGLE_ANNULER = 'https://oauth2.googleapis.com/revoke';

async function corpsJson(requete) {
  try {
    return await requete.json();
  } catch (_) {
    return null;
  }
}

function googleConfigure(env) {
  return Boolean(env.GOOGLE_WEB_ID && env.GOOGLE_WEB_SECRET);
}

async function demanderGoogle(env, champs) {
  const corps = new URLSearchParams({
    client_id: env.GOOGLE_WEB_ID,
    client_secret: env.GOOGLE_WEB_SECRET,
    ...champs,
  });
  const r = await fetch(GOOGLE_JETON, {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: corps.toString(),
  });
  let d = {};
  try {
    d = await r.json();
  } catch (_) {}
  return { ok: r.ok, d };
}

// Liste noire : une lecture du KV au plus toutes les 10 minutes par appareil
// (mémoire de Cloudflare, gratuite), pour ne pas user les lectures permises.
async function estRetire(env, empreinteJeton) {
  const cle = `x:${empreinteJeton}`;
  const cache = typeof caches !== 'undefined' ? caches.default : null;
  const adresse = `https://liste-noire.zero-perte.invalid/${empreinteJeton}`;
  if (cache) {
    const m = await cache.match(adresse);
    if (m) return (await m.text()) === '1';
  }
  const retire = (await env.ALERTES.get(cle)) !== null;
  if (cache) {
    await cache.put(
      adresse,
      new Response(retire ? '1' : '0', { headers: { 'cache-control': 'max-age=600' } }),
    );
  }
  return retire;
}

async function oublierCache(empreinteJeton) {
  if (typeof caches === 'undefined') return;
  await caches.default.delete(`https://liste-noire.zero-perte.invalid/${empreinteJeton}`);
}

const ID_BOITE = /^[0-9a-f]{32}$/;
const EMPREINTE = /^[0-9a-f]{64}$/;

async function routeGoogle(requete, env, chemin) {
  // Identifiant (public) de l'application Web : le téléphone du patron en a
  // besoin pour demander l'accord à Google. Ce n'est pas un secret.
  if (chemin === '/google/id' && requete.method === 'GET') {
    if (!googleConfigure(env)) return reponse(503, { erreur: 'non configuré' });
    return reponse(200, { id: env.GOOGLE_WEB_ID });
  }
  if (requete.method !== 'POST') return reponse(405, { erreur: 'méthode' });
  if (!googleConfigure(env)) return reponse(503, { erreur: 'non configuré' });
  const d = await corpsJson(requete);
  if (!d) return reponse(400, { erreur: 'json' });

  // Patron : code d'échange (un seul usage, quelques minutes) → jeton long.
  if (chemin === '/google/echange') {
    if (!jetonDe(requete)) return reponse(401, { erreur: 'jeton absent' });
    if (typeof d.code !== 'string' || d.code.length > 2000) return reponse(400, { erreur: 'code' });
    const g = await demanderGoogle(env, { code: d.code, grant_type: 'authorization_code', redirect_uri: '' });
    if (!g.ok || !g.d.refresh_token) return reponse(400, { erreur: 'refusé par Google' });
    return reponse(200, { jeton_long: g.d.refresh_token });
  }

  // Vendeur : accès d'une heure au Drive, si son appareil n'est pas retiré.
  if (chemin === '/google/acces') {
    if (typeof d.jeton_long !== 'string' || d.jeton_long.length > 2000) {
      return reponse(400, { erreur: 'jeton' });
    }
    if (await estRetire(env, await empreinte(d.jeton_long))) {
      return reponse(403, { erreur: 'retiré' });
    }
    const g = await demanderGoogle(env, { refresh_token: d.jeton_long, grant_type: 'refresh_token' });
    if (!g.ok || !g.d.access_token) {
      // invalid_grant : autorisation annulée (« Couper tous les vendeurs »).
      return reponse(g.d.error === 'invalid_grant' ? 403 : 502, { erreur: 'refusé par Google' });
    }
    return reponse(200, { acces: g.d.access_token, expire_dans: g.d.expires_in ?? 3600 });
  }

  // Patron : retirer UN appareil (empreinte de son jeton, jamais le jeton).
  if (chemin === '/google/retirer') {
    if (!jetonDe(requete)) return reponse(401, { erreur: 'jeton absent' });
    if (typeof d.empreinte !== 'string' || !EMPREINTE.test(d.empreinte)) {
      return reponse(400, { erreur: 'empreinte' });
    }
    await env.ALERTES.put(`x:${d.empreinte}`, '1', { expirationTtl: UN_AN });
    await oublierCache(d.empreinte);
    return reponse(200, { ok: true });
  }

  // Patron : « Couper tous les vendeurs » : annule l'autorisation chez Google
  // (tous les jetons longs de la boutique cessent de marcher).
  if (chemin === '/google/couper') {
    if (!jetonDe(requete)) return reponse(401, { erreur: 'jeton absent' });
    if (typeof d.code !== 'string' || d.code.length > 2000) return reponse(400, { erreur: 'code' });
    const g = await demanderGoogle(env, { code: d.code, grant_type: 'authorization_code', redirect_uri: '' });
    const jeton = g.d.refresh_token || g.d.access_token;
    if (!g.ok || !jeton) return reponse(400, { erreur: 'refusé par Google' });
    const r = await fetch(GOOGLE_ANNULER, {
      method: 'POST',
      headers: { 'content-type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({ token: jeton }).toString(),
    });
    return r.ok ? reponse(200, { ok: true }) : reponse(502, { erreur: 'refusé par Google' });
  }
  return reponse(404, { erreur: 'introuvable' });
}

// Boîte aux lettres d'une invitation : un paquet chiffré, 10 minutes, lu une fois.
async function routeBoite(requete, env, id, url) {
  const cle = `b:${id}`;
  if (requete.method === 'PUT') {
    if (!jetonDe(requete)) return reponse(401, { erreur: 'jeton absent' });
    const d = await corpsJson(requete);
    if (!d || typeof d.paquet !== 'string' || d.paquet.length > MAX_PAQUET) {
      return reponse(400, { erreur: 'paquet' });
    }
    const fin = Date.now() + DIX_MINUTES_MS;
    await env.ALERTES.put(cle, JSON.stringify({ paquet: d.paquet, fin }), { expirationTtl: 660 });
    return reponse(201, { ok: true, fin });
  }
  if (requete.method === 'GET') {
    const brut = await env.ALERTES.get(cle);
    const v = brut ? JSON.parse(brut) : null;
    const valable = v && Date.now() <= v.fin;
    // Le patron regarde si le vendeur a pris le paquet (sans le prendre).
    if (url.searchParams.get('etat') === '1') return reponse(200, { present: Boolean(valable) });
    if (!valable) return reponse(404, { erreur: 'expiré ou déjà utilisé' });
    await env.ALERTES.delete(cle);
    return reponse(200, { paquet: v.paquet });
  }
  return reponse(405, { erreur: 'méthode' });
}

// Code de secours à 8 chiffres : le vendeur demande à entrer, le patron dit OUI.
async function routeDemande(requete, env, id) {
  if (requete.method === 'PUT') {
    // Patron : ouvre l'attente (10 minutes).
    if (!jetonDe(requete)) return reponse(401, { erreur: 'jeton absent' });
    await env.ALERTES.put(`w:${id}`, String(Date.now() + DIX_MINUTES_MS), { expirationTtl: 660 });
    return reponse(201, { ok: true });
  }
  if (requete.method === 'POST') {
    // Vendeur : seulement si le patron attend vraiment ce code (sinon rien
    // n'est écrit : essayer des codes au hasard ne remplit pas le relais).
    const fin = parseInt((await env.ALERTES.get(`w:${id}`)) || '0', 10);
    if (!fin || Date.now() > fin) return reponse(404, { erreur: 'code inconnu ou expiré' });
    if (await env.ALERTES.get(`q:${id}`)) return reponse(409, { erreur: 'déjà demandé' });
    const d = await corpsJson(requete);
    if (!d || typeof d.cle !== 'string' || d.cle.length > 100) return reponse(400, { erreur: 'clé' });
    const demande = { cle: d.cle, appareil: String(d.appareil || '').slice(0, 60) };
    await env.ALERTES.put(`q:${id}`, JSON.stringify(demande), { expirationTtl: 660 });
    return reponse(201, { ok: true });
  }
  if (requete.method === 'GET') {
    if (!jetonDe(requete)) return reponse(401, { erreur: 'jeton absent' });
    const brut = await env.ALERTES.get(`q:${id}`);
    return reponse(200, { demande: brut ? JSON.parse(brut) : null });
  }
  return reponse(405, { erreur: 'méthode' });
}

async function routeAlertes(requete, env, ctx, url) {
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
}

export default {
  async fetch(requete, env, ctx) {
    const url = new URL(requete.url);
    const chemin = url.pathname;
    if (chemin === '/alertes') return routeAlertes(requete, env, ctx, url);
    if (chemin.startsWith('/google/')) return routeGoogle(requete, env, chemin);
    const m = chemin.match(/^\/(boite|demande)\/([^/]+)$/);
    if (m) {
      if (!ID_BOITE.test(m[2])) return reponse(400, { erreur: 'identifiant' });
      return m[1] === 'boite' ? routeBoite(requete, env, m[2], url) : routeDemande(requete, env, m[2]);
    }
    return reponse(404, { erreur: 'introuvable' });
  },
};
