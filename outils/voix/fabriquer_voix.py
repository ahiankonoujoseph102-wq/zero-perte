#!/usr/bin/env python3
"""Fabrique la voix d'Afi (démonstration guidée) avec un service d'IA.

Lit docs/demo/texte-voix.md, demande chaque phrase au service (Gemini en
premier choix, OpenAI en secours), convertit en MP3 mono 24 kbit/s (lu par
Android 8 et par Windows sans bibliothèque), calcule le mouvement de la
bouche (volume toutes les 50 ms, chiffre de 0 à 9) et la forme de la bouche
(e / a / o, d'après le timbre), et écrit :
  assets/demo/voix/<numéro>.mp3
  assets/demo/voix/bouches.json

Mode `--extraits` : la même phrase d'accueil avec 3 voix différentes, pour
choisir à l'écoute (docs/site/voix/, publié sur le site).

Clés (jamais affichées, jamais écrites) : variables d'environnement
  ZP_CLE_VOIX          clé Gemini (ou OpenAI si elle commence par « sk- »)
  ZP_CLE_VOIX_SECOURS  clé OpenAI facultative, utilisée si Gemini échoue
Réglages facultatifs : ZP_VOIX_MODELE, ZP_VOIX_NOM.
Sans clé, `--essai` fabrique des sons de test (bip) pour vérifier la chaîne.
"""
import base64
import datetime
import json
import math
import os
import re
import struct
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request

RACINE = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
TEXTE = os.path.join(RACINE, "docs", "demo", "texte-voix.md")
SORTIE = os.path.join(RACINE, "assets", "demo", "voix")
TAUX = 24000  # Hz, PCM 16 bits mono
PAS_BOUCHE_MS = 50

STYLE = (
    "Lis ce texte en français, avec une voix de femme chaleureuse, claire et "
    "souriante, au rythme posé, comme une commerçante qui explique gentiment "
    "à un client. Ne lis que le texte, sans rien ajouter : "
)

GEMINI_MODELES = ["gemini-3.1-flash-tts-preview", "gemini-2.5-flash-preview-tts"]
GEMINI_VOIX = "Sulafat"  # voix féminine chaleureuse (réglable : ZP_VOIX_NOM)
OPENAI_MODELE = "gpt-4o-mini-tts"
OPENAI_VOIX = "coral"


def lire_phrases():
    t = open(TEXTE, encoding="utf-8").read()
    lignes = re.findall(r"^\| (\d{3}) \| (\S+) \| ([^|]+) \| ([^|]+) \|$", t, re.M)
    if not lignes:
        sys.exit("Aucune phrase trouvée dans docs/demo/texte-voix.md")
    return [(n, f, p.strip()) for n, f, _, p in lignes]


class QuotaDuJour(RuntimeError):
    """Quota du jour atteint (offre gratuite) : on garde ce qui est fait et
    on reprendra après la remise à zéro (minuit en Californie)."""


def _analyser_429(texte):
    """(quota du jour ?, attente conseillée en s, description) d'une réponse
    429 de Google, sans jamais citer la clé (elle n'y est pas)."""
    try:
        j = json.loads(texte)
    except ValueError:
        return False, 30, texte[:200]
    jour, attente, quotas = False, 30, []
    for d in j.get("error", {}).get("details", []):
        for v in d.get("violations", []):
            q = f"{v.get('quotaId', '?')} = {v.get('quotaValue', '?')}"
            quotas.append(q)
            if "PerDay" in v.get("quotaId", ""):
                jour = True
        if "retryDelay" in d:
            try:
                attente = float(str(d["retryDelay"]).rstrip("s")) + 2
            except ValueError:
                pass
    return jour, attente, "; ".join(quotas) or j.get("error", {}).get("message", "")[:200]


