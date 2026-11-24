import 'package:flutter/material.dart';

import '../../app/etat_application.dart';
import '../../domaine/argent.dart';
import '../../donnees/journal_local.dart';
import '../../theme/couleurs.dart';
import '../assistant/etapes_boutique.dart' show decorationChamp;
import '../caisse/fermeture.dart' show dateEtHeure;
import '../caisse/saisie_montant.dart';
import '../communs.dart';

const _ambre = CouleursZp.creditTexte;

/// Espace patron → « Fournisseurs » : ce que la boutique doit à chacun.
class PageFournisseurs extends StatefulWidget {
  const PageFournisseurs({super.key, required this.etat});

  final EtatApplication etat;

  @override
  State<PageFournisseurs> createState() => _PageFournisseursState();
}

class _PageFournisseursState extends State<PageFournisseurs> {
  late Future<List<Fournisseur>> _liste = widget.etat.fournisseurs();

  void _recharger() {
    if (!mounted) return;
    setState(() {
      _liste = widget.etat.fournisseurs();
    });
  }

  @override
  void initState() {
    super.initState();
    widget.etat.addListener(_recharger);
  }

  @override
  void dispose() {
    widget.etat.removeListener(_recharger);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageZp(
      titre: 'Ce que je dois',
      icone: Icons.handshake_rounded,
      bas: GrosBouton(
        key: const Key('bouton-nouveau-fournisseur'),
        texte: 'Nouveau fournisseur',
        icone: Icons.add_business_rounded,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PageNouveauFournisseur(etat: widget.etat),
          ),
        ),
      ),
      corps: FutureBuilder<List<Fournisseur>>(
        future: _liste,
        builder: (context, s) {
          if (!s.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final liste = s.data!;
          if (liste.isEmpty) {
            return const EtatVide(
              icone: Icons.handshake_rounded,
              titre: 'Aucun fournisseur pour l\'instant.',
              explication:
                  'Ajoutez vos grossistes : vous saurez toujours combien vous '
                  'leur devez, et leur numéro est au même endroit.',
            );
          }
          final total = liste.fold<int>(0, (t, f) => t + f.doit);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: CouleursZp.credit.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'La boutique doit en tout',
                        style: TextStyle(fontSize: 17),
                      ),
                    ),
                    Text(
                      formatFrancs(total),
                      key: const Key('total-fournisseurs'),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: CouleursZp.creditTexte,
                      ),
                    ),
                  ],
                ),
              ),
              for (final f in liste)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: CouleursZp.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(FormesZp.rayon),
                      side: const BorderSide(color: CouleursZp.ligne),
                    ),
                    child: ListTile(
                      key: Key('fournisseur-${f.nom}'),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      leading: const Icon(
                        Icons.local_shipping_rounded,
                        size: 32,
                      ),
                      title: Text(
                        f.nom,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        f.doit > 0
                            ? 'On lui doit ${formatFrancs(f.doit)}'
                            : 'On ne lui doit rien',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: f.doit > 0 ? _ambre : CouleursZp.argentEntre,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PageFournisseur(
                            etat: widget.etat,
                            fournisseurId: f.id,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class PageNouveauFournisseur extends StatefulWidget {
  const PageNouveauFournisseur({super.key, required this.etat});

  final EtatApplication etat;

  @override
  State<PageNouveauFournisseur> createState() => _PageNouveauFournisseurState();
}

class _PageNouveauFournisseurState extends State<PageNouveauFournisseur> {
  final _nom = TextEditingController();
  final _tel = TextEditingController();

  @override
  void dispose() {
    _nom.dispose();
    _tel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageZp(
      titre: 'Nouveau fournisseur',
      icone: Icons.add_business_rounded,
      bas: GrosBouton(
        key: const Key('bouton-enregistrer-fournisseur'),
        texte: 'Enregistrer',
        icone: Icons.check_rounded,
        onPressed: _nom.text.trim().isEmpty
            ? null
            : () async {
                try {
                  await widget.etat.ajouterFournisseur(
                    nom: _nom.text,
                    telephone: _tel.text,
                  );
                  if (context.mounted) Navigator.of(context).pop();
                } catch (e) {
                  if (context.mounted) {
                    annoncer(context, messageErreur(e), erreur: true);
                  }
                }
              },
      ),
      corps: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            key: const Key('champ-nom-fournisseur'),
            controller: _nom,
            style: const TextStyle(fontSize: 21),
            textCapitalization: TextCapitalization.words,
            decoration: decorationChamp('Nom', icone: Icons.store_rounded),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('champ-telephone-fournisseur'),
            controller: _tel,
            keyboardType: TextInputType.phone,
            style: const TextStyle(fontSize: 21),
            decoration: decorationChamp(
              'Téléphone (facultatif)',
              icone: Icons.phone_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

/// Fiche d'un fournisseur : ce qu'on lui doit, achat à crédit, paiement.
class PageFournisseur extends StatefulWidget {
  const PageFournisseur({
    super.key,
    required this.etat,
    required this.fournisseurId,
  });

  final EtatApplication etat;
  final String fournisseurId;

  @override
  State<PageFournisseur> createState() => _PageFournisseurState();
}

class _PageFournisseurState extends State<PageFournisseur> {
  late Future<(Fournisseur?, List<(int, int, String?)>)> _donnees = _charger();

  Future<(Fournisseur?, List<(int, int, String?)>)> _charger() async => (
    (await widget.etat.fournisseurs())
        .where((f) => f.id == widget.fournisseurId)
        .firstOrNull,
    await widget.etat.journal.historiqueFournisseur(widget.fournisseurId),
  );

  void _recharger() {
    if (!mounted) return;
    setState(() {
      _donnees = _charger();
    });
  }

  @override
  void initState() {
    super.initState();
    widget.etat.addListener(_recharger);
  }

  @override
  void dispose() {
    widget.etat.removeListener(_recharger);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(Fournisseur?, List<(int, int, String?)>)>(
      future: _donnees,
      builder: (context, s) {
        final f = s.data?.$1;
        if (f == null) {
          return const PageZp(
            titre: 'Fournisseur',
            icone: Icons.handshake_rounded,
            corps: Center(child: CircularProgressIndicator()),
          );
        }
        final h = s.data!.$2;
        return PageZp(
          titre: f.nom,
          icone: Icons.handshake_rounded,
          bas: GrosBouton(
            key: const Key('bouton-payer-fournisseur'),
            texte: 'Je paie',
            icone: Icons.payments_rounded,
            couleur: CouleursZp.argentSort,
            onPressed: f.doit <= 0
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PageSaisieMontant(
                        titre: 'Payer ${f.nom}',
                        icone: Icons.payments_rounded,
                        question: 'Combien payez-vous ?',
                        aide:
                            'On lui doit ${formatFrancs(f.doit)}. L\'argent sort de la caisse.',
                        libelleBouton: 'Enregistrer le paiement',
                        couleur: CouleursZp.argentSort,
                        avecMode: true,
                        onValider: (montant, mode, _) async {
                          await widget.etat.payerFournisseur(
                            f,
                            montant,
                            mode: mode,
                          );
                          return null; // la fiche montre le nouveau montant
                        },
                      ),
                    ),
                  ),
          ),
          corps: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                f.doit > 0
                    ? 'On lui doit ${formatFrancs(f.doit)}'
                    : 'On ne lui doit rien',
                key: const Key('doit-fournisseur'),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: f.doit > 0 ? _ambre : CouleursZp.argentEntre,
                ),
              ),
              if (f.telephone.isNotEmpty)
                Text(f.telephone, style: const TextStyle(fontSize: 17)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('bouton-achat-credit'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PageSaisieMontant(
                      titre: 'Achat à crédit',
                      icone: Icons.add_shopping_cart_rounded,
                      question: 'Montant de la marchandise prise à crédit ?',
                      aide: 'Pensez aussi à enregistrer l\'arrivage pour le stock.',
                      libelleBouton: 'Enregistrer la dette',
                      couleur: _ambre,
                      onValider: (montant, _, _) async {
                        await widget.etat.achatFournisseur(f, montant);
                        return null; // la fiche montre le nouveau montant
                      },
                    ),
                  ),
                ),
                icon: const Icon(Icons.add_shopping_cart_rounded),
                label: const Text(
                  'Achat à crédit',
                  style: TextStyle(fontSize: 18),
                ),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 56)),
              ),
              const SizedBox(height: 16),
              const Text(
                'Historique',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
              ),
              for (final (heure, montant, note) in h)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(
                        montant > 0
                            ? Icons.add_shopping_cart_rounded
                            : Icons.payments_rounded,
                        color: montant > 0 ? _ambre : CouleursZp.argentEntre,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${dateEtHeure(heure)} · ${montant > 0 ? 'Achat à crédit' : 'Paiement'}'
                          '${note == null ? '' : ' ($note)'}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      Text(
                        '${montant > 0 ? '+' : '−'} ${formatFrancs(montant.abs())}',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: montant > 0 ? _ambre : CouleursZp.argentEntre,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
