import 'package:flutter/material.dart';

import '../../app/etat_application.dart';
import '../../domaine/argent.dart';
import '../../domaine/calculs.dart';
import '../../donnees/journal_local.dart';
import '../clavier_montant.dart';
import '../vente/page_encaisser.dart' show nomPaiement;
import '../../theme/couleurs.dart';
import '../communs.dart';
import '../patron/graphiques.dart';
import '../vente/ventes_du_jour.dart' show heureCourte;
import 'fermeture.dart';
import 'saisie_montant.dart';
import '../depense/page_depense.dart';

/// « Ma caisse » : ouvrir la caisse (fond initial), sortir de l'argent
/// (dépense), fermer la caisse, et l'historique des sessions.
///
/// Le vendeur ne voit jamais ce qui devrait être dans la caisse (fermeture
/// aveugle) : seul le patron voit l'attendu et les écarts.
class PageMaCaisse extends StatefulWidget {
  const PageMaCaisse({super.key, required this.etat});

  final EtatApplication etat;

  @override
  State<PageMaCaisse> createState() => _PageMaCaisseState();
}

class _PageMaCaisseState extends State<PageMaCaisse> {
  late Future<EtatCaisseJour> _etat = widget.etat.etatCaisse();

  EtatApplication get etat => widget.etat;

  Future<void> _ouvrirPage(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (!mounted) return;
    setState(() {
      _etat = etat.etatCaisse();
    });
  }

  Future<void> _fermer() async {
    if (!await etat.caisseOuverte()) {
      if (mounted) annoncer(context, 'La caisse n\'est pas ouverte.');
      return;
    }
    final modes = await etat.modesAFermer();
    if (!mounted) return;
    await _ouvrirPage(PageFermerCaisse(etat: etat, modes: modes));
  }