def requete(url, corps, entetes, essais=6):
    """POST JSON ; renvoie les octets de la réponse. Les erreurs ne citent
    jamais la clé (elle est dans un en-tête, pas dans l'adresse)."""
    donnees = json.dumps(corps).encode("utf-8")
    for essai in range(essais):
        req = urllib.request.Request(url, data=donnees, method="POST")
        for k, v in entetes.items():
            req.add_header(k, v)
        try:
            with urllib.request.urlopen(req, timeout=180) as r:
                return r.read()
        except urllib.error.HTTPError as e:
            texte = e.read().decode("utf-8", "replace")
            if e.code == 429:
                jour, attente, quotas = _analyser_429(texte)
                if jour:
                    raise QuotaDuJour(f"quota du jour atteint ({quotas})")
                if essai < essais - 1:
                    print(f"  quota par minute ({quotas}) : attente {attente:.0f} s")
                    time.sleep(min(attente, 90))
                    continue
                raise RuntimeError(f"HTTP 429 : {quotas}")
            if e.code in (500, 502, 503) and essai < essais - 1:
                time.sleep(5 * (essai + 1))
                continue
            raise RuntimeError(f"HTTP {e.code} : {texte[:300]}")
        except urllib.error.URLError as e:
            if essai < essais - 1:
                time.sleep(5)
                continue
            raise RuntimeError(f"réseau : {e.reason}")
    raise RuntimeError("trop d'essais")


def gemini(texte, cle, modele, voix, style=STYLE):
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{modele}:generateContent"
    corps = {
        "contents": [{"parts": [{"text": style + texte}]}],
        "generationConfig": {
            "responseModalities": ["AUDIO"],
            "speechConfig": {
                "voiceConfig": {"prebuiltVoiceConfig": {"voiceName": voix}},
            },
        },
    }
    r = json.loads(requete(url, corps, {"x-goog-api-key": cle, "Content-Type": "application/json"}))
    for c in r.get("candidates", []):
        for p in c.get("content", {}).get("parts", []):
            d = p.get("inlineData") or p.get("inline_data")
            if d and d.get("data"):
                return base64.b64decode(d["data"])  # PCM 24 kHz 16 bits mono
    raise RuntimeError("réponse Gemini sans audio")


def openai(texte, cle, modele, voix):
    corps = {
        "model": modele,
        "voice": voix,
        "input": texte,
        "instructions": STYLE.rstrip(" :"),
        "response_format": "pcm",  # 24 kHz 16 bits mono
    }
    return requete(
        "https://api.openai.com/v1/audio/speech",
        corps,
        {"Authorization": f"Bearer {cle}", "Content-Type": "application/json"},
    )


def bip(texte):
    """Son de test (sans service) : un bip doux de la durée de la phrase."""
    n = int(TAUX * max(1.0, len(texte) / 13))
    return b"".join(
        struct.pack("<h", int(6000 * math.sin(2 * math.pi * 220 * i / TAUX) * (0.5 + 0.5 * math.sin(i / 1800))))
        for i in range(n)
    )


