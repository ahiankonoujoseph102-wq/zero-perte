import 'package:flutter/material.dart';

import '../../app/etat_application.dart';
import '../../domaine/argent.dart';
import '../../domaine/calculs.dart';
import '../../donnees/journal_local.dart';
import '../../theme/couleurs.dart';
import '../clavier_montant.dart';
import '../communs.dart';
import '../vente/page_encaisser.dart' show nomPaiement, iconePaiement;
import '../patron/inventaire.dart' show PageInventaire;
import '../vente/ventes_du_jour.dart' show heureCourte;

/// Question posée pour chaque moyen de paiement (le vendeur ne voit jamais
/// combien il devrait y avoir : comptage aveugle).
(String, String) questionFermeture(ModePaiement m) => switch (m) {
  ModePaiement.especes => (
    'Comptez tout l\'argent de la caisse.',
    'Billets et pièces, monnaie du matin comprise.',
  ),
  _ => (
    'Combien avez-vous reçu sur ${nomPaiement(m)} ?',
    'Additionnez les paiements des clients reçus par ${nomPaiement(m)} depuis l\'ouverture.',
  ),
};

/// Fermeture de la caisse : un écran de comptage par moyen de paiement.
class PageFermerCaisse extends StatefulWidget {
  const PageFermerCaisse({super.key, required this.etat, required this.modes});

  final EtatApplication etat;
  final List<ModePaiement> modes;

  @override
  State<PageFermerCaisse> createState() => _PageFermerCaisseState();
}

class _PageFermerCaisseState extends State<PageFermerCaisse> {
  int _etape = 0;
  final Map<ModePaiement, int> _comptes = {};
  bool _enCours = false;

  ModePaiement get _mode => widget.modes[_etape];
  bool get _derniere => _etape == widget.modes.length - 1;

