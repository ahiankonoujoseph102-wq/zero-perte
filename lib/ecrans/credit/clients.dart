import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'retards.dart';
import '../../app/etat_application.dart';
import '../../domaine/argent.dart';
import '../../donnees/journal_local.dart';
import '../../services/partage.dart';
import '../../theme/couleurs.dart';
import '../assistant/etapes_boutique.dart' show decorationChamp;
import '../caisse/fermeture.dart' show dateEtHeure;
import '../caisse/saisie_montant.dart';
import '../communs.dart';
import '../connexion.dart' show Avatar;
import '../logo_boutique.dart';
import '../recu/capture.dart';

/// Photo ronde du client, ou ses initiales.
class AvatarClient extends StatelessWidget {
  const AvatarClient({super.key, required this.client, this.taille = 52});

  final Client client;
  final double taille;

  @override
  Widget build(BuildContext context) {
    final photo = client.photo;
    if (photo != null) {
      return ClipOval(
        child: Image.memory(
          base64.decode(photo),
          width: taille,
          height: taille,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      );
    }
    return Avatar(nom: client.nom, taille: taille);
  }
}

/// « Doit 1 800 F » (ambre) ou « Ne doit rien » (vert).
Widget texteSolde(Client c, {double taille = 17, Key? key}) => Text(
  c.solde > 0 ? 'Doit ${formatFrancs(c.solde)}' : 'Ne doit rien',
  key: key,
  style: TextStyle(
    fontSize: taille,
    fontWeight: FontWeight.w700,
    color: c.solde > 0 ? CouleursZp.creditTexte : CouleursZp.argentEntre,
  ),
);

/// Liste des clients (bouton « Crédit » de l'accueil). Avec [choisir], toucher
/// un client le renvoie (vente à crédit).
class PageClients extends StatefulWidget {
  const PageClients({
    super.key,
    required this.etat,
    this.choisir = false,
    this.pourCredit = true,
  });

  final EtatApplication etat;
  final bool choisir;

  /// En mode [choisir] : le client doit pouvoir prendre à crédit (téléphone).
  final bool pourCredit;

  @override
  State<PageClients> createState() => _PageClientsState();
}

class _PageClientsState extends State<PageClients> {
  late Future<List<Client>> _clients = widget.etat.clients();
  late Future<List<(Client, int)>> _retards = _chargerRetards();
  final _recherche = TextEditingController();

  Future<List<(Client, int)>> _chargerRetards() =>
      widget.choisir || !widget.etat.voitTout
      ? Future.value(const [])
      : widget.etat.creditsEnRetard();

  void _recharger() {
    if (!mounted) return;
    setState(() {
      _clients = widget.etat.clients();
      _retards = _chargerRetards();
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
    _recherche.dispose();
    super.dispose();
  }

  Future<void> _exporter() async {
    try {
      final csv = await widget.etat.exporterClientsCsv();
      // BOM UTF-8 : les accents s'affichent bien dans Excel.
      final octets = Uint8List.fromList([
        0xEF,
        0xBB,
        0xBF,
        ...utf8.encode(csv),
      ]);
      final r = await widget.etat.services.partagerFichier(
        octets,
        'clients.csv',
      );
      if (r == ResultatPartage.echec && mounted) {
        annoncer(context, 'L\'export n\'a pas pu être envoyé.', erreur: true);
      }
    } catch (e) {
      if (mounted) annoncer(context, messageErreur(e), erreur: true);
    }
  }

  Future<void> _nouveau() async {
    final id = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => PageFicheEdition(etat: widget.etat)),
    );
    if (id == null || !mounted || !widget.choisir) return;
    final c = await widget.etat.journal.client(id);
    if (c != null && mounted) Navigator.of(context).pop(c);
  }

