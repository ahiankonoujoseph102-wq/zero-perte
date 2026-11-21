#!/usr/bin/env python3
"""Dessine le logo Zéro Perte en SVG (formes calculées, traits nets).

Zéro blanc FERMÉ (ovale plein percé d'un ovale), coche verte devant, détachée
par un fin contour bleu nuit, anneau or ouvert et effilé, fond bleu nuit.
Couleurs du thème de l'application (lib/theme/couleurs.dart).

Écrit dans assets/logo/ :
  zero-perte.svg               logo complet (fond bleu nuit carré)
  zero-perte-avant-plan.svg    sans fond, réduit dans la zone sûre (icône adaptative)
  zero-perte-monochrome.svg    silhouette blanche (icônes à thème, Android 13+)
  zero-perte-notification.svg  silhouette blanche pour la barre des notifications
"""
import math
import os

BLEU_NUIT = "#0B1730"  # CouleursZp.fond
VERT = "#2BC77A"       # CouleursZp.argentEntreClair
OR = "#F8BE5F"         # CouleursZp.creditClair
BLANC = "#FFFFFF"

T = 1024  # toile
# Zéro (ovale plein percé d'un ovale : toujours fermé)
ZC = (512.0, 498.0)
Z_EXT = (224.0, 258.0)
Z_INT = (98.0, 158.0)
# Anneau or : ellipse ouverte en haut à droite (là où sort la coche)
AC = (506.0, 500.0)
A_RAYON = (380.0, 366.0)
A_DEBUT, A_FIN = -18.0, 318.0  # degrés (sens des aiguilles, 0 = à droite)
A_EPAISSEUR = 54.0
# Coche : trois points, trait rond
COCHE = [(398.0, 488.0), (532.0, 606.0), (862.0, 308.0)]
C_LARGEUR = 70.0
C_CONTOUR = 18.0  # fin contour bleu nuit de chaque côté


def ellipse(c, r):
    (x, y), (rx, ry) = c, r
    return (f"M{x - rx:.1f},{y:.1f}"
            f"A{rx:.1f},{ry:.1f} 0 1,0 {x + rx:.1f},{y:.1f}"
            f"A{rx:.1f},{ry:.1f} 0 1,0 {x - rx:.1f},{y:.1f}Z")


def zero():
    return ellipse(ZC, Z_EXT) + ellipse(ZC, Z_INT)


def anneau(n=240):
    """Croissant effilé : bord extérieur fixe, épaisseur qui grandit puis
    diminue (bouts fins et arrondis)."""
    ext, inte = [], []
    for i in range(n + 1):
        u = i / n
        t = math.radians(A_DEBUT + (A_FIN - A_DEBUT) * u)
        w = 4.0 + (A_EPAISSEUR - 4.0) * math.sin(math.pi * u) ** 0.7
        rx, ry = A_RAYON
        cx, cy = AC
        ext.append((cx + rx * math.cos(t), cy + ry * math.sin(t)))
        inte.append((cx + (rx - w) * math.cos(t), cy + (ry - w) * math.sin(t)))
    pts = ext + inte[::-1]
    d = "M" + " L".join(f"{x:.1f},{y:.1f}" for x, y in pts) + "Z"
    return d


def coche_d():
    return "M" + " L".join(f"{x:.1f},{y:.1f}" for x, y in COCHE)


def dessin(couleurs=True):
    """Le dessin sans fond. couleurs=False : silhouette blanche (le contour
    de la coche devient un vide)."""
    if couleurs:
        return f'''  <path d="{anneau()}" fill="{OR}"/>
  <path d="{zero()}" fill="{BLANC}" fill-rule="evenodd"/>
  <path d="{coche_d()}" fill="none" stroke="{BLEU_NUIT}" stroke-width="{C_LARGEUR + 2 * C_CONTOUR:.0f}" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="{coche_d()}" fill="none" stroke="{VERT}" stroke-width="{C_LARGEUR:.0f}" stroke-linecap="round" stroke-linejoin="round"/>'''
    return f'''  <defs>
    <mask id="vide" maskUnits="userSpaceOnUse" x="0" y="0" width="{T}" height="{T}">
      <rect width="{T}" height="{T}" fill="#fff"/>
      <path d="{coche_d()}" fill="none" stroke="#000" stroke-width="{C_LARGEUR + 2 * C_CONTOUR:.0f}" stroke-linecap="round" stroke-linejoin="round"/>
    </mask>
  </defs>
  <g mask="url(#vide)">
    <path d="{anneau()}" fill="{BLANC}"/>
    <path d="{zero()}" fill="{BLANC}" fill-rule="evenodd"/>
  </g>
  <path d="{coche_d()}" fill="none" stroke="{BLANC}" stroke-width="{C_LARGEUR:.0f}" stroke-linecap="round" stroke-linejoin="round"/>'''


def svg(contenu, titre, fond=None, echelle=1.0):
    g = contenu
    if echelle != 1.0:
        d = T / 2 * (1 - echelle)
        g = f'  <g transform="translate({d:.1f} {d:.1f}) scale({echelle})">\n{contenu}\n  </g>'
    f = f'  <rect width="{T}" height="{T}" fill="{fond}"/>\n' if fond else ''
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {T} {T}" '
            f'width="{T}" height="{T}" role="img" aria-label="{titre}">\n'
            f'  <title>{titre}</title>\n{f}{g}\n</svg>\n')


if __name__ == "__main__":
    dossier = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "logo")
    os.makedirs(dossier, exist_ok=True)
    # Icône adaptative : tout le dessin dans le cercle sûr (66/108 de la toile).
    sure = 0.70
    for nom, texte in {
        "zero-perte.svg": svg(dessin(), "Zéro Perte", fond=BLEU_NUIT),
        "zero-perte-avant-plan.svg": svg(dessin(), "Zéro Perte", echelle=sure),
        "zero-perte-monochrome.svg": svg(dessin(False), "Zéro Perte", echelle=sure),
        # Petite icône blanche des notifications (barre d'état).
        "zero-perte-notification.svg": svg(dessin(False), "Zéro Perte", echelle=0.92),
    }.items():
        with open(os.path.join(dossier, nom), "w", encoding="utf-8") as fichier:
            fichier.write(texte)
        print(nom)
