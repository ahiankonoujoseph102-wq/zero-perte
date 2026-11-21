import 'package:flutter/material.dart';

import '../../app/etat_application.dart';
import '../../donnees/journal_local.dart';
import '../../theme/couleurs.dart';
import '../assistant/etapes_boutique.dart' show decorationChamp;
import '../clavier_montant.dart';
import '../communs.dart';
import '../vente/page_encaisser.dart' show nomPaiement, iconePaiement;

/// Écran générique : une question, un montant (clavier), éventuellement un motif
/// et un moyen de paiement. Sert au fonds de caisse, aux dépenses et aux retraits.
class PageSaisieMontant extends StatefulWidget {
  const PageSaisieMontant({
    super.key,
    required this.titre,
    required this.icone,
    required this.question,
    required this.libelleBouton,
    required this.onValider,
    this.couleur,
    this.avecMode = false,
    this.motifs = const [],
    this.zeroPermis = false,
    this.aide,
  });

  final String titre;
  final IconData icone;
  final String question;
  final String libelleBouton;
  final Color? couleur;
  final bool avecMode;

  /// Motifs proposés (texte + icône) ; si non vide, un motif est obligatoire.
  final List<(String, IconData)> motifs;
  final bool zeroPermis;
  final String? aide;

  /// Enregistre ; renvoie le message de réussite (nul = aucun message,
  /// pour ne pas cacher le bas de l'écran suivant).
  final Future<String?> Function(int montant, ModePaiement mode, String? motif)
  onValider;

  @override
  State<PageSaisieMontant> createState() => _PageSaisieMontantState();
}

class _PageSaisieMontantState extends State<PageSaisieMontant> {
  int _montant = 0;
  ModePaiement _mode = ModePaiement.especes;
  String? _motif;
  bool _autre = false;
  final _texteAutre = TextEditingController();
  bool _enCours = false;

  @override
  void dispose() {
    _texteAutre.dispose();
    super.dispose();
  }

  String? get _motifFinal => _autre
      ? (_texteAutre.text.trim().isEmpty ? null : _texteAutre.text.trim())
      : _motif;

  bool get _peutValider =>
      !_enCours &&
      (_montant > 0 || widget.zeroPermis) &&
      (widget.motifs.isEmpty || _motifFinal != null);

  Future<void> _valider() async {
    setState(() => _enCours = true);
    try {
      final message = await widget.onValider(_montant, _mode, _motifFinal);
      if (!mounted) return;
      if (message != null) annoncer(context, message);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) annoncer(context, messageErreur(e), erreur: true);
      setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageZp(
      titre: widget.titre,
      icone: widget.icone,
      bas: GrosBouton(
        key: const Key('bouton-valider-montant-page'),
        texte: widget.libelleBouton,
        icone: Icons.check_rounded,
        couleur: widget.couleur,
        onPressed: _peutValider ? _valider : null,
      ),
      corps: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        children: [
          Text(
            widget.question,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          if (widget.aide != null)
            Text(
              widget.aide!,
              style: const TextStyle(fontSize: 17, color: CouleursZp.texteDoux),
            ),
          if (widget.motifs.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (m, icone) in widget.motifs)
                  ChoiceChip(
                    key: Key('motif-$m'),
                    avatar: Icon(icone),
                    label: Text(m, style: const TextStyle(fontSize: 17)),
                    selected: !_autre && _motif == m,
                    onSelected: (_) => setState(() {
                      _autre = false;
                      _motif = m;
                    }),
                  ),
                ChoiceChip(
                  key: const Key('motif-Autre'),
                  avatar: const Icon(Icons.edit_rounded),
                  label: const Text('Autre', style: TextStyle(fontSize: 17)),
                  selected: _autre,
                  onSelected: (_) => setState(() => _autre = true),
                ),
              ],
            ),
            if (_autre) ...[
              const SizedBox(height: 10),
              TextField(
                key: const Key('champ-motif-autre'),
                controller: _texteAutre,
                style: const TextStyle(fontSize: 20),
                decoration: decorationChamp('Écrivez le motif'),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ],
          if (widget.avecMode) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in ModePaiement.values)
                  ChoiceChip(
                    key: Key('mode-${m.code}'),
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
          const SizedBox(height: 10),
          if (widget.motifs.isNotEmpty || widget.avecMode)
            Text(
              [
                if (widget.motifs.isNotEmpty)
                  _motifFinal ?? 'Choisissez « pour quoi » en haut',
                if (widget.avecMode) nomPaiement(_mode),
              ].join(' · '),
              key: const Key('rappel-choix'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: widget.motifs.isNotEmpty && _motifFinal == null
                    ? CouleursZp.argentSort
                    : CouleursZp.texteDoux,
              ),
            ),
          Center(
            child: MontantGeant(
              _montant,
              key: const Key('montant-saisi'),
              couleur: widget.couleur ?? CouleursZp.texte,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 260,
            child: ClavierMontant(
              valeur: _montant,
              onChange: (v) => setState(() => _montant = v),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ouverture de la caisse : argent laissé pour rendre la monnaie.
Widget pageOuvrirCaisse(EtatApplication etat) => PageSaisieMontant(
  titre: 'Ouvrir la caisse',
  icone: Icons.point_of_sale_rounded,
  question: 'Combien d\'argent dans la caisse pour rendre la monnaie ?',
  aide: 'Comptez les pièces et billets avant la première vente. 0 s\'il n\'y a rien.',
  libelleBouton: 'Ouvrir la caisse',
  zeroPermis: true,
  onValider: (montant, _, _) async {
    await etat.ouvrirCaisse(montant);
    return null; // l'écran Vendre s'ouvre aussitôt
  },
);

/// Motifs de dépense proposés.
const List<(String, IconData)> motifsDepense = [
  ('Transport', Icons.two_wheeler_rounded),
  ('Repas', Icons.restaurant_rounded),
  ('Électricité, eau', Icons.bolt_rounded),
  ('Loyer', Icons.home_rounded),
  ('Achat de marchandise', Icons.inventory_2_rounded),
  ('Réparation', Icons.build_rounded),
  ('Taxes, mairie', Icons.account_balance_rounded),
  ('Crédit téléphone', Icons.phone_android_rounded),
];

/// Dépense d'argent payée avec la caisse.
Widget pageDepenseArgent(EtatApplication etat) => PageSaisieMontant(
  titre: 'Dépense d\'argent',
  icone: Icons.payments_rounded,
  question: 'Pour quoi ?',
  libelleBouton: 'Enregistrer la dépense',
  couleur: CouleursZp.argentSort,
  avecMode: true,
  motifs: motifsDepense,
  onValider: (montant, mode, motif) async {
    await etat.depenser(montant, motif: motif!, mode: mode);
    return 'Dépense enregistrée.';
  },
);

/// Argent pris par le patron (espace patron).
Widget pageRetraitPatron(EtatApplication etat) => PageSaisieMontant(
  titre: 'Argent pris',
  icone: Icons.account_balance_wallet_rounded,
  question: 'Combien prenez-vous dans la caisse ?',
  aide: 'Notez-le toujours : sinon la caisse paraîtra volée.',
  libelleBouton: 'Enregistrer',
  couleur: CouleursZp.argentSort,
  avecMode: true,
  onValider: (montant, mode, _) async {
    await etat.retraitPatron(montant, mode: mode);
    return 'Retrait enregistré.';
  },
);