  @override
  Widget build(BuildContext context) {
    return PageZp(
      titre: widget.choisir ? 'Quel client ?' : 'Ce qu\'on me doit',
      icone: Icons.menu_book_rounded,
      bas: GrosBouton(
        key: const Key('bouton-nouveau-client'),
        texte: 'Nouveau client',
        icone: Icons.person_add_rounded,
        onPressed: _nouveau,
      ),
      corps: FutureBuilder<List<Client>>(
        future: _clients,
        builder: (context, s) {
          if (!s.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final tous = s.data!;
          if (tous.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Aucun client pour l\'instant.\nTouchez « Nouveau client ».',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20),
                ),
              ),
            );
          }
          final filtre = _recherche.text.trim().toLowerCase();
          final liste = filtre.isEmpty
              ? tous
              : tous
                    .where(
                      (c) =>
                          c.nom.toLowerCase().contains(filtre) ||
                          (filtre.replaceAll(RegExp(r'[^0-9]'), '').length >=
                                  2 &&
                              c.telephone
                                  .replaceAll(RegExp(r'[^0-9]'), '')
                                  .contains(
                                    filtre.replaceAll(RegExp(r'[^0-9]'), ''),
                                  )),
                    )
                    .toList();
          final total = tous.fold<int>(0, (t, c) => t + c.solde);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (!widget.choisir && widget.etat.voitTout)
                FutureBuilder<List<(Client, int)>>(
                  future: _retards,
                  builder: (context, r) {
                    final n = r.data?.length ?? 0;
                    if (n == 0) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Material(
                        color: CouleursZp.argentSort.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          key: const Key('bandeau-retards'),
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  PageCreditsEnRetard(etat: widget.etat),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.schedule_rounded,
                                  color: CouleursZp.argentSort,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '$n crédit${n > 1 ? 's' : ''} en retard : '
                                    'rappeler en un toucher',
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              if (!widget.choisir)
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
                          'Les clients doivent en tout',
                          style: TextStyle(fontSize: 17),
                        ),
                      ),
                      Text(
                        formatFrancs(total),
                        key: const Key('total-credits'),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: CouleursZp.creditTexte,
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('recherche-client'),
                        controller: _recherche,
                        style: const TextStyle(fontSize: 19),
                        decoration: decorationChamp(
                          'Nom ou téléphone',
                          icone: Icons.search_rounded,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    if (widget.etat.estPatron && !widget.choisir) ...[
                      const SizedBox(width: 8),
                      IconButton.outlined(
                        key: const Key('bouton-exporter-clients'),
                        tooltip: 'Exporter les clients',
                        iconSize: 30,
                        onPressed: _exporter,
                        icon: const Icon(Icons.ios_share_rounded),
                      ),
                    ],
                  ],
                ),
              ),
              for (final c in liste)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: CouleursZp.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: CouleursZp.ligne),
                    ),
                    child: InkWell(
                      key: Key('client-${c.nom}'),
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => widget.choisir
                          ? (c.peutPrendreCredit || !widget.pourCredit
                                ? Navigator.of(context).pop(c)
                                : annoncer(
                                    context,
                                    'Ajoutez d\'abord le téléphone de ${c.nom} (obligatoire pour le crédit).',
                                    erreur: true,
                                  ))
                          : Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => PageClient(
                                  etat: widget.etat,
                                  clientId: c.id,
                                ),
                              ),
                            ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          children: [
                            AvatarClient(client: c),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c.nom,
                                    style: const TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  texteSolde(c),
                                  if (widget.choisir &&
                                      widget.pourCredit &&
                                      !c.peutPrendreCredit)
                                    const Text(
                                      'Téléphone manquant',
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: CouleursZp.argentSort,
                                      ),
                                    )
                                  else if (widget.choisir && widget.pourCredit)
                                    Text(
                                      'Peut encore prendre ${formatFrancs(c.disponible)}',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        color: CouleursZp.texteDoux,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded),
                          ],
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

