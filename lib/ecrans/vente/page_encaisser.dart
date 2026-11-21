import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/etat_application.dart';
import '../../domaine/argent.dart';
import '../../domaine/panier.dart';
import '../../donnees/journal_local.dart';
import '../../theme/couleurs.dart';
import '../assistant/etapes_boutique.dart' show decorationChamp;
import '../clavier_montant.dart';
import '../recu/recu_vente.dart';
import '../communs.dart';
import '../credit/clients.dart';

/// Nom affiché d'un moyen de paiement (« Mixx » = l'ancien T-Money).
String nomPaiement(ModePaiement m) => switch (m) {
  ModePaiement.especes => 'Espèces',
  ModePaiement.flooz => 'Flooz',
  ModePaiement.mixx => 'Mixx (T-Money)',
  ModePaiement.credit => 'Crédit',
};

IconData iconePaiement(ModePaiement m) => switch (m) {
  ModePaiement.especes => Icons.payments_rounded,
  ModePaiement.credit => Icons.menu_book_rounded,
  _ => Icons.phone_android_rounded,
};

/// Encaissement : moyen de paiement, argent reçu, monnaie à rendre.
class PageEncaisser extends StatefulWidget {
  const PageEncaisser({super.key, required this.etat, required this.panier});

  final EtatApplication etat;
  final Panier panier;

  @override
  State<PageEncaisser> createState() => _PageEncaisserState();
}

class _PageEncaisserState extends State<PageEncaisser> {
  ModePaiement _mode = ModePaiement.especes;
  int _recu = 0;
  final _reference = TextEditingController();
  bool _enCours = false;

  /// Client qui prend à crédit (mode « Crédit »).
  Client? _client;

  int get _total => widget.panier.total;

  @override
  void initState() {
    super.initState();
    widget.etat.services.voix.dire('À payer : ${montantPourVoix(_total)}');
  }

  @override
  void dispose() {
    _reference.dispose();
    super.dispose();
  }

  bool get _peutValider => switch (_mode) {
    ModePaiement.especes => _recu >= _total,
    ModePaiement.credit =>
      _client != null && _client!.solde + _total <= _client!.plafond,
    _ => true,
  };

  Future<void> _choisirClient() async {
    final c = await Navigator.of(context).push<Client>(
      MaterialPageRoute(
        builder: (_) => PageClients(etat: widget.etat, choisir: true),
      ),
    );
    if (c != null && mounted) setState(() => _client = c);
  }