  @override
  Widget build(BuildContext context) {
    return PageZp(
      titre: 'Ma caisse',
      icone: Icons.point_of_sale_rounded,
      pleineLargeur: true,
      corps: FutureBuilder<EtatCaisseJour>(
        future: _etat,
        builder: (context, s) {
          if (!s.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final c = s.data!;
          final statut = _Statut(c: c);
          final boutons = _Boutons(
            ouverte: c.ouverte,
            patron: etat.voitTout,
            onOuvrir: () => _ouvrirPage(pageOuvrirCaisse(etat)),
            onDepense: () => _ouvrirPage(
              PageChoixDepense(
                etat: etat,
                ouvrirDepenseArgent: (_) => pageDepenseArgent(etat),
              ),
            ),
            onRetrait: () => _ouvrirPage(pageRetraitPatron(etat)),
            onFermer: _fermer,
          );
          final attendu = c.attendus.isEmpty || !c.ouverte
              ? null
              : CarteZp(
                  titre: 'Doit être dans la caisse',
                  icone: Icons.visibility_rounded,
                  child: Column(
                    children: [
                      for (final m in ModePaiement.caisses)
                        if (m == ModePaiement.especes ||
                            (c.attendus[m] ?? 0) != 0)
                          _Ligne(
                            cle: 'attendu-${m.code}',
                            gauche: nomPaiement(m),
                            droite: formatFrancs(c.attendus[m] ?? 0),
                          ),
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'Le vendeur ne voit pas ces chiffres : il compte à l\'aveugle.',
                          style: TextStyle(
                            fontSize: 15,
                            color: CouleursZp.texteDoux,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
          final historique = CarteZp(
            titre: 'Sessions de caisse',
            icone: Icons.history_rounded,
            child: c.sessions.isEmpty
                ? const Text(
                    'Aucune caisse fermée pour l\'instant.',
                    style: TextStyle(fontSize: 17, color: CouleursZp.texteDoux),
                  )
                : Column(
                    children: [
                      for (final (i, f) in c.sessions.indexed)
                        _Session(
                          index: i,
                          fermeture: f,
                          etat: etat,
                          patron: etat.voitTout,
                        ),
                    ],
                  ),
          );
          final gauche = [
            statut,
            const SizedBox(height: 14),
            boutons,
            if (attendu != null) ...[const SizedBox(height: 14), attendu],
          ];
          if (estGrandEcran(context)) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: gauche,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(child: historique),
                ],
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [...gauche, const SizedBox(height: 14), historique],
          );
        },
      ),
    );
  }
}

class _Statut extends StatelessWidget {
  const _Statut({required this.c});
  final EtatCaisseJour c;

  @override
  Widget build(BuildContext context) {
    final couleur = c.ouverte
        ? CouleursZp.argentEntreClair
        : CouleursZp.texteDoux;
    return CarteZp(
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: couleur.withValues(alpha: 0.16),
            child: Icon(
              c.ouverte ? Icons.lock_open_rounded : Icons.lock_rounded,
              color: couleur,
              size: 32,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.ouverte ? 'Caisse ouverte' : 'Caisse fermée',
                  key: const Key('statut-caisse'),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: couleur,
                  ),
                ),
                if (c.ouverte && c.heureOuverture != null)
                  Text(
                    'Depuis ${heureCourte(c.heureOuverture!)} · ${c.ouvertPar ?? ''}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: CouleursZp.texteDoux,
                    ),
                  ),
                if (c.ouverte) ...[
                  const SizedBox(height: 6),
                  const Text(
                    'Fond initial',
                    style: TextStyle(fontSize: 16, color: CouleursZp.texteDoux),
                  ),
                  MontantGeant(
                    c.fonds,
                    key: const Key('fond-initial'),
                    taille: 32,
                  ),
                ] else
                  const Text(
                    'Ouvrez la caisse avant la première vente : comptez l\'argent laissé pour rendre la monnaie.',
                    style: TextStyle(fontSize: 16, color: CouleursZp.texteDoux),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Boutons extends StatelessWidget {
  const _Boutons({
    required this.ouverte,
    required this.patron,
    required this.onOuvrir,
    required this.onDepense,
    required this.onRetrait,
    required this.onFermer,
  });

  final bool ouverte;
  final bool patron;
  final VoidCallback onOuvrir;
  final VoidCallback onDepense;
  final VoidCallback onRetrait;
  final VoidCallback onFermer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!ouverte) ...[
          GrosBouton(
            key: const Key('bouton-ouvrir-caisse'),
            texte: 'Ouvrir la caisse',
            icone: Icons.lock_open_rounded,
            couleur: CouleursZp.argentEntre,
            hauteur: 68,
            onPressed: onOuvrir,
          ),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            Expanded(
              child: GrosBouton(
                key: const Key('bouton-depense'),
                texte: 'Dépense',
                icone: Icons.payments_rounded,
                couleur: CouleursZp.argentSort,
                hauteur: 72,
                onPressed: onDepense,
              ),
            ),
            if (patron) ...[
              const SizedBox(width: 10),
              Expanded(
                child: GrosBouton(
                  key: const Key('bouton-retrait'),
                  texte: 'Argent pris',
                  icone: Icons.account_balance_wallet_rounded,
                  couleur: CouleursZp.argentSort,
                  hauteur: 72,
                  onPressed: onRetrait,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        GrosBouton(
          key: const Key('bouton-fermer-caisse'),
          texte: 'Fermer la caisse',
          icone: Icons.lock_rounded,
          hauteur: 72,
          onPressed: onFermer,
        ),
      ],
    );
  }
}

class _Session extends StatelessWidget {
  const _Session({
    required this.index,
    required this.fermeture,
    required this.etat,
    required this.patron,
  });

  final int index;
  final FermetureCaisse fermeture;
  final EtatApplication etat;
  final bool patron;

  @override
  Widget build(BuildContext context) {
    final f = fermeture;
    final total = ResultatCaisse(attendu: 0, compte: f.ecartTotal);
    final couleur = couleurEcart(total.etat);
    final ecart = switch (total.etat) {
      EtatCaisse.juste => 'Juste',
      EtatCaisse.manque => 'Manque ${formatFrancs(-f.ecartTotal)}',
      EtatCaisse.surplus => 'En plus ${formatFrancs(f.ecartTotal)}',
    };
    return InkWell(
      key: Key('session-$index'),
      borderRadius: BorderRadius.circular(FormesZp.rayonPetit),
      onTap: patron
          ? () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PageResultatFermeture(etat: etat, fermeture: f),
              ),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            const Icon(Icons.lock_rounded, color: CouleursZp.texteDoux),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fermée le ${dateEtHeure(f.heure)}',
                    style: const TextStyle(fontSize: 17),
                  ),
                  Text(
                    'par ${etat.nomDe(f.auteurId)}',
                    style: const TextStyle(
                      fontSize: 15,
                      color: CouleursZp.texteDoux,
                    ),
                  ),
                ],
              ),
            ),
            if (patron)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: couleur.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(FormesZp.rayon),
                ),
                child: Text(
                  ecart,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: couleur,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne({required this.cle, required this.gauche, required this.droite});
  final String cle;
  final String gauche;
  final String droite;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Expanded(child: Text(gauche, style: const TextStyle(fontSize: 18))),
        Text(
          droite,
          key: Key(cle),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}