/// Création ou modification d'une fiche client. Renvoie l'identifiant.
class PageFicheEdition extends StatefulWidget {
  const PageFicheEdition({super.key, required this.etat, this.existant});

  final EtatApplication etat;
  final Client? existant;

  @override
  State<PageFicheEdition> createState() => _PageFicheEditionState();
}

class _PageFicheEditionState extends State<PageFicheEdition> {
  late final _nom = TextEditingController(text: widget.existant?.nom ?? '');
  late final _tel = TextEditingController(
    text: widget.existant?.telephone ?? '',
  );
  late final _quartier = TextEditingController(
    text: widget.existant?.quartier ?? '',
  );
  late final _email = TextEditingController(text: widget.existant?.email ?? '');
  late int _plafond =
      widget.existant?.plafond ?? EtatApplication.plafondParDefaut;
  String? _photo;
  bool _enCours = false;

  @override
  void dispose() {
    _nom.dispose();
    _tel.dispose();
    _quartier.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _prendrePhoto() async {
    final octets = await widget.etat.services.prendrePhoto(
      SourcePhoto.appareil,
    );
    if (octets != null && mounted) {
      setState(() => _photo = base64.encode(octets));
    }
  }

  Future<void> _enregistrer() async {
    setState(() => _enCours = true);
    try {
      final id = await widget.etat.enregistrerClient(
        existant: widget.existant,
        nom: _nom.text,
        telephone: _tel.text,
        quartier: _quartier.text,
        email: _email.text,
        photo: _photo,
        plafond: _plafond,
      );
      if (!mounted) return;
      annoncer(context, '${_nom.text.trim()} est enregistré.');
      Navigator.of(context).pop(id);
    } catch (e) {
      if (mounted) annoncer(context, messageErreur(e), erreur: true);
      setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final patron = widget.etat.estPatron;
    final photo = _photo ?? widget.existant?.photo;
    return PageZp(
      titre: widget.existant == null ? 'Nouveau client' : 'Modifier le client',
      icone: Icons.person_add_rounded,
      bas: GrosBouton(
        key: const Key('bouton-enregistrer-client'),
        texte: 'Enregistrer',
        icone: Icons.check_rounded,
        onPressed: _enCours || _nom.text.trim().isEmpty ? null : _enregistrer,
      ),
      corps: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: InkWell(
              key: const Key('bouton-photo-client'),
              customBorder: const CircleBorder(),
              onTap: _prendrePhoto,
              child: CircleAvatar(
                radius: 48,
                backgroundColor: CouleursZp.marquePale,
                backgroundImage: photo == null
                    ? null
                    : MemoryImage(base64.decode(photo)),
                child: photo == null
                    ? const Icon(Icons.add_a_photo_rounded, size: 40)
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Photo (pour reconnaître le client)',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: CouleursZp.texteDoux),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('champ-nom-client'),
            controller: _nom,
            style: const TextStyle(fontSize: 21),
            textCapitalization: TextCapitalization.words,
            decoration: decorationChamp('Nom', icone: Icons.person_rounded),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('champ-telephone-client'),
            controller: _tel,
            keyboardType: TextInputType.phone,
            style: const TextStyle(fontSize: 21),
            decoration: decorationChamp(
              'Téléphone (WhatsApp)',
              icone: Icons.phone_rounded,
              aide: 'Obligatoire pour faire crédit.',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('champ-quartier-client'),
            controller: _quartier,
            style: const TextStyle(fontSize: 21),
            textCapitalization: TextCapitalization.words,
            decoration: decorationChamp(
              'Quartier (facultatif)',
              icone: Icons.place_rounded,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('champ-email-client'),
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(fontSize: 21),
            decoration: decorationChamp(
              'E-mail (facultatif)',
              icone: Icons.alternate_email_rounded,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Il peut devoir au maximum',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          if (patron)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in EtatApplication.plafondsProposes)
                  ChoiceChip(
                    key: Key('plafond-$p'),
                    label: Text(
                      formatFrancs(p),
                      style: const TextStyle(fontSize: 17),
                    ),
                    selected: _plafond == p,
                    onSelected: (_) => setState(() => _plafond = p),
                  ),
              ],
            )
          else
            Text(
              '${formatFrancs(_plafond)} (seul le patron peut changer ce montant)',
              key: const Key('plafond-fixe'),
              style: const TextStyle(fontSize: 17, color: CouleursZp.texteDoux),
            ),
        ],
      ),
    );
  }
}

/// Fiche d'un client : ce qu'il doit, remboursement, rappel, historique.
class PageClient extends StatefulWidget {
  const PageClient({super.key, required this.etat, required this.clientId});

  final EtatApplication etat;
  final String clientId;

  @override
  State<PageClient> createState() => _PageClientState();
}

class _PageClientState extends State<PageClient> {
  late Future<(Client?, List<MouvementCredit>)> _donnees = _charger();

  Future<(Client?, List<MouvementCredit>)> _charger() async => (
    await widget.etat.journal.client(widget.clientId),
    await widget.etat.journal.historiqueCredit(widget.clientId),
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

  Future<void> _rembourser(Client c) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PageSaisieMontant(
          titre: 'Remboursement',
          icone: Icons.savings_rounded,
          question: 'Combien ${c.nom} donne-t-il ?',
          aide: 'Il doit ${formatFrancs(c.solde)}.',
          libelleBouton: 'Enregistrer le remboursement',
          couleur: CouleursZp.argentEntre,
          avecMode: true,
          onValider: (montant, mode, _) async {
            await widget.etat.rembourser(c, montant, mode: mode);
            return null;
          },
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final apres = await widget.etat.journal.client(c.id);
    final h = await widget.etat.journal.historiqueCredit(c.id);
    if (!mounted || apres == null || h.isEmpty) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PageRemboursementFait(
          etat: widget.etat,
          client: apres,
          mouvement: h.first,
        ),
      ),
    );
  }

  Future<void> _supprimer(Client c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Supprimer ${c.nom} ?',
          style: const TextStyle(fontSize: 22),
        ),
        content: const Text(
          'Il ne sera plus dans la liste. Son historique reste gardé.',
          style: TextStyle(fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Non', style: TextStyle(fontSize: 18)),
          ),
          FilledButton(
            key: const Key('confirmer-suppression'),
            style: FilledButton.styleFrom(
              backgroundColor: CouleursZp.argentSort,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Supprimer', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await widget.etat.supprimerClient(c);
      if (!mounted) return;
      annoncer(context, '${c.nom} est supprimé.');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) annoncer(context, messageErreur(e), erreur: true);
    }
  }

  Future<void> _rappeler(Client c) async {
    final lien = widget.etat.lienRappel(c);
    if (lien == null) return;
    final ok = await widget.etat.services.ouvrirLien(lien);
    if (!ok && mounted) {
      annoncer(context, 'WhatsApp ne s\'ouvre pas.', erreur: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(Client?, List<MouvementCredit>)>(
      future: _donnees,
      builder: (context, s) {
        final c = s.data?.$1;
        if (c == null) {
          return const PageZp(
            titre: 'Client',
            icone: Icons.person_rounded,
            corps: Center(child: CircularProgressIndicator()),
          );
        }
        final h = s.data!.$2;
        final peutRappeler = c.solde > 0 && widget.etat.lienRappel(c) != null;
        return PageZp(
          titre: c.nom,
          icone: Icons.person_rounded,
          bas: GrosBouton(
            key: const Key('bouton-rembourse'),
            texte: 'Il rembourse',
            icone: Icons.savings_rounded,
            couleur: CouleursZp.argentEntre,
            onPressed: c.solde > 0 ? () => _rembourser(c) : null,
          ),
          corps: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  AvatarClient(client: c, taille: 72),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        texteSolde(
                          c,
                          taille: 24,
                          key: const Key('solde-client'),
                        ),
                        Text(
                          c.plafond == 0
                              ? 'Plus de crédit (décision du patron)'
                              : 'Peut encore prendre ${formatFrancs(c.disponible)}',
                          style: const TextStyle(
                            fontSize: 16,
                            color: CouleursZp.texteDoux,
                          ),
                        ),
                        if (c.telephone.isNotEmpty)
                          Text(
                            c.telephone,
                            style: const TextStyle(fontSize: 16),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    key: const Key('bouton-rappeler'),
                    onPressed: peutRappeler ? () => _rappeler(c) : null,
                    icon: const Icon(Icons.notifications_active_rounded),
                    label: const Text(
                      'Rappeler sur WhatsApp',
                      style: TextStyle(fontSize: 17),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 52),
                    ),
                  ),
                  if (widget.etat.estPatron)
                    OutlinedButton.icon(
                      key: const Key('bouton-modifier-client'),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              PageFicheEdition(etat: widget.etat, existant: c),
                        ),
                      ),
                      icon: const Icon(Icons.edit_rounded),
                      label: const Text(
                        'Modifier',
                        style: TextStyle(fontSize: 17),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 52),
                      ),
                    ),
                  if (widget.etat.estPatron)
                    OutlinedButton.icon(
                      key: const Key('bouton-credit-arret'),
                      onPressed: () async {
                        await widget.etat.changerCredit(
                          c,
                          autorise: c.plafond == 0,
                        );
                        if (context.mounted) {
                          annoncer(
                            context,
                            c.plafond == 0
                                ? '${c.nom} peut de nouveau prendre à crédit.'
                                : 'Plus de crédit pour ${c.nom}.',
                          );
                        }
                      },
                      icon: Icon(
                        c.plafond == 0
                            ? Icons.lock_open_rounded
                            : Icons.block_rounded,
                      ),
                      label: Text(
                        c.plafond == 0
                            ? 'Refaire crédit'
                            : 'Ne plus faire crédit',
                        style: const TextStyle(fontSize: 17),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 52),
                        foregroundColor: c.plafond == 0
                            ? CouleursZp.argentEntre
                            : CouleursZp.argentSort,
                      ),
                    ),
                  if (widget.etat.estPatron)
                    OutlinedButton.icon(
                      key: const Key('bouton-supprimer-client'),
                      onPressed: () => _supprimer(c),
                      icon: const Icon(Icons.delete_rounded),
                      label: const Text(
                        'Supprimer',
                        style: TextStyle(fontSize: 17),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 52),
                        foregroundColor: CouleursZp.argentSort,
                      ),
                    ),
                ],
              ),
              if (c.quartier.isNotEmpty || c.email.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    [
                      c.quartier,
                      c.email,
                    ].where((t) => t.isNotEmpty).join(' · '),
                    style: const TextStyle(
                      fontSize: 16,
                      color: CouleursZp.texteDoux,
                    ),
                  ),
                ),
              if (c.solde > 0 && c.telephone.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'Ajoutez son numéro pour pouvoir le rappeler.',
                    style: TextStyle(fontSize: 15, color: CouleursZp.texteDoux),
                  ),
                ),
              const SizedBox(height: 16),
              const Text(
                'Historique',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
              ),
              if (h.isEmpty)
                const Text(
                  'Rien pour l\'instant.',
                  style: TextStyle(fontSize: 17, color: CouleursZp.texteDoux),
                ),
              for (final m in h)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(
                        m.montant > 0
                            ? Icons.shopping_basket_rounded
                            : Icons.savings_rounded,
                        color: m.montant > 0
                            ? CouleursZp.creditTexte
                            : CouleursZp.argentEntre,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${dateEtHeure(m.heure)} · ${switch (m.nature) {
                            'vente' => 'Achat ${m.recu ?? ''}',
                            'annulation' => 'Achat annulé ${m.recu ?? ''}',
                            _ => 'Remboursement',
                          }}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      Text(
                        '${m.montant > 0 ? '+' : '−'} ${formatFrancs(m.montant.abs())}',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: m.montant > 0
                              ? CouleursZp.creditTexte
                              : CouleursZp.argentEntre,
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

/// Après un remboursement : le reçu, à envoyer au client sur WhatsApp.
class PageRemboursementFait extends StatefulWidget {
  const PageRemboursementFait({
    super.key,
    required this.etat,
    required this.client,
    required this.mouvement,
  });

  final EtatApplication etat;
  final Client client;
  final MouvementCredit mouvement;

  @override
  State<PageRemboursementFait> createState() => _PageRemboursementFaitState();
}

class _PageRemboursementFaitState extends State<PageRemboursementFait> {
  final _cadre = GlobalKey();
  bool _enCours = false;

  String get _texte =>
      '${widget.etat.config.nom} : ${widget.client.nom} a remboursé '
      '${formatFrancs(-widget.mouvement.montant)}. Reste à payer : '
      '${formatFrancs(widget.client.solde)}. Merci !';

  Future<void> _envoyer() async {
    setState(() => _enCours = true);
    try {
      final png = await capturerPng(_cadre);
      if (png == null) return;
      final r = await widget.etat.services.partagerImage(png, _texte);
      if (r == ResultatPartage.echec && mounted) {
        annoncer(context, 'Impossible d\'envoyer le reçu.', erreur: true);
      } else if (r == ResultatPartage.enregistre && mounted) {
        annoncer(
          context,
          'Reçu enregistré dans Documents › Zero Perte › Recus. '
          'Joignez-le dans WhatsApp (le texte est déjà copié).',
        );
      }
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.etat.config;
    final m = widget.mouvement;
    return PageZp(
      titre: 'Remboursement',
      icone: Icons.check_circle_rounded,
      bas: GrosBouton(
        key: const Key('bouton-fin-remboursement'),
        texte: 'Terminé',
        icone: Icons.check_rounded,
        onPressed: () => Navigator.of(context).pop(),
      ),
      corps: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          OutlinedButton.icon(
            key: const Key('bouton-envoyer-recu'),
            onPressed: _enCours ? null : _envoyer,
            icon: const Icon(Icons.send_rounded),
            label: const Text(
              'Envoyer le reçu sur WhatsApp',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 60),
              foregroundColor: CouleursZp.argentEntre,
              side: const BorderSide(color: CouleursZp.argentEntre, width: 2),
            ),
          ),
          const SizedBox(height: 12),
          RepaintBoundary(
            key: _cadre,
            child: DefaultTextStyle.merge(
              style: const TextStyle(color: CouleursRecu.texte),
              child: ColoredBox(
                color: CouleursRecu.cadre,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Container(
                    key: const Key('recu-remboursement'),
                    decoration: BoxDecoration(
                      color: CouleursRecu.fond,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          color: Color(config.couleur),
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              LogoBoutique(config: config, taille: 44),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  config.nom,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Remboursement · ${dateEtHeure(m.heure)}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: CouleursRecu.texteDoux,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                widget.client.nom,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Divider(height: 20),
                              _ligne(
                                'A payé',
                                formatFrancs(-m.montant),
                                CouleursRecu.vert,
                              ),
                              _ligne(
                                'Reste à payer',
                                formatFrancs(widget.client.solde),
                                widget.client.solde > 0
                                    ? CouleursRecu.ambre
                                    : CouleursRecu.vert,
                                cle: 'reste-a-payer',
                              ),
                              const SizedBox(height: 8),
                              Text(
                                config.messageRecu,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ligne(String a, String b, Color couleur, {String? cle}) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Expanded(child: Text(a, style: const TextStyle(fontSize: 18))),
        Text(
          b,
          key: cle == null ? null : Key(cle),
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            color: couleur,
          ),
        ),
      ],
    ),
  );
}
