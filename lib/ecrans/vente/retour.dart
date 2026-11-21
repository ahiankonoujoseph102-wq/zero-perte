import 'package:flutter/material.dart';

import '../../app/etat_application.dart';
import '../../domaine/argent.dart';
import '../../donnees/journal_local.dart';
import '../../synchro/relais.dart' show seuilAlerteAnnulation;
import '../../theme/couleurs.dart';
import '../assistant/etapes_boutique.dart' show decorationChamp;
import '../clavier_montant.dart';
import '../communs.dart';
import '../recu/apercu_recu.dart';
import '../recu/document_partageable.dart';
import '../recu/recu_vente.dart' show dateRecu, lignesDuRecu;
import 'page_encaisser.dart' show nomPaiement, iconePaiement;
import 'ventes_du_jour.dart' show heureCourte;

/// Motifs de retour proposés (« Autre » permet d'écrire le sien).
const List<String> motifsRetour = [
  'Produit abîmé',
  'Mauvais produit',
  'Le client a changé d\'avis',
  'Autre',
];

/// Part d'une ligne rendue ([n] unités sur [vendu]) : même calcul que le journal.
int partRendue(int valeur, int n, int vendu) =>
    n == vendu ? valeur : valeur * n ~/ vendu;

/// Retour partiel : le client rend une partie de ce qu'il a acheté.
/// La marchandise revient en stock, l'argent sort de la caisse choisie (ou le
/// crédit du client diminue). Au-delà de 5 000 F, l'accord du patron (son
/// code) est demandé au vendeur.
class PageRetour extends StatefulWidget {
  const PageRetour({super.key, required this.etat, required this.vente});

  final EtatApplication etat;
  final VenteResume vente;

  @override
  State<PageRetour> createState() => _PageRetourState();
}

class _PageRetourState extends State<PageRetour> {
  late final Future<(List<LigneRecu>, Map<int, int>)> _donnees = () async {
    final lignes = await lignesDuRecu(widget.etat, widget.vente.donnees);
    final deja = await widget.etat.journal.dejaRendus(widget.vente.operationId);
    return (lignes, deja);
  }();

  final Map<int, int> _rendus = {};
  late ModePaiement _mode = widget.vente.mode;
  String? _motif;
  final _autre = TextEditingController();
  bool _enCours = false;

  VenteResume get v => widget.vente;
  bool get _aCredit => v.mode == ModePaiement.credit;

  @override
  void dispose() {
    _autre.dispose();
    super.dispose();
  }

  int _vendu(int i) {
    final l = v.lignes[i];
    return l['au_montant'] == true ? 1 : (l['nombre'] as int? ?? 1);
  }

  int get _total => _rendus.entries.fold(
    0,
    (s, e) =>
        s +
        partRendue(
          v.lignes[e.key]['prix_total'] as int,
          e.value,
          _vendu(e.key),
        ),
  );

  String? get _motifFinal => _motif == 'Autre'
      ? (_autre.text.trim().isEmpty ? null : _autre.text)
      : _motif;

