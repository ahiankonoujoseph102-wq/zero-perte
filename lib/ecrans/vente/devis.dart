import 'package:flutter/material.dart';

import '../../app/etat_application.dart';
import '../../domaine/argent.dart';
import '../../donnees/journal_local.dart';
import '../../theme/couleurs.dart';
import '../accueil_vendeur.dart' show ouvrirVenteAvec;
import '../communs.dart';
import '../recu/apercu_recu.dart';
import '../recu/document_partageable.dart';
import '../recu/recu_vente.dart' show dateRecu;

/// Texte envoyé avec l'image du devis.
String texteDevis(EtatApplication etat, OperationLue d) =>
    'Devis n° ${d.recu} – ${etat.config.nom} : ${formatFrancs(d.total)}. '
    'Valable ${d.donnees['validite_jours'] ?? 7} jours.';

/// Un devis : l'image à envoyer au client, et « Transformer en vente ».
class PageDevis extends StatefulWidget {
  const PageDevis({super.key, required this.etat, required this.devis});

  final EtatApplication etat;
  final OperationLue devis;

  @override
  State<PageDevis> createState() => _PageDevisState();
}

class _PageDevisState extends State<PageDevis> {
  late final Future<String?> _client = () async {
    final id = widget.devis.donnees['client'] as String?;
    if (id == null) return null;
    return (await widget.etat.journal.client(id))?.nom;
  }();

  /// Reçu de la vente si le devis est déjà vendu.
  late final Future<String?> _vendu = widget.etat.journal.devis().then(
    (l) => l.where((e) => e.$1.id == widget.devis.id).firstOrNull?.$2,
  );

  Future<void> _vendre() async {
    final etat = widget.etat;
    final r = await etat.panierDepuisDevis(widget.devis);
    final panier = r.panier;
    if (!mounted) return;
    if (panier.vide) {
      annoncer(context, 'Ces produits n\'existent plus.', erreur: true);
      return;
    }
    if (!r.valable) {
      annoncer(
        context,
        r.totalChange
            ? 'Devis expiré, nouveaux prix : ${formatFrancs(panier.total)}.'
            : 'Devis expiré : prix du jour, total inchangé '
                  '(${formatFrancs(panier.total)}).',
      );
    } else if (r.totalChange) {
      annoncer(
        context,
        'Un produit du devis n\'existe plus : total ${formatFrancs(panier.total)}.',
      );
    }
    await ouvrirVenteAvec(context, etat, panier: panier, devis: widget.devis);
    // Retour de la vente : on ferme le devis (seulement s'il est encore
    // l'écran affiché, pour ne jamais fermer une autre page).
    if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final etat = widget.etat;
    final d = widget.devis;
    final jours = d.donnees['validite_jours'] ?? 7;
    return PageZp(
      titre: 'Devis ${d.recu}',
      icone: Icons.request_quote_rounded,
      bas: FutureBuilder<String?>(
        future: _vendu,
        builder: (context, s) => s.data != null
            ? Text(
                'Déjà vendu (reçu ${s.data}).',
                key: const Key('devis-deja-vendu'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 19,
                  color: CouleursZp.argentEntreClair,
                  fontWeight: FontWeight.w700,
                ),
              )
            : GrosBouton(
                key: const Key('bouton-devis-en-vente'),
                texte: 'Transformer en vente',
                icone: Icons.shopping_basket_rounded,
                couleur: CouleursZp.argentEntre,
                onPressed: s.connectionState == ConnectionState.done
                    ? _vendre
                    : null,
              ),
      ),
      corps: FutureBuilder<String?>(
        future: _client,
        builder: (context, s) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Le devis ne change ni le stock ni la caisse. Envoyez-le au '
              'client ; s\'il achète, touchez « Transformer en vente ».',
              style: TextStyle(fontSize: 17, color: CouleursZp.texteDoux),
            ),
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                final valable = etat.devisValable(d);
                final cree = DateTime.fromMillisecondsSinceEpoch(d.heure);
                final fin = DateTime(
                  cree.year,
                  cree.month,
                  cree.day + (jours as int),
                );
                final date =
                    '${fin.day.toString().padLeft(2, '0')}/${fin.month.toString().padLeft(2, '0')}';
                return Text(
                  valable
                      ? 'Valable jusqu\'au $date : les prix du devis sont gardés.'
                      : 'Expiré depuis le $date : la vente prendra les prix du jour.',
                  key: const Key('devis-validite'),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: valable
                        ? CouleursZp.argentEntreClair
                        : CouleursZp.creditTexte,
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            DocumentPartageable(
              etat: etat,
              cleBouton: 'bouton-envoyer-devis',
              libelleBouton: 'Envoyer le devis sur WhatsApp',
              texte: texteDevis(etat, d),
              child: ApercuRecu(
                config: etat.config,
                titre: 'DEVIS n°',
                numero: d.recu,
                date: dateRecu(d.heure),
                lignes: [
                  for (final l in d.lignes)
                    LigneRecu(l['libelle'] as String? ?? '', l['prix'] as int),
                ],
                paiement: '',
                credit: s.data == null ? null : 'Client : ${s.data}',
                mention:
                    'Facture proforma, valable $jours jours. '
                    'Ce n\'est pas un reçu de paiement.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Liste des devis (patron) : à vendre ou déjà vendus.
class PageListeDevis extends StatefulWidget {
  const PageListeDevis({super.key, required this.etat});

  final EtatApplication etat;

  @override
  State<PageListeDevis> createState() => _PageListeDevisState();
}

class _PageListeDevisState extends State<PageListeDevis> {
  late Future<List<(OperationLue, String?)>> _liste = widget.etat.journal
      .devis();

  @override
  Widget build(BuildContext context) {
    return PageZp(
      titre: 'Devis',
      icone: Icons.request_quote_rounded,
      corps: FutureBuilder<List<(OperationLue, String?)>>(
        future: _liste,
        builder: (context, s) {
          if (!s.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final liste = s.data!;
          if (liste.isEmpty) {
            return const EtatVide(
              icone: Icons.request_quote_rounded,
              titre: 'Aucun devis pour l\'instant.',
              explication:
                  'Un client demande un prix ? Dans « Vendre », remplissez le '
                  'panier puis touchez « Devis » en haut. Il reçoit le devis sur '
                  'WhatsApp et les prix sont gardés 7 jours.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: liste.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final (d, vendu) = liste[i];
              return Material(
                color: CouleursZp.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(FormesZp.rayon),
                  side: const BorderSide(color: CouleursZp.ligne),
                ),
                child: InkWell(
                  key: Key('devis-$i'),
                  borderRadius: BorderRadius.circular(FormesZp.rayon),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PageDevis(etat: widget.etat, devis: d),
                      ),
                    );
                    if (mounted) {
                      setState(() {
                        _liste = widget.etat.journal.devis();
                      });
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.request_quote_rounded,
                          size: 30,
                          color: CouleursZp.texteDoux,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                d.recu,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                vendu == null
                                    ? '${dateRecu(d.heure)} · à vendre'
                                    : '${dateRecu(d.heure)} · vendu ($vendu)',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: vendu == null
                                      ? CouleursZp.texteDoux
                                      : CouleursZp.argentEntreClair,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          formatFrancs(d.total),
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
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