  Future<void> _valider() async {
    setState(() => _enCours = true);
    try {
      final vente = await widget.etat.vendre(
        widget.panier,
        mode: _mode,
        montantRecu: _mode == ModePaiement.especes ? _recu : null,
        reference: _mode == ModePaiement.credit ? null : _reference.text,
        clientId: _mode == ModePaiement.credit ? _client?.id : null,
      );
      final rendre = vente.monnaie?.aRendre ?? 0;
      await widget.etat.services.voix.dire(
        rendre > 0
            ? 'Vente enregistrée. Rendez ${montantPourVoix(rendre)}.'
            : 'Vente enregistrée.',
      );
      if (!mounted) return;
      final nouvelle = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) =>
              PageVenteTerminee(etat: widget.etat, vente: vente, mode: _mode),
        ),
      );
      if (mounted) Navigator.of(context).pop(nouvelle ?? true);
    } catch (e) {
      if (mounted) annoncer(context, messageErreur(e), erreur: true);
      setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final monnaie = calculerMonnaie(total: _total, recu: _recu);
    return PageZp(
      titre: 'Encaisser',
      icone: Icons.payments_rounded,
      bas: GrosBouton(
        key: const Key('bouton-valider-vente'),
        texte: 'Valider la vente',
        icone: Icons.check_rounded,
        couleur: CouleursZp.argentEntre,
        hauteur: 68,
        onPressed: _peutValider && !_enCours ? _valider : null,
      ),
      corps: LayoutBuilder(
        builder: (context, contraintes) {
          // Le clavier garde au moins 200 points ; sur un très petit écran la
          // page défile un peu plutôt que de déborder.
          final hauteurClavier =
              (contraintes.maxHeight - (_recu > 0 ? 330 : 220)).clamp(
                200.0,
                340.0,
              );
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // À payer | Le client donne : toujours visibles ensemble.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Flexible(
                                child: Text(
                                  'À payer',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 17,
                                    color: CouleursZp.texteDoux,
                                  ),
                                ),
                              ),
                              IconButton(
                                key: const Key('bouton-ecouter-total'),
                                visualDensity: VisualDensity.compact,
                                tooltip: 'Écouter',
                                onPressed: () => widget.etat.services.voix.dire(
                                  'À payer : ${montantPourVoix(_total)}',
                                ),
                                icon: const Icon(Icons.volume_up_rounded),
                              ),
                            ],
                          ),
                          MontantGeant(
                            _total,
                            key: const Key('a-payer'),
                            couleur: CouleursZp.argentEntre,
                            taille: 40,
                          ),
                        ],
                      ),
                    ),
                    if (_mode == ModePaiement.especes) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(bottom: 12),
                              child: Text(
                                'Le client donne',
                                style: TextStyle(
                                  fontSize: 17,
                                  color: CouleursZp.texteDoux,
                                ),
                              ),
                            ),
                            MontantGeant(
                              _recu,
                              key: const Key('montant-recu'),
                              taille: 40,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (final m in ModePaiement.values)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: _BoutonMode(
                            mode: m,
                            choisi: m == _mode,
                            onTap: () => setState(() => _mode = m),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_mode == ModePaiement.especes) ...[
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        ActionChip(
                          key: const Key('rapide-exact'),
                          avatar: const Icon(Icons.done_all_rounded),
                          label: const Text(
                            'Compte exact',
                            style: TextStyle(fontSize: 17),
                          ),
                          onPressed: () => setState(() => _recu = _total),
                        ),
                        for (final b in const [500, 1000, 2000, 5000, 10000])
                          if (b > _total || b == 10000)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: ActionChip(
                                key: Key('rapide-$b'),
                                label: Text(
                                  formatFrancs(b),
                                  style: const TextStyle(fontSize: 17),
                                ),
                                onPressed: () => setState(() => _recu = b),
                              ),
                            ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_recu > 0) _ResultatMonnaie(monnaie: monnaie),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: hauteurClavier,
                    child: ClavierMontant(
                      valeur: _recu,
                      onChange: (v) => setState(() => _recu = v),
                    ),
                  ),
                ] else if (_mode == ModePaiement.credit)
                  _ChoixClientCredit(
                    client: _client,
                    total: _total,
                    onChoisir: _choisirClient,
                  )
                else
                  SizedBox(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: CouleursZp.credit.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.sms_rounded,
                                size: 32,
                                color: CouleursZp.texteSurCredit,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Vérifiez le message ${nomPaiement(_mode)} reçu : montant ${formatFrancs(_total)}.',
                                  style: const TextStyle(fontSize: 18),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          key: const Key('champ-reference'),
                          controller: _reference,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(12),
                          ],
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                          decoration: decorationChamp(
                            '4 derniers chiffres de la transaction',
                            icone: Icons.tag_rounded,
                            aide: 'Facultatif, mais aide le patron à vérifier.',
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Vente à crédit : le client choisi, ce qu'il devra, ou le bouton pour le choisir.
class _ChoixClientCredit extends StatelessWidget {
  const _ChoixClientCredit({
    required this.client,
    required this.total,
    required this.onChoisir,
  });

  final Client? client;
  final int total;
  final VoidCallback onChoisir;

  @override
  Widget build(BuildContext context) {
    final c = client;
    if (c == null) {
      return GrosBouton(
        key: const Key('bouton-choisir-client'),
        texte: 'Choisir le client',
        icone: Icons.person_search_rounded,
        couleur: CouleursZp.credit,
        onPressed: onChoisir,
      );
    }
    final apres = c.solde + total;
    final trop = apres > c.plafond;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CouleursZp.credit.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: trop ? CouleursZp.argentSort : CouleursZp.credit,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AvatarClient(client: c),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  c.nom,
                  key: const Key('client-choisi'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                key: const Key('bouton-changer-client'),
                onPressed: onChoisir,
                child: const Text('Changer', style: TextStyle(fontSize: 17)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            trop
                ? 'Plafond dépassé : il peut encore prendre ${formatFrancs(c.disponible)}.'
                : 'Après cette vente, il devra ${formatFrancs(apres)}.',
            key: const Key('credit-apres'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: trop ? CouleursZp.argentSort : CouleursZp.texteSurCredit,
            ),
          ),
        ],
      ),
    );
  }
}