  Future<void> _valider() async {
    final etat = widget.etat;
    final motif = _motifFinal;
    if (motif == null || _total <= 0) return;
    String? accord;
    if (etat.retourDemandeAccord(_total) && etat.patron != null) {
      final ok = await demanderPin(
        context,
        etat,
        etat.patron!,
        titre: 'Accord du patron (retour de ${formatFrancs(_total)})',
        connecter: false,
      );
      if (!ok || !mounted) return;
      accord = etat.patron!.id;
    }
    setState(() => _enCours = true);
    try {
      final op = await etat.retournerVente(
        v,
        rendus: {
          for (final e in _rendus.entries)
            if (e.value > 0) e.key: e.value,
        },
        mode: _mode,
        motif: motif,
        accordPatronId: accord,
      );
      await etat.services.voix.dire(
        _aCredit
            ? 'Retour enregistré.'
            : 'Retour enregistré. Rendez ${montantPourVoix(op.total)}.',
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PageRetourTermine(etat: etat, vente: v, retour: op),
        ),
      );
    } catch (e) {
      if (mounted) {
        annoncer(context, messageErreur(e), erreur: true);
        setState(() => _enCours = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final etat = widget.etat;
    return PageZp(
      titre: 'Retour · ${v.recu}',
      icone: Icons.assignment_return_rounded,
      bas: GrosBouton(
        key: const Key('bouton-valider-retour'),
        texte: _total > 0
            ? 'Rendre ${formatFrancs(_total)}'
            : 'Choisissez ce qui revient',
        icone: Icons.assignment_return_rounded,
        couleur: CouleursZp.argentSort,
        onPressed: _total > 0 && _motifFinal != null && !_enCours
            ? _valider
            : null,
      ),
      corps: FutureBuilder<(List<LigneRecu>, Map<int, int>)>(
        future: _donnees,
        builder: (context, s) {
          if (!s.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final (lignes, deja) = s.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Vente de ${heureCourte(v.heure)} · ${nomPaiement(v.mode)} · ${formatFrancs(v.total)}',
                style: const TextStyle(
                  fontSize: 17,
                  color: CouleursZp.texteDoux,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Qu\'est-ce que le client rend ?',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < lignes.length; i++)
                _LigneRetour(
                  index: i,
                  libelle: lignes[i].libelle,
                  prix: lignes[i].montant,
                  vendu: _vendu(i),
                  dejaRendu: deja[i] ?? 0,
                  auMontant: v.lignes[i]['au_montant'] == true,
                  rendu: _rendus[i] ?? 0,
                  onChange: (n) => setState(() => _rendus[i] = n),
                ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: CouleursZp.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: CouleursZp.ligne),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'À rendre au client',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    MontantGeant(
                      _total,
                      key: const Key('total-retour'),
                      couleur: CouleursZp.argentSortClair,
                      taille: 34,
                    ),
                  ],
                ),
              ),
              if (etat.retourDemandeAccord(_total))
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Plus de ${seuilAlerteAnnulation ~/ 1000} 000 F : le patron doit donner son accord (son code).',
                    key: Key('retour-accord-patron'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: CouleursZp.creditTexte,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              if (_aCredit)
                const Text(
                  'Vente à crédit : ce que le client doit va diminuer.',
                  style: TextStyle(fontSize: 18),
                )
              else ...[
                const Text(
                  'Rembourser depuis la caisse',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final m in ModePaiement.caisses)
                      ChoiceChip(
                        key: Key('retour-mode-${m.code}'),
                        avatar: Icon(iconePaiement(m)),
                        label: Text(
                          nomPaiement(m),
                          style: const TextStyle(fontSize: 17),
                        ),
                        selected: _mode == m,
                        onSelected: (_) => setState(() => _mode = m),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              const Text(
                'Pourquoi ? (le patron le verra)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in motifsRetour)
                    ChoiceChip(
                      key: Key('motif-retour-$m'),
                      label: Text(m, style: const TextStyle(fontSize: 17)),
                      selected: _motif == m,
                      onSelected: (_) => setState(() => _motif = m),
                    ),
                ],
              ),
              if (_motif == 'Autre') ...[
                const SizedBox(height: 8),
                TextField(
                  key: const Key('champ-motif-retour'),
                  controller: _autre,
                  style: const TextStyle(fontSize: 19),
                  decoration: decorationChamp('Écrivez le motif'),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _LigneRetour extends StatelessWidget {
  const _LigneRetour({
    required this.index,
    required this.libelle,
    required this.prix,
    required this.vendu,
    required this.dejaRendu,
    required this.auMontant,
    required this.rendu,
    required this.onChange,
  });

  final int index;
  final String libelle;
  final int prix;
  final int vendu;
  final int dejaRendu;
  final bool auMontant;
  final int rendu;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    final reste = vendu - dejaRendu;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: CouleursZp.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: rendu > 0 ? CouleursZp.argentSort : CouleursZp.ligne,
          width: rendu > 0 ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  libelle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  reste <= 0
                      ? 'Déjà rendu'
                      : dejaRendu > 0
                      ? '${formatFrancs(prix)} · déjà rendu : $dejaRendu'
                      : formatFrancs(prix),
                  style: const TextStyle(
                    fontSize: 15,
                    color: CouleursZp.texteDoux,
                  ),
                ),
              ],
            ),
          ),
          if (reste > 0) ...[
            IconButton.outlined(
              key: Key('retour-moins-$index'),
              onPressed: rendu > 0 ? () => onChange(rendu - 1) : null,
              icon: const Icon(Icons.remove_rounded),
            ),
            SizedBox(
              width: 44,
              child: Text(
                auMontant ? (rendu > 0 ? 'Tout' : '0') : '$rendu',
                key: Key('retour-nombre-$index'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton.filledTonal(
              key: Key('retour-plus-$index'),
              onPressed: rendu < reste ? () => onChange(rendu + 1) : null,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ],
      ),
    );
  }
}

/// Retour enregistré : l'argent à rendre en grand, et le reçu du retour.
class PageRetourTermine extends StatelessWidget {
  const PageRetourTermine({
    super.key,
    required this.etat,
    required this.vente,
    required this.retour,
  });

  final EtatApplication etat;
  final VenteResume vente;
  final OperationLue retour;

  @override
  Widget build(BuildContext context) {
    final mode = ModePaiement.depuisCode(
      retour.donnees['mode_paiement'] as String,
    );
    final rendusParLigne = {
      for (final l in retour.lignes) l['ligne'] as int: l['prix_total'] as int,
    };
    return PageZp(
      titre: 'Retour enregistré',
      icone: Icons.check_circle_rounded,
      bas: GrosBouton(
        key: const Key('bouton-fin-retour'),
        texte: 'Terminé',
        icone: Icons.check_rounded,
        onPressed: () => Navigator.of(context).pop(true),
      ),
      corps: FutureBuilder<List<LigneRecu>>(
        future: lignesDuRecu(etat, vente.donnees),
        builder: (context, s) {
          final lignes = s.data ?? const <LigneRecu>[];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                mode == ModePaiement.credit
                    ? 'Le crédit du client diminue de'
                    : 'Rendez au client (${nomPaiement(mode)})',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20),
              ),
              Center(
                child: MontantGeant(
                  retour.total,
                  key: const Key('retour-a-rendre'),
                  couleur: CouleursZp.argentSortClair,
                  taille: 56,
                ),
              ),
              const SizedBox(height: 16),
              DocumentPartageable(
                etat: etat,
                cleBouton: 'bouton-envoyer-recu-retour',
                libelleBouton: 'Envoyer le reçu du retour sur WhatsApp',
                texte:
                    'Retour sur le reçu n° ${vente.recu} – ${etat.config.nom} : '
                    '${formatFrancs(retour.total)} rendus.',
                child: ApercuRecu(
                  config: etat.config,
                  titre: 'Retour · reçu n°',
                  numero: vente.recu,
                  date: dateRecu(retour.heure),
                  lignes: [
                    for (final e in rendusParLigne.entries)
                      if (e.key < lignes.length)
                        LigneRecu('Rendu : ${lignes[e.key].libelle}', e.value),
                  ],
                  libelleTotal: 'RENDU',
                  paiement: '',
                  mention: mode == ModePaiement.credit
                      ? 'Déduit du crédit du client.'
                      : 'Remboursé : ${nomPaiement(mode)}.',
                  demo: etat.estDemo,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Tous les retours (patron) : qui, quand, combien, pourquoi, accord.
class PageRetours extends StatelessWidget {
  const PageRetours({super.key, required this.etat});

  final EtatApplication etat;

  @override
  Widget build(BuildContext context) {
    return PageZp(
      titre: 'Retours',
      icone: Icons.assignment_return_rounded,
      corps: FutureBuilder<List<OperationLue>>(
        future: etat.journal.retours(),
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
                  'Aucun retour pour l\'instant.',
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
              final r = liste[i];
              final mode = ModePaiement.depuisCode(
                r.donnees['mode_paiement'] as String,
              );
              final accord = r.donnees['accord'] as String?;
              return Container(
                key: Key('retour-$i'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: CouleursZp.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: CouleursZp.ligne),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.assignment_return_rounded,
                      color: CouleursZp.argentSortClair,
                      size: 30,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reçu ${r.recu} · ${etat.nomDe(r.auteurId)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${dateRecu(r.heure)} · ${nomPaiement(mode)} · « ${r.donnees['motif']} »',
                            style: const TextStyle(
                              fontSize: 15,
                              color: CouleursZp.texteDoux,
                            ),
                          ),
                          if (accord != null && accord != r.auteurId)
                            Text(
                              'Accord : ${etat.nomDe(accord)}',
                              style: const TextStyle(
                                fontSize: 15,
                                color: CouleursZp.creditTexte,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      '− ${formatFrancs(r.total)}',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: CouleursZp.argentSortClair,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