def bouche(pcm):
    """Volume toutes les 50 ms → chiffres 0..9 (lissés)."""
    echantillons = struct.unpack(f"<{len(pcm) // 2}h", pcm[: len(pcm) // 2 * 2])
    pas = TAUX * PAS_BOUCHE_MS // 1000
    rms = []
    for i in range(0, len(echantillons), pas):
        bloc = echantillons[i : i + pas]
        rms.append(math.sqrt(sum(x * x for x in bloc) / max(1, len(bloc))))
    if not rms:
        return ""
    haut = sorted(rms)[int(len(rms) * 0.95)] or 1
    valeurs, avant = [], 0.0
    for r in rms:
        v = min(1.0, r / haut)
        v = 0.0 if v < 0.12 else v
        avant = avant * 0.35 + v * 0.65
        valeurs.append(str(min(9, round(avant * 9))))
    return "".join(valeurs)


def formes(pcm):
    """Forme de la bouche toutes les 50 ms d'après le timbre (passages par
    zéro) : « e » (son clair, aigu), « a » (ouvert), « o » (son sourd, rond),
    « m » (silence)."""
    echantillons = struct.unpack(f"<{len(pcm) // 2}h", pcm[: len(pcm) // 2 * 2])
    pas = TAUX * PAS_BOUCHE_MS // 1000
    res = []
    for i in range(0, len(echantillons), pas):
        bloc = echantillons[i : i + pas]
        if not bloc:
            break
        rms = math.sqrt(sum(x * x for x in bloc) / len(bloc))
        if rms < 400:
            res.append("m")
            continue
        zc = sum(1 for a, b in zip(bloc, bloc[1:]) if (a < 0) != (b < 0)) / len(bloc)
        res.append("e" if zc > 0.12 else ("a" if zc > 0.05 else "o"))
    return "".join(res)


def encoder(pcm, sortie):
    """PCM → MP3 mono 24 kbit/s (Android 8 et Windows le lisent sans
    bibliothèque)."""
    with tempfile.NamedTemporaryFile(suffix=".pcm", delete=False) as f:
        f.write(pcm)
        brut = f.name
    try:
        subprocess.run(
            ["ffmpeg", "-y", "-loglevel", "error", "-f", "s16le", "-ar", str(TAUX), "-ac", "1",
             "-i", brut, "-c:a", "libmp3lame", "-b:a", "24k", "-ac", "1", "-ar", str(TAUX),
             sortie],
            check=True,
        )
    finally:
        os.unlink(brut)


STYLE_LOT = (
    "Lis ce texte en français, avec une voix de femme chaleureuse, claire et "
    "souriante, au rythme posé, comme une commerçante qui explique gentiment "
    "à un client. Il y a plusieurs paragraphes : lis-les dans l'ordre et fais "
    "une longue pause, d'environ deux secondes, entre deux paragraphes. Ne lis "
    "que le texte, sans rien ajouter :\n\n"
)
TAILLE_LOT = 5


def _niveaux(pcm):
    """Volume (RMS) toutes les 50 ms."""
    ech = struct.unpack(f"<{len(pcm) // 2}h", pcm[: len(pcm) // 2 * 2])
    pas = TAUX * PAS_BOUCHE_MS // 1000
    return [
        math.sqrt(sum(x * x for x in ech[i : i + pas]) / max(1, len(ech[i : i + pas])))
        for i in range(0, len(ech), pas)
    ]


def decouper(pcm, textes):
    """Découpe l'audio d'un lot en autant de morceaux que de phrases, aux
    pauses les plus longues. Renvoie la liste des PCM, ou None si le
    découpage n'est pas sûr (on demandera alors phrase par phrase)."""
    n = len(textes)
    if n == 1:
        return [pcm]
    niv = _niveaux(pcm)
    if not niv:
        return None
    haut = sorted(niv)[int(len(niv) * 0.95)] or 1
    calme = [v < haut * 0.06 for v in niv]
    # Pauses : suites de blocs calmes (début, longueur), hors début et fin.
    pauses, i = [], 0
    while i < len(calme):
        if calme[i]:
            j = i
            while j < len(calme) and calme[j]:
                j += 1
            if i > 0 and j < len(calme):
                pauses.append((i, j - i))
            i = j
        else:
            i += 1
    if len(pauses) < n - 1:
        return None
    par_longueur = sorted(pauses, key=lambda p: -p[1])
    choisies = sorted(par_longueur[: n - 1])
    plus_courte = min(p[1] for p in choisies)
    suivante = par_longueur[n - 1][1] if len(par_longueur) >= n else 0
    # Les pauses entre phrases doivent être nettement plus longues que les
    # pauses à l'intérieur d'une phrase.
    if plus_courte < 12 or (suivante and plus_courte < suivante * 1.4):
        return None
    pas = TAUX * PAS_BOUCHE_MS // 1000 * 2  # octets par bloc
    marge = 3  # blocs de silence gardés de chaque côté (150 ms)
    morceaux, debut = [], 0
    for d, l in choisies:
        morceaux.append(pcm[debut * pas : (d + marge) * pas])
        debut = d + l - marge
    morceaux.append(pcm[debut * pas :])
    # Durées cohérentes avec la longueur des textes.
    rapports = [len(m) / max(1, len(t)) for m, t in zip(morceaux, textes)]
    milieu = sorted(rapports)[len(rapports) // 2]
    if any(r < milieu * 0.55 or r > milieu * 1.8 for r in rapports):
        return None
    return morceaux


def _retirer_silence(pcm):
    """Retire le silence au début et à la fin (garde 150 ms)."""
    niv = _niveaux(pcm)
    if not niv:
        return pcm
    haut = sorted(niv)[int(len(niv) * 0.95)] or 1
    actifs = [i for i, v in enumerate(niv) if v >= haut * 0.06]
    if not actifs:
        return pcm
    pas = TAUX * PAS_BOUCHE_MS // 1000 * 2
    return pcm[max(0, actifs[0] - 3) * pas : (actifs[-1] + 4) * pas]


EXTRAIT = (
    "Bonjour ! Je m'appelle Afi. Bienvenue dans la démonstration de Zéro Perte. "
    "Ensemble, nous allons visiter une boutique pour de faux. "
    "Rien n'est gardé : vous pouvez tout essayer."
)
GEMINI_EXTRAITS = ["Sulafat", "Aoede", "Achernar"]
OPENAI_EXTRAITS = ["coral", "nova", "shimmer"]


def extraits(cle, secours, modele, essai):
    """Même phrase d'accueil avec 3 voix → docs/site/voix/ (+ page d'écoute)."""
    dossier = os.path.join(RACINE, "docs", "site", "voix")
    os.makedirs(dossier, exist_ok=True)
    faits = []
    for service, k, voix_liste in (
        [("essai", None, GEMINI_EXTRAITS)] if essai else
        ([("openai", cle, OPENAI_EXTRAITS)] if cle.startswith("sk-") else
         [("gemini", cle, GEMINI_EXTRAITS)] + ([("openai", secours, OPENAI_EXTRAITS)] if secours else []))
    ):
        try:
            for i, voix in enumerate(voix_liste, 1):
                if service == "gemini":
                    pcm = None
                    for m in ([modele] if modele else GEMINI_MODELES):
                        try:
                            pcm = gemini(EXTRAIT, k, m, voix)
                            break
                        except Exception as e:  # modèle suivant
                            print(f"  {m} : {e}")
                    if pcm is None:
                        raise RuntimeError("aucun modèle Gemini")
                elif service == "openai":
                    pcm = openai(EXTRAIT, k, OPENAI_MODELE, voix)
                else:
                    pcm = bip(EXTRAIT)
                nom = f"extrait-{i}-{voix.lower()}.mp3"
                encoder(pcm, os.path.join(dossier, nom))
                faits.append((i, voix, nom, round(len(pcm) / 2 / TAUX, 1), service))
                print(f"  voix {i} ({voix}) : {faits[-1][3]} s")
            break
        except Exception as e:
            print(f"  échec avec {service} : {e}")
            faits = []
    if not faits:
        sys.exit("Aucun extrait n'a pu être fabriqué.")
    lignes = "\n".join(
        f'<section><h2>Voix {i}</h2><p>{voix} · {duree} s</p>'
        f'<audio controls preload="none" src="{nom}"></audio>'
        f'<p><a href="{nom}">Télécharger</a></p></section>'
        for i, voix, nom, duree, _ in faits
    )
    page = f"""<!doctype html>
<html lang="fr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Voix d'Afi — 3 extraits</title>
<link rel="icon" href="../logo.svg" type="image/svg+xml">
<link rel="stylesheet" href="../style.css">
<style>section{{background:var(--surface);border:1px solid var(--ligne);border-radius:16px;padding:16px;margin:12px 0}}audio{{width:100%}}</style>
</head><body><main>
<h1>Voix d'Afi : 3 extraits</h1>
<p class="chapeau">Même phrase d'accueil, trois voix différentes. Écoutez-les et dites laquelle choisir
(Voix 1, 2 ou 3).</p>
<p>« {EXTRAIT} »</p>
{lignes}
<p class="date">Voix générée par intelligence artificielle ({faits[0][4]}).</p>
</main></body></html>
"""
    open(os.path.join(dossier, "index.html"), "w", encoding="utf-8").write(page)
    print(f"Extraits prêts : {len(faits)} voix ({faits[0][4]}).")


def main():
    essai = "--essai" in sys.argv
    if "--extraits" in sys.argv:
        extraits(
            os.environ.get("ZP_CLE_VOIX", "").strip(),
            os.environ.get("ZP_CLE_VOIX_SECOURS", "").strip(),
            os.environ.get("ZP_VOIX_MODELE", "").strip(),
            essai,
        )
        return
    cle = os.environ.get("ZP_CLE_VOIX", "").strip()
    secours = os.environ.get("ZP_CLE_VOIX_SECOURS", "").strip()
    if not cle and not essai:
        sys.exit("Le secret ZP_CLE_VOIX est absent (voir docs/etapes-proprietaire.md, partie H).")
    voix_nom = os.environ.get("ZP_VOIX_NOM", "").strip()
    modele = os.environ.get("ZP_VOIX_MODELE", "").strip()

    # Choix du service : une seule voix pour toute la démonstration.
    if essai:
        services = [("essai", None, "", "")]
    elif cle.startswith("sk-"):
        services = [("openai", cle, modele or OPENAI_MODELE, voix_nom or OPENAI_VOIX)]
    else:
        services = [("gemini", cle, m, voix_nom or GEMINI_VOIX) for m in ([modele] if modele else GEMINI_MODELES)]
        if secours:
            services.append(("openai", secours, OPENAI_MODELE, OPENAI_VOIX))

    phrases = lire_phrases()
    os.makedirs(SORTIE, exist_ok=True)
    chemin_json = os.path.join(SORTIE, "bouches.json")

    # Reprise : on garde les phrases déjà faites (même texte, même service,
    # même voix) et on continue avec le même modèle (une seule voix).
    ancien = {}
    try:
        ancien = json.load(open(chemin_json, encoding="utf-8"))
    except (OSError, ValueError):
        pass
    deja = {}
    if ancien.get("phrases") and not essai:
        meme = [x for x in services if x[0] == ancien.get("service") and x[2] == ancien.get("modele") and x[3] == ancien.get("voix")]
        if meme:
            services = meme
            textes = {n: t for n, _, t in phrases}
            deja = {
                n: p for n, p in ancien["phrases"].items()
                if p.get("texte") == textes.get(n) and os.path.exists(os.path.join(SORTIE, p["fichier"]))
            }
            print(f"Reprise : {len(deja)} phrases déjà faites ({ancien.get('modele')}, {ancien.get('voix')}).")

    def ecrire(service, mod, voix, resultat):
        complet = len(resultat) == len(phrases)
        json.dump(
            {
                "version": 1,
                "service": service,
                "modele": mod,
                "voix": voix,
                "pas_bouche_ms": PAS_BOUCHE_MS,
                "fabrique_le": datetime.date.today().isoformat(),
                "complet": complet,
                "mention": "Voix générée par intelligence artificielle",
                "phrases": dict(sorted(resultat.items())),
            },
            open(chemin_json, "w", encoding="utf-8"),
            ensure_ascii=False,
            indent=1,
        )
        total = sum(os.path.getsize(os.path.join(SORTIE, p["fichier"])) for p in resultat.values())
        duree = sum(p["duree_ms"] for p in resultat.values()) / 1000
        etat = "complète" if complet else "INCOMPLÈTE"
        print(f"Voix {etat} : {len(resultat)}/{len(phrases)} phrases, {duree:.0f} s, {total / 1024:.0f} Ko.")

    def garder(resultat, n, fichier, texte, pcm):
        pcm = _retirer_silence(pcm)
        encoder(pcm, os.path.join(SORTIE, fichier))
        resultat[n] = {
            "fichier": fichier,
            "texte": texte,
            "duree_ms": round(len(pcm) / 2 / TAUX * 1000),
            "bouche": bouche(pcm),
            "forme": formes(pcm),
        }
        print(f"  {n} : {resultat[n]['duree_ms']} ms")

    for service, k, mod, voix in services:
        print(f"Service : {service} {mod} {voix}".rstrip())
        resultat = dict(deja) if deja else {}
        restantes = [x for x in phrases if x[0] not in resultat]
        try:
            if service == "gemini":
                # Par lots de 5 (10 demandes au lieu de 50) ; lot douteux :
                # phrase par phrase.
                for i in range(0, len(restantes), TAILLE_LOT):
                    lot = restantes[i : i + TAILLE_LOT]
                    morceaux = None
                    # Lot douteux : redemandé une fois (1 demande), puis phrase
                    # par phrase (5 demandes).
                    for _ in range(2 if len(lot) > 1 else 0):
                        pcm = gemini("\n\n".join(t for _, _, t in lot), k, mod, voix, STYLE_LOT)
                        morceaux = decouper(pcm, [t for _, _, t in lot])
                        if morceaux is not None:
                            break
                        print(f"  lot {lot[0][0]}–{lot[-1][0]} : découpage pas sûr")
                    if morceaux is None:
                        morceaux = [gemini(t, k, mod, voix) for _, _, t in lot]
                    for (n, fichier, texte), m in zip(lot, morceaux):
                        garder(resultat, n, fichier, texte, m)
                    time.sleep(2)
            else:
                for n, fichier, texte in restantes:
                    pcm = openai(texte, k, mod, voix) if service == "openai" else bip(texte)
                    garder(resultat, n, fichier, texte, pcm)
        except QuotaDuJour as e:
            print(f"  {e}")
            if resultat:
                # On garde ce qui est fait ; même modèle à la reprise.
                ecrire(service, mod, voix, resultat)
                print("À relancer après la remise à zéro du quota (vers 8 h, heure de Lomé).")
                return
            continue
        except Exception as e:  # le message ne contient jamais la clé
            print(f"  échec avec {service} : {e}")
            if resultat and len(resultat) > len(deja):
                ecrire(service, mod, voix, resultat)
                return
            continue
        ecrire(service, mod, voix, resultat)
        return
    sys.exit("Aucun service n'a pu fabriquer la voix.")


if __name__ == "__main__":
    main()