class _BoutonMode extends StatelessWidget {
  const _BoutonMode({
    required this.mode,
    required this.choisi,
    required this.onTap,
  });

  final ModePaiement mode;
  final bool choisi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final couleur = Theme.of(context).colorScheme.primary;
    return Material(
      color: choisi ? couleur : CouleursZp.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: choisi ? couleur : CouleursZp.ligne, width: 2),
      ),
      child: InkWell(
        key: Key('mode-${mode.code}'),
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          height: 66,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                children: [
                  Icon(
                    iconePaiement(mode),
                    size: 30,
                    color: choisi ? Colors.white : CouleursZp.texte,
                  ),
                  Text(
                    // Nom court sur le bouton (« Mixx » : la place manque).
                    mode == ModePaiement.mixx ? 'Mixx' : nomPaiement(mode),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: choisi ? Colors.white : CouleursZp.texte,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultatMonnaie extends StatelessWidget {
  const _ResultatMonnaie({required this.monnaie});
  final MonnaieARendre monnaie;

  @override
  Widget build(BuildContext context) {
    if (!monnaie.suffisant) {
      return Container(
        key: const Key('il-manque'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: CouleursZp.argentSort.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: CouleursZp.argentSort, width: 2),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.error_rounded,
              color: CouleursZp.argentSort,
              size: 30,
            ),
            const SizedBox(width: 8),
            const Text('Il manque', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(
              child: MontantGeant(
                monnaie.manque,
                couleur: CouleursZp.argentSort,
                taille: 30,
              ),
            ),
          ],
        ),
      );
    }
    final d = decomposerEnCoupures(monnaie.aRendre);
    return Container(
      key: const Key('a-rendre'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CouleursZp.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CouleursZp.ligne, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                'Rendre',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 10),
              Expanded(child: MontantGeant(monnaie.aRendre, taille: 40)),
            ],
          ),
          if (d.coupures.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final e in d.coupures.entries)
                  Chip(
                    avatar: Icon(
                      e.key >= 500 && e.key != 500
                          ? Icons.money_rounded
                          : Icons.circle,
                      size: 18,
                    ),
                    label: Text(
                      '${e.value} × ${formatFrancs(e.key)}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Après la vente : numéro du reçu et monnaie à rendre en très grand.
class PageVenteTerminee extends StatelessWidget {
  const PageVenteTerminee({
    super.key,
    required this.etat,
    required this.vente,
    required this.mode,
  });

  final EtatApplication etat;
  final VenteEnregistree vente;
  final ModePaiement mode;

  @override
  Widget build(BuildContext context) {
    final rendre = vente.monnaie?.aRendre ?? 0;
    return PageZp(
      titre: 'Vente enregistrée',
      icone: Icons.check_circle_rounded,
      bas: GrosBouton(
        key: const Key('bouton-nouvelle-vente'),
        texte: 'Nouvelle vente',
        icone: Icons.shopping_basket_rounded,
        couleur: CouleursZp.argentEntre,
        onPressed: () => Navigator.of(context).pop(true),
      ),
      corps: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 96,
            color: CouleursZp.argentEntre,
          ),
          const SizedBox(height: 8),
          Text(
            'Reçu n° ${vente.recu}',
            key: const Key('numero-recu'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '${formatFrancs(vente.total)} · ${nomPaiement(mode)}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, color: CouleursZp.texteDoux),
          ),
          if (rendre > 0) ...[
            const SizedBox(height: 24),
            const Text(
              'Rendez au client',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22),
            ),
            Center(
              child: MontantGeant(
                rendre,
                key: const Key('rendre-final'),
                taille: 60,
              ),
            ),
          ],
          const SizedBox(height: 24),
          RecuPartageable(
            etat: etat,
            donnees: vente.operation.donnees,
            heure: vente.operation.heureTelephone,
          ),
        ],
      ),
    );
  }
}
