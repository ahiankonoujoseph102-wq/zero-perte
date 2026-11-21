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

/// Libellé court d'un motif sur les boutons (le motif enregistré reste
/// complet).
String motifCourt(String m) => switch (m) {
  'Produit abîmé' => 'Abîmé',
  'Le client a changé d\'avis' => 'Changé d\'avis',
  _ => m,
};

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
  /// Lignes de la vente, ce qui a déjà été rendu, et (vente à crédit) ce que
  /// le client doit encore.
  late final Future<(List<LigneRecu>, Map<int, int>, int)> _donnees = () async {
    final lignes = await lignesDuRecu(widget.etat, widget.vente.donnees);
    final deja = await widget.etat.journal.dejaRendus(widget.vente.operationId);
    final client = v.donnees['client'] as String?;
    final dette = _aCredit && client != null
        ? await widget.etat.journal.soldeClient(client)
        : 0;
    return (lignes, deja, dette);
  }();

  final Map<int, int> _rendus = {};
  late ModePaiement _mode = widget.vente.mode;
  String? _motif;
  final _autre = TextEditingController();
  bool _enCours = false;

  /// Ce que le client doit encore (vente à crédit), connu après chargement.
  int _dette = 0;

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

  /// Vente à crédit : part rendue en espèces (la dette ne passe jamais sous 0).
  int get _especesSurCredit {
    if (!_aCredit) return 0;
    final d = _dette < 0 ? 0 : _dette;
    return _total > d ? _total - d : 0;
  }

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
      final especes = op.donnees['rendu_especes'] as int? ?? 0;
      await etat.services.voix.dire(
        _aCredit
            ? (especes > 0
                  ? 'Retour enregistré. Rendez ${montantPourVoix(especes)} en espèces.'
                  : 'Retour enregistré.')
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

  ChoiceChip _puce(
    String cle,
    String texte,
    bool choisi,
    VoidCallback onTap, {
    IconData? icone,
  }) => ChoiceChip(
    key: Key(cle),
    avatar: icone == null ? null : Icon(icone, size: 18),
    label: Text(texte, style: const TextStyle(fontSize: 16)),
    visualDensity: VisualDensity.compact,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    selected: choisi,
    onSelected: (_) => onTap(),
  );

  /// Partie fixe en bas : total, caisse, motif et bouton toujours visibles,
  /// même sur un téléphone de 4 pouces.
  Widget _bas(BuildContext context) {
    final etat = widget.etat;
    final especes = _especesSurCredit;
    // Petit écran (4 à 5 pouces) : libellés courts, sans icônes, pour laisser
    // la place aux articles au-dessus.
    final compact = MediaQuery.sizeOf(context).height < 700;
    final titre = TextStyle(
      fontSize: compact ? 14 : 16,
      fontWeight: FontWeight.w700,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'À rendre au client',
                style: TextStyle(
                  fontSize: compact ? 16 : 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            MontantGeant(
              _total,
              key: const Key('total-retour'),
              couleur: CouleursZp.argentSortClair,
              taille: compact ? 24 : 28,
            ),
          ],
        ),
        if (etat.retourDemandeAccord(_total))
          const Text(
            'Plus de ${seuilAlerteAnnulation ~/ 1000} 000 F : le patron doit donner son accord (son code).',
            key: Key('retour-accord-patron'),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: CouleursZp.creditTexte,
            ),
          ),
        const SizedBox(height: 4),
        if (_aCredit)
          Text(
            especes <= 0
                ? 'Vente à crédit : ce que le client doit va diminuer.'
                : _dette <= 0
                ? 'Le client ne doit plus rien : vous lui rendez '
                      '${formatFrancs(especes)} en espèces.'
                : 'Sa dette tombe à 0 F et vous lui rendez '
                      '${formatFrancs(especes)} en espèces.',
            key: const Key('retour-credit-info'),
            style: TextStyle(
              fontSize: 15,
              fontWeight: especes > 0 ? FontWeight.w700 : FontWeight.w400,
              color: especes > 0 ? CouleursZp.creditTexte : null,
            ),
          )
        else ...[
          Text(
            compact ? 'Rembourser depuis' : 'Rembourser depuis la caisse',
            style: titre,
          ),
          const SizedBox(height: 2),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final m in ModePaiement.caisses)
                _puce(
                  'retour-mode-${m.code}',
                  m == ModePaiement.mixx ? 'Mixx' : nomPaiement(m),
                  _mode == m,
                  () => setState(() => _mode = m),
                  icone: compact ? null : iconePaiement(m),
                ),
            ],
          ),
        ],
        const SizedBox(height: 4),
        Text(
          compact ? 'Pourquoi ?' : 'Pourquoi ? (le patron le verra)',
          style: titre,
        ),
        const SizedBox(height: 2),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final m in motifsRetour)
              _puce(
                'motif-retour-$m',
                compact ? motifCourt(m) : m,
                _motif == m,
                () => setState(() => _motif = m),
              ),
          ],
        ),
        if (_motif == 'Autre') ...[
          const SizedBox(height: 6),
          TextField(
            key: const Key('champ-motif-retour'),
            controller: _autre,
            style: const TextStyle(fontSize: 18),
            decoration: decorationChamp('Écrivez le motif'),
            onChanged: (_) => setState(() {}),
          ),
        ],
        SizedBox(height: compact ? 6 : 8),
        GrosBouton(
          key: const Key('bouton-valider-retour'),
          hauteur: compact ? 52 : 56,
          texte: _total > 0
              ? 'Rendre ${formatFrancs(_total)}'
              : 'Choisissez ce qui revient',
          icone: Icons.assignment_return_rounded,
          couleur: CouleursZp.argentSort,
          onPressed: _total > 0 && _motifFinal != null && !_enCours
              ? _valider
              : null,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PageZp(
      titre: 'Retour · ${v.recu}',
      icone: Icons.assignment_return_rounded,
      bas: _bas(context),
      corps: FutureBuilder<(List<LigneRecu>, Map<int, int>, int)>(
        future: _donnees,
        builder: (context, s) {
          if (!s.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final (lignes, deja, dette) = s.data!;
          if (_dette != dette) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _dette = dette);
            });
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            children: [
              Text(
                'Vente de ${heureCourte(v.heure)} · ${nomPaiement(v.mode)} · ${formatFrancs(v.total)}',
                style: const TextStyle(
                  fontSize: 15,
                  color: CouleursZp.texteDoux,
                ),
              ),
              Text(
                'Qu\'est-ce que le client rend ?',
                style: TextStyle(
                  fontSize: MediaQuery.sizeOf(context).height < 700 ? 17 : 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
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
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
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
                      : [
                          formatFrancs(prix),
                          if (!auMontant) 'vendu : $vendu',
                          if (dejaRendu > 0) 'déjà rendu : $dejaRendu',
                        ].join(' · '),
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
    final especes = retour.donnees['rendu_especes'] as int? ?? 0;
    final baisseDette = retour.total - especes;
    // Lignes rendues décrites avec la quantité RENDUE (« 1 kg de Riz »), pas
    // celle de la vente.
    final rendues = {
      'lignes': [
        for (final l in retour.lignes)
          {
            ...l,
            'conditionnement':
                vente.lignes[l['ligne'] as int]['conditionnement'],
            if (vente.lignes[l['ligne'] as int]['au_montant'] == true)
              'nombre': null,
          },
      ],
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
        future: lignesDuRecu(etat, rendues),
        builder: (context, s) {
          final lignes = s.data ?? const <LigneRecu>[];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                mode != ModePaiement.credit
                    ? 'Rendez au client (${nomPaiement(mode)})'
                    : especes > 0
                    ? 'Rendez au client (Espèces)'
                    : 'Le crédit du client diminue de',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20),
              ),
              Center(
                child: MontantGeant(
                  especes > 0 ? especes : retour.total,
                  key: const Key('retour-a-rendre'),
                  couleur: CouleursZp.argentSortClair,
                  taille: 56,
                ),
              ),
              if (especes > 0)
                Text(
                  baisseDette > 0
                      ? 'Sa dette baisse aussi de ${formatFrancs(baisseDette)} : il ne doit plus rien.'
                      : 'Il ne devait plus rien : tout est rendu en espèces.',
                  key: const Key('retour-especes-credit'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: CouleursZp.creditTexte,
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
                    for (final l in lignes)
                      LigneRecu('Rendu : ${l.libelle}', l.montant),
                  ],
                  libelleTotal: 'RENDU',
                  paiement: '',
                  mention: mode != ModePaiement.credit
                      ? 'Remboursé : ${nomPaiement(mode)}.'
                      : especes > 0
                      ? '${baisseDette > 0 ? 'Dette réduite de ${formatFrancs(baisseDette)}. ' : ''}'
                            'Rendu en espèces : ${formatFrancs(especes)}.'
                      : 'Déduit du crédit du client.',
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
