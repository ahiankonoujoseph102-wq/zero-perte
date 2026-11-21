#!/usr/bin/env python3
"""Fabrique toutes les icônes depuis les SVG de assets/logo/ (rendu Chromium).

  python3 outils/logo/dessiner_logo.py      # (re)dessine les SVG
  python3 outils/logo/fabriquer_icones.py   # PNG Android, ICO Windows, site web
"""
import os
import shutil
import subprocess
import tempfile

from PIL import Image

RACINE = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
LOGO = os.path.join(RACINE, "assets", "logo")
RES = os.path.join(RACINE, "android", "app", "src", "main", "res")
SITE = os.path.join(RACINE, "docs", "site")
RENDRE = os.path.join(os.path.dirname(__file__), "rendre.js")

DENSITES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}


def rendre(svg, taille, sortie, coins=None):
    args = ["node", RENDRE, os.path.join(LOGO, svg), str(taille), sortie]
    if coins:
        args.append(str(coins))
    subprocess.run(args, check=True)
    # PNG propre et compact (palette si possible sans perte visible).
    im = Image.open(sortie).convert("RGBA")
    im.save(sortie, optimize=True)


def main():
    # 1. Logo PNG 1024 × 1024 (source gardée dans le dépôt).
    rendre("zero-perte.svg", 1024, os.path.join(LOGO, "zero-perte-1024.png"))

    # 2. Android : icône adaptative (avant-plan + monochrome, 108 dp) et
    #    icône classique (48 dp) pour les écrans qui ne découpent pas.
    for nom, f in DENSITES.items():
        dossier = os.path.join(RES, f"mipmap-{nom}")
        os.makedirs(dossier, exist_ok=True)
        rendre("zero-perte-avant-plan.svg", int(108 * f),
               os.path.join(dossier, "ic_launcher_foreground.png"))
        rendre("zero-perte-monochrome.svg", int(108 * f),
               os.path.join(dossier, "ic_launcher_monochrome.png"))
        rendre("zero-perte.svg", int(48 * f),
               os.path.join(dossier, "ic_launcher.png"), coins=18)
        # Icône des notifications : silhouette blanche 24 dp.
        dessin_notif = os.path.join(RES, f"drawable-{nom}")
        os.makedirs(dessin_notif, exist_ok=True)
        rendre("zero-perte-notification.svg", int(24 * f),
               os.path.join(dessin_notif, "ic_notification.png"))

    # 3. Windows : .ico multi-tailles (16 à 256).
    with tempfile.TemporaryDirectory() as t:
        tailles = [16, 24, 32, 48, 64, 128, 256]
        images = []
        for n in tailles:
            p = os.path.join(t, f"{n}.png")
            rendre("zero-perte.svg", n, p)
            images.append(Image.open(p).convert("RGBA"))
        ico = os.path.join(RACINE, "windows", "runner", "resources", "app_icon.ico")
        images[-1].save(ico, format="ICO", sizes=[(n, n) for n in tailles],
                        append_images=images[:-1])

    # 4. Site web : icône d'onglet et logo du haut des pages.
    shutil.copy(os.path.join(LOGO, "zero-perte.svg"), os.path.join(SITE, "logo.svg"))
    rendre("zero-perte.svg", 32, os.path.join(SITE, "favicon-32.png"))
    rendre("zero-perte.svg", 180, os.path.join(SITE, "apple-touch-icon.png"))
    print("Icônes fabriquées.")


if __name__ == "__main__":
    main()