  Future<void> _suivant() async {
    if (!_derniere) {
      setState(() => _etape++);
      return;
    }
    setState(() => _enCours = true);
    try {
      final f = await widget.etat.fermerCaisse(_comptes);
      await widget.etat.services.voix.dire('Caisse fermée. Merci.');
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => widget.etat.estPatron
              ? PageResultatFermeture(etat: widget.etat, fermeture: f)
              : PageCaisseFermee(etat: widget.etat),
        ),
      );
    } catch (e) {
      if (mounted) annoncer(context, messageErreur(e), erreur: true);
      setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (question, aide) = questionFermeture(_mode);
    final montant = _comptes[_mode] ?? 0;
    return PopScope(
      canPop: _etape == 0,
      onPopInvokedWithResult: (aQuitte, _) {
        if (!aQuitte && _etape > 0) setState(() => _etape--);
      },
      child: PageZp(
        titre: 'Fermer la caisse',
        icone: Icons.lock_clock_rounded,
        bas: GrosBouton(
          key: const Key('bouton-suivant-fermeture'),
          texte: _derniere ? 'Fermer la caisse' : 'Suivant',
          icone: _derniere ? Icons.lock_rounded : Icons.arrow_forward_rounded,
          onPressed: _enCours ? null : _suivant,
        ),
        corps: ListView(
          // Nouvelle étape : l'écran repart en haut (la question est visible).
          key: ValueKey('etape-$_etape'),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          children: [
            if (widget.modes.length > 1)
              Text(
                'Étape ${_etape + 1} sur ${widget.modes.length}',
                key: const Key('etape-fermeture'),
                style: const TextStyle(
                  fontSize: 17,
                  color: CouleursZp.texteDoux,
                ),
              ),
            Row(
              children: [
                Icon(iconePaiement(_mode), size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    nomPaiement(_mode),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              question,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
            ),
            Text(
              aide,
              style: const TextStyle(fontSize: 17, color: CouleursZp.texteDoux),
            ),
            const SizedBox(height: 10),
            Center(
              child: MontantGeant(montant, key: const Key('montant-compte')),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 260,
              child: ClavierMontant(
                key: ValueKey(_mode),
                valeur: montant,
                onChange: (v) => setState(() => _comptes[_mode] = v),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fin de fermeture pour un vendeur : aucun chiffre (le patron verra l'écart).
class PageCaisseFermee extends StatelessWidget {
  const PageCaisseFermee({super.key, this.etat});

  /// Pour proposer le petit inventaire du jour (3 produits).
  final EtatApplication? etat;

  @override
  Widget build(BuildContext context) {
    return PageZp(
      titre: 'Caisse fermée',
      icone: Icons.lock_rounded,
      bas: etat == null
          ? GrosBouton(
              key: const Key('bouton-fin-fermeture'),
              texte: 'Terminé',
              icone: Icons.check_rounded,
              onPressed: () => Navigator.of(context).pop(),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Inventaire tournant : quelques produits chaque soir.
                GrosBouton(
                  key: const Key('bouton-compter-du-jour'),
                  texte: 'Compter les produits du jour',
                  icone: Icons.inventory_rounded,
                  onPressed: () async {
                    final p = await etat!.produitsAInventorierAujourdhui();
                    if (!context.mounted) return;
                    if (p.isEmpty) {
                      Navigator.of(context).pop();
                      return;
                    }
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => PageInventaire(
                          etat: etat!,
                          produits: p,
                          titre: 'Produits du jour',
                        ),
                      ),
                    );
                  },
                ),
                TextButton(
                  key: const Key('bouton-fin-fermeture'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Plus tard',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
      corps: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_rounded,
                size: 96,
                color: CouleursZp.argentEntre,
              ),
              SizedBox(height: 12),
              Text(
                'Caisse fermée. Merci !',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 8),
              Text(
                'Le patron verra le résultat.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 19, color: CouleursZp.texteDoux),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Phrase courte décrivant un écart.
String texteEcart(ResultatCaisse r) => switch (r.etat) {
  EtatCaisse.juste => 'Juste',
  EtatCaisse.manque => 'Il manque ${formatFrancs(-r.ecart)}',
  EtatCaisse.surplus => 'En trop : ${formatFrancs(r.ecart)}',
};

Color couleurEcart(EtatCaisse e) => switch (e) {
  EtatCaisse.juste => CouleursZp.argentEntre,
  EtatCaisse.manque => CouleursZp.argentSort,
  // Ambre foncé : lisible sur fond blanc.
  EtatCaisse.surplus => const Color(0xFF8A5300),
};

String dateEtHeure(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  final j = d.day.toString().padLeft(2, '0');
  final m = d.month.toString().padLeft(2, '0');
  return '$j/$m à ${heureCourte(ms)}';
}

/// Résultat d'une fermeture (patron seulement) : attendu, compté, écart.
class PageResultatFermeture extends StatelessWidget {
  const PageResultatFermeture({
    super.key,
    required this.etat,
    required this.fermeture,
  });

  final EtatApplication etat;
  final FermetureCaisse fermeture;

  @override
  Widget build(BuildContext context) {
    final f = fermeture;
    final modes = [
      for (final m in ModePaiement.caisses)
        if (m == ModePaiement.especes ||
            (f.attendus[m] ?? 0) != 0 ||
            (f.comptes[m] ?? 0) != 0)
          m,
    ];
    Widget ligne(String libelle, String valeur, {Color? couleur, Key? key}) =>
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(libelle, style: const TextStyle(fontSize: 18)),
              ),
              Text(
                valeur,
                key: key,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: couleur,
                ),
              ),
            ],
          ),
        );
    return PageZp(
      titre: 'Écart de caisse',
      icone: Icons.fact_check_rounded,
      corps: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Fermée le ${dateEtHeure(f.heure)} par ${etat.nomDe(f.auteurId)}',
            style: const TextStyle(fontSize: 17, color: CouleursZp.texteDoux),
          ),
          const SizedBox(height: 10),
          for (final m in modes)
            Builder(
              builder: (context) {
                final r = f.resultat(m);
                final c = couleurEcart(r.etat);
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: CouleursZp.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: c, width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(iconePaiement(m), size: 30),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              nomPaiement(m),
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      ligne('Il devait y avoir', formatFrancs(r.attendu)),
                      ligne('Compté', formatFrancs(r.compte)),
                      const Divider(),
                      Row(
                        children: [
                          Icon(
                            r.etat == EtatCaisse.juste
                                ? Icons.check_circle_rounded
                                : Icons.warning_rounded,
                            color: c,
                            size: 30,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              texteEcart(r),
                              key: Key('ecart-${m.code}'),
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: c,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// Liste des fermetures de caisse (espace patron).
class PageFermetures extends StatelessWidget {
  const PageFermetures({super.key, required this.etat});

  final EtatApplication etat;

  @override
  Widget build(BuildContext context) {
    return PageZp(
      titre: 'Caisses fermées',
      icone: Icons.fact_check_rounded,
      corps: FutureBuilder<List<FermetureCaisse>>(
        future: etat.journal.fermetures(),
        builder: (context, s) {
          if (!s.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final liste = s.data!;
          if (liste.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Aucune caisse fermée pour l\'instant.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: liste.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final f = liste[i];
              final total = ResultatCaisse(attendu: 0, compte: f.ecartTotal);
              final c = couleurEcart(total.etat);
              return Material(
                color: CouleursZp.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: c, width: 1.5),
                ),
                child: InkWell(
                  key: Key('fermeture-$i'),
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          PageResultatFermeture(etat: etat, fermeture: f),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dateEtHeure(f.heure),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                etat.nomDe(f.auteurId),
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: CouleursZp.texteDoux,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Flexible(
                          child: Text(
                            texteEcart(total),
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: c,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
