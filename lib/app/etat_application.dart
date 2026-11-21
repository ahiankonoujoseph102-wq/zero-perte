import 'package:flutter/foundation.dart';

import '../domaine/argent.dart';
import '../domaine/boutique.dart';
import '../domaine/catalogue.dart';
import '../domaine/licence.dart';
import '../domaine/operation.dart';
import '../domaine/panier.dart';
import '../domaine/quantites.dart';
import '../domaine/sauvegarde.dart';
import '../domaine/tableau.dart';
import '../domaine/utilisateurs.dart';
import '../donnees/journal_local.dart';
import '../services/partage.dart';
import '../services/aide.dart';
import '../services/telephone.dart';
import '../services/voix.dart';

/// Origine d'une photo.
enum SourcePhoto { appareil, galerie }

/// Services extérieurs (téléphone, voix, liens, photos…), remplaçables dans les tests.
class ServicesZp {
  const ServicesZp({
    required this.telephone,
    required this.voix,
    required this.ouvrirLien,
    required this.lirePressePapiers,
    required this.clePublique,
    required this.lireCatalogue,
    required this.prendrePhoto,
    required this.creerRaccourci,
    required this.partagerImage,
    required this.partagerFichier,
  });

  final ServiceTelephone telephone;
  final Voix voix;
  final OuvreurDeLien ouvrirLien;

  /// Lit le texte copié (code d'activation reçu sur WhatsApp).
  final Future<String?> Function() lirePressePapiers;

  /// Clé publique des licences (32 octets), nulle si absente de cette version.
  final Future<List<int>?> Function() clePublique;

  /// Texte JSON du catalogue prérempli.
  final Future<String> Function() lireCatalogue;

  /// Prend ou choisit une photo, déjà réduite (JPEG), ou nul si annulé.
  final Future<Uint8List?> Function(SourcePhoto source) prendrePhoto;

  /// Demande à Android d'ajouter un raccourci (nom + image PNG) sur l'écran d'accueil.
  /// Faux si le téléphone ne le permet pas.
  final Future<bool> Function(String nom, Uint8List png) creerRaccourci;

  /// Envoie une image (reçu) dans WhatsApp, ou par le menu de partage.
  final Future<ResultatPartage> Function(Uint8List png, String texte)
  partagerImage;

  /// Partage un fichier (sauvegarde) par le menu de partage d'Android.
  final Future<ResultatPartage> Function(Uint8List octets, String nom)
  partagerFichier;
}

/// Étapes de l'assistant d'installation, dans l'ordre.
enum EtapeAssistant {
  bienvenue,
  verification,
  activation,
  typeBoutique,
  identite,
  contact,
  couleur,
  produits,
  prix,
  recu,
  codePatron,
  fin,
  termine,
}

const _cleEtape = 'assistant.etape';

/// État global de l'application.
class EtatApplication extends ChangeNotifier {
  EtatApplication._(
    this.journal,
    this.services,
    this._etape,
    this._codes,
    this._config,
    this._utilisateurs,
    this.catalogue,
    this._produits,
  );

  /// Charge l'état (reprend l'assistant là où il s'était arrêté).
  static Future<EtatApplication> charger({
    required JournalLocal journal,
    required ServicesZp services,
  }) async {
    final nom = await journal.lireParametre(_cleEtape);
    final etape =
        EtapeAssistant.values.where((e) => e.name == nom).firstOrNull ??
        EtapeAssistant.bienvenue;
    Catalogue catalogue;
    try {
      catalogue = Catalogue.depuisJson(await services.lireCatalogue());
    } catch (_) {
      catalogue = const Catalogue([]);
    }
    final etat = EtatApplication._(
      journal,
      services,
      etape,
      await journal.codesActives(),
      await journal.configuration() ?? const ConfigBoutique(),
      await journal.utilisateurs(),
      catalogue,
      await journal.produits(),
    );
    etat._stocks = await journal.stocks();
    return etat;
  }

  final JournalLocal journal;
  final ServicesZp services;
  final Catalogue catalogue;

  // ---------------------------------------------------------------------------
  // Assistant
  // ---------------------------------------------------------------------------

  EtapeAssistant _etape;
  EtapeAssistant get etape => _etape;

  bool get installationTerminee => _etape == EtapeAssistant.termine;

  /// Passe à une étape et la mémorise (reprise après interruption).
  Future<void> allerA(EtapeAssistant etape) async {
    _etape = etape;
    await journal.ecrireParametre(_cleEtape, etape.name);
    notifyListeners();
  }

  /// Étape suivante de l'assistant.
  Future<void> suivante() => allerA(
    EtapeAssistant.values[(_etape.index + 1).clamp(
      0,
      EtapeAssistant.values.length - 1,
    )],
  );

  /// Étape précédente de l'assistant.
  Future<void> precedente() => allerA(
    EtapeAssistant.values[(_etape.index - 1).clamp(
      0,
      EtapeAssistant.values.length - 1,
    )],
  );

  // ---------------------------------------------------------------------------
  // Licence
  // ---------------------------------------------------------------------------

  final List<CodeActivation> _codes;

  /// Licence de la boutique, nulle tant qu'aucun code n'a été activé.
  Licence? get licence => calculerLicence(_codes);

  /// Vérifie un code collé, le contrôle par rapport à la licence actuelle, puis
  /// l'enregistre dans le journal. Lève [ErreurCode] avec un message simple.
  Future<CodeActivation> activer(String texteColle) async {
    final code = await verifierCode(texteColle, await services.clePublique());
    controlerNouveauCode(code, licence);
    await journal.enregistrerActivation(code, auteurId: auteurActuel);
    _codes.add(code);
    // Le nom donné à l'activation sert de nom de boutique par défaut.
    if (_config.nom.isEmpty && code.nomBoutique.isNotEmpty) {
      await enregistrerConfig(_config.copie(nom: code.nomBoutique));
    }
    notifyListeners();
    return code;
  }

  // ---------------------------------------------------------------------------
  // Boutique
  // ---------------------------------------------------------------------------

  ConfigBoutique _config;
  ConfigBoutique get config => _config;

  /// Enregistre une nouvelle version de la configuration de la boutique.
  Future<void> enregistrerConfig(ConfigBoutique c) async {
    await journal.configurerBoutique(c, auteurId: auteurActuel);
    _config = c;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Utilisateurs
  // ---------------------------------------------------------------------------

  List<Utilisateur> _utilisateurs;
  List<Utilisateur> get utilisateurs => List.unmodifiable(_utilisateurs);
  Utilisateur? get patron =>
      _utilisateurs.where((u) => u.role == Role.patron).firstOrNull;

  /// Auteur des opérations faites pendant l'installation (le patron, s'il existe).
  String get auteurActuel =>
      _utilisateurActuel?.id ?? patron?.id ?? 'installation';

  /// Crée le patron avec son code secret (ou le remplace).
  Future<Utilisateur> definirPatron({
    required String nom,
    required String pin,
  }) async {
    final probleme = problemePin(pin);
    if (probleme != null) throw ErreurZeroPerte(probleme);
    final sel = nouveauSel();
    final u = Utilisateur(
      id: patron?.id ?? nouvelIdentifiant(),
      nom: nom.trim().isEmpty ? 'Patron' : nom.trim(),
      role: Role.patron,
      sel: sel,
      hachage: await hacherPin(pin, sel),
    );
    await journal.definirUtilisateur(u, auteurId: u.id);
    _utilisateurs = await journal.utilisateurs();
    // Le patron qui vient de choisir son code est connecté.
    _utilisateurActuel = u;
    notifyListeners();
    return u;
  }

  /// Vendeurs (actifs et bloqués).
  List<Utilisateur> get vendeurs =>
      _utilisateurs.where((u) => u.role == Role.vendeur).toList();

  /// Ajoute un vendeur avec son code secret (choisi par lui).
  Future<Utilisateur> ajouterVendeur({
    required String nom,
    required String pin,
  }) async {
    if (nom.trim().isEmpty) {
      throw const ErreurZeroPerte('Écrivez le prénom du vendeur.');
    }
    final probleme = problemePin(pin);
    if (probleme != null) throw ErreurZeroPerte(probleme);
    final sel = nouveauSel();
    final u = Utilisateur(
      id: nouvelIdentifiant(),
      nom: nom.trim(),
      role: Role.vendeur,
      sel: sel,
      hachage: await hacherPin(pin, sel),
    );
    await journal.definirUtilisateur(u, auteurId: auteurActuel);
    _utilisateurs = await journal.utilisateurs();
    notifyListeners();
    return u;
  }

  /// Bloque ou débloque un vendeur (nouvelle version ; l'historique reste).
  Future<void> bloquer(Utilisateur u, {required bool bloque}) async {
    await journal.definirUtilisateur(
      Utilisateur(
        id: u.id,
        nom: u.nom,
        role: u.role,
        sel: u.sel,
        hachage: u.hachage,
        actif: !bloque,
      ),
      auteurId: auteurActuel,
    );
    _utilisateurs = await journal.utilisateurs();
    if (bloque && _utilisateurActuel?.id == u.id) _utilisateurActuel = null;
    notifyListeners();
  }

  /// Change le code secret d'un utilisateur.
  Future<void> changerPin(Utilisateur u, String pin) async {
    final probleme = problemePin(pin);
    if (probleme != null) throw ErreurZeroPerte(probleme);
    final sel = nouveauSel();
    await journal.definirUtilisateur(
      Utilisateur(
        id: u.id,
        nom: u.nom,
        role: u.role,
        sel: sel,
        hachage: await hacherPin(pin, sel),
        actif: u.actif,
      ),
      auteurId: auteurActuel,
    );
    _utilisateurs = await journal.utilisateurs();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Session : qui utilise le téléphone
  // ---------------------------------------------------------------------------

  Utilisateur? _utilisateurActuel;

  /// Personne connectée (patron ou vendeur), nulle si personne.
  Utilisateur? get utilisateurActuel => _utilisateurActuel;

  /// Nombre d'erreurs de PIN autorisées avant blocage.
  static const int essaisPin = 5;

  /// Durée du blocage après trop d'erreurs.
  static const Duration dureeBlocagePin = Duration(minutes: 5);

  final Map<String, int> _erreursPin = {};

  /// Heure jusqu'à laquelle le PIN de [u] est bloqué (nulle si pas bloqué).
  Future<DateTime?> pinBloqueJusqua(Utilisateur u) async {
    final t = int.tryParse(
      await journal.lireParametre('pin.blocage.${u.id}') ?? '',
    );
    if (t == null) return null;
    final fin = DateTime.fromMillisecondsSinceEpoch(t);
    return fin.isAfter(maintenant()) ? fin : null;
  }

  /// Horloge (remplaçable dans les tests).
  DateTime Function() maintenant = DateTime.now;

  /// Vérifie le PIN de [u]. Après [essaisPin] erreurs, bloque [dureeBlocagePin].
  /// Renvoie vrai si le PIN est bon (et connecte l'utilisateur si [connecter]).
  Future<bool> verifierPin(
    Utilisateur u,
    String pin, {
    bool connecter = true,
  }) async {
    if (!u.actif) return false;
    if (await pinBloqueJusqua(u) != null) return false;
    if (await pinCorrect(u, pin)) {
      _erreursPin.remove(u.id);
      if (connecter) {
        _utilisateurActuel = u;
        notifyListeners();
      }
      return true;
    }
    final n = (_erreursPin[u.id] ?? 0) + 1;
    _erreursPin[u.id] = n;
    if (n >= essaisPin) {
      _erreursPin.remove(u.id);
      await journal.ecrireParametre(
        'pin.blocage.${u.id}',
        '${maintenant().add(dureeBlocagePin).millisecondsSinceEpoch}',
      );
    }
    return false;
  }

  Duration get dureeBlocage => dureeBlocagePin;

  /// Erreurs restantes avant blocage.
  int essaisRestants(Utilisateur u) => essaisPin - (_erreursPin[u.id] ?? 0);

  /// Déconnecte la personne actuelle (changement d'utilisateur).
  void deconnecter() {
    _utilisateurActuel = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Produits
  // ---------------------------------------------------------------------------

  List<Produit> _produits;
  List<Produit> get produits => List.unmodifiable(_produits);

  Map<String, int> _stocks = {};

  /// Stock d'un produit (millièmes d'unité de base).
  int stock(String produitId) => _stocks[produitId] ?? 0;

  Future<void> rechargerProduits() async {
    _produits = await journal.produits();
    _stocks = await journal.stocks();
    notifyListeners();
  }

  /// Enregistre une vente (le panier n'est pas vidé ici). Lève [ErreurZeroPerte]
  /// si l'argent reçu ne suffit pas.
  Future<VenteEnregistree> vendre(
    Panier panier, {
    required ModePaiement mode,
    int? montantRecu,
    String? reference,
    String? clientId,
  }) async {
    final vente = await journal.enregistrerVente(
      clientId: clientId,
      lignes: [
        for (final l in panier.lignes)
          l.auMontant
              ? LigneDemandee.auMontant(
                  produitId: l.produitId,
                  montant: l.montant!,
                )
              : LigneDemandee.quantite(
                  produitId: l.produitId,
                  conditionnementId: l.conditionnement?.id,
                  nombre: l.nombre!,
                ),
      ],
      mode: mode,
      montantRecu: montantRecu,
      referencePaiement: (reference ?? '').trim().isEmpty
          ? null
          : reference!.trim(),
      auteurId: auteurActuel,
    );
    await rechargerProduits();
    return vente;
  }

  /// Début de la journée en cours (minuit, heure du téléphone).
  int get debutDuJour {
    final m = maintenant();
    return DateTime(m.year, m.month, m.day).millisecondsSinceEpoch;
  }

  /// Ventes du jour (les plus récentes d'abord).
  Future<List<VenteResume>> ventesDuJour() => journal.ventesDepuis(debutDuJour);

  /// Annule une vente (motif obligatoire) : la marchandise revient, l'argent sort de la caisse.
  Future<void> annulerVente(VenteResume v, String motif) async {
    await journal.annulerVente(
      venteOperationId: v.operationId,
      motif: motif,
      auteurId: auteurActuel,
    );
    await rechargerProduits();
  }

  /// Perte déclarée (casse, périmé…) : [nombre] unités de [conditionnement] (ou de base).
  Future<void> declarerPerte({
    required Produit produit,
    Conditionnement? conditionnement,
    required int nombre,
    required String motif,
  }) async {
    final milliemes = conditionnement == null
        ? nombre * milliemesParUnite
        : versMilliemes(nombre, conditionnement);
    await journal.enregistrerPerte(
      produitId: produit.id,
      milliemes: milliemes,
      motif: motif,
      auteurId: auteurActuel,
    );
    await rechargerProduits();
  }

  /// Vrai si la caisse a été ouverte (fonds de caisse) depuis la dernière fermeture.
  Future<bool> caisseOuverte() async =>
      await journal.dernierEvenementCaisse() == TypeOperation.fondsDeCaisse;

  /// Ouvre la caisse avec l'argent laissé pour rendre la monnaie (0 accepté).
  Future<void> ouvrirCaisse(int fonds) async {
    await journal.enregistrerFondsDeCaisse(fonds, auteurId: auteurActuel);
    notifyListeners();
  }

  /// Dépense payée avec la caisse (motif obligatoire).
  Future<void> depenser(
    int montant, {
    required String motif,
    required ModePaiement mode,
  }) async {
    await journal.enregistrerDepense(
      montant,
      motif: motif,
      mode: mode,
      auteurId: auteurActuel,
    );
    notifyListeners();
  }

  /// Argent pris par le patron.
  Future<void> retraitPatron(int montant, {required ModePaiement mode}) async {
    await journal.enregistrerRetraitPatron(
      montant,
      mode: mode,
      auteurId: auteurActuel,
    );
    notifyListeners();
  }

  /// Moyens de paiement à compter à la fermeture : toujours les espèces, plus
  /// Flooz et Mixx s'ils ont reçu de l'argent depuis la dernière fermeture.
  Future<List<ModePaiement>> modesAFermer() async {
    final enCours = await journal.caisseEnCours();
    return [
      for (final e in enCours.entries)
        if (e.key == ModePaiement.especes ||
            attenduAFermeture(e.key, e.value) != 0)
          e.key,
    ];
  }

  /// Fermeture de caisse en comptage aveugle.
  Future<FermetureCaisse> fermerCaisse(Map<ModePaiement, int> comptes) async {
    final f = await journal.enregistrerFermeture(
      comptes,
      auteurId: auteurActuel,
    );
    notifyListeners();
    return f;
  }

  /// Chiffres du tableau du patron pour une période.
  Future<TableauPatron> tableau(Periode periode) async {
    final m = maintenant();
    final depuis = periode.debut(m).millisecondsSinceEpoch;
    final ilYa7Jours = DateTime(
      m.year,
      m.month,
      m.day,
    ).subtract(const Duration(days: 6)).millisecondsSinceEpoch;
    final ventes = await journal.resumeVentes(depuis: depuis);
    final benefice = await journal.beneficeEstime(depuis: depuis);
    final depenses = await journal.totalDepenses(depuis: depuis);
    final parProduit = await journal.ventesParProduit(depuis: depuis);
    final semaine = await journal.ventesParProduit(depuis: ilYa7Jours);
    final recus = await journal.produitsDejaRecus();
    final stocks = await journal.stocks();

    final meilleurs =
        parProduit.entries.where((e) => e.value.montant > 0).toList()
          ..sort((a, b) => b.value.montant.compareTo(a.value.montant));
    final bas = <(Produit, int, RaisonStockBas)>[];
    for (final p in _produits) {
      final stock = stocks[p.id] ?? 0;
      final raison = stockBas(
        stock: stock,
        seuil: p.seuilAlerteMilliemes,
        venduSur7Jours: semaine[p.id]?.milliemes ?? 0,
        dejaRecu: recus.contains(p.id),
      );
      if (raison != null) bas.add((p, stock, raison));
    }
    bas.sort((a, b) => a.$3.index.compareTo(b.$3.index));
    return TableauPatron(
      periode: periode,
      ventes: ventes.total,
      nombreVentes: ventes.nombre,
      benefice: benefice,
      depenses: depenses,
      credits: await journal.totalCredits(),
      meilleurs: [
        for (final e in meilleurs.take(3))
          (
            _produits.where((p) => p.id == e.key).firstOrNull?.nom ?? 'Produit',
            e.value.montant,
          ),
      ],
      stockBas: bas,
    );
  }

  /// Vrai pour la boutique de démonstration (voir `app/demo.dart`).
  bool estDemo = false;

  /// Fichier de sauvegarde chiffré avec le code secret du patron.
  /// Jamais en démonstration (ses données ne doivent pas en sortir).
  Future<Uint8List> creerSauvegarde(String codePatron) async {
    if (estDemo) {
      throw const ErreurZeroPerte('Pas de sauvegarde en démonstration.');
    }
    return chiffrerSauvegarde(await journal.exporterJournal(), codePatron);
  }

  /// Nom du fichier de sauvegarde : « ZeroPerte-Boutique-Ama-2026-11-21.zps ».
  String nomSauvegarde() {
    final m = maintenant();
    String n(int v) => v.toString().padLeft(2, '0');
    final nom = config.nom
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return 'ZeroPerte-${nom.isEmpty ? 'boutique' : nom}-${m.year}-${n(m.month)}-${n(m.day)}.zps';
  }

  /// Restaure une sauvegarde sur un téléphone vide, puis recharge tout.
  /// Renvoie le nombre d'opérations restaurées.
  Future<int> restaurerSauvegarde(List<int> fichier, String codePatron) async {
    if (estDemo) {
      throw const ErreurZeroPerte('Pas de restauration en démonstration.');
    }
    final clair = await dechiffrerSauvegarde(fichier, codePatron);
    final n = await journal.restaurerJournal(clair);
    _codes
      ..clear()
      ..addAll(await journal.codesActives());
    _config = await journal.configuration() ?? const ConfigBoutique();
    _utilisateurs = await journal.utilisateurs();
    _produits = await journal.produits();
    _stocks = await journal.stocks();
    notifyListeners();
    return n;
  }

  // ---------------------------------------------------------------------------
  // Crédit client
  // ---------------------------------------------------------------------------

  /// Plafond donné à un nouveau client quand ce n'est pas le patron qui le crée.
  static const int plafondParDefaut = 5000;

  /// Plafonds proposés au patron.
  static const List<int> plafondsProposes = [2000, 5000, 10000, 20000, 50000];

  /// Clients actifs : ceux qui doivent le plus d'abord, puis par nom.
  Future<List<Client>> clients() async {
    final l = (await journal.clients()).where((c) => c.actif).toList()
      ..sort(
        (a, b) => b.solde != a.solde
            ? b.solde.compareTo(a.solde)
            : a.nom.toLowerCase().compareTo(b.nom.toLowerCase()),
      );
    return l;
  }

  /// Crée ou modifie une fiche client. Seul le patron choisit le plafond.
  Future<String> enregistrerClient({
    Client? existant,
    required String nom,
    String telephone = '',
    String? photo,
    int? plafond,
  }) async {
    final p = estPatron
        ? (plafond ?? existant?.plafond ?? plafondParDefaut)
        : (existant?.plafond ?? plafondParDefaut);
    final id = await journal.definirClient(
      clientId: existant?.id,
      nom: nom,
      telephone: normaliserTelephone(telephone) ?? telephone.trim(),
      photo: photo ?? existant?.photo,
      plafond: p,
      auteurId: auteurActuel,
    );
    notifyListeners();
    return id;
  }

  /// Le client rembourse tout ou partie de sa dette.
  Future<void> rembourser(
    Client c,
    int montant, {
    required ModePaiement mode,
  }) async {
    await journal.enregistrerRemboursement(
      clientId: c.id,
      montant: montant,
      mode: mode,
      auteurId: auteurActuel,
    );
    notifyListeners();
  }

  /// Message de rappel envoyé au client sur WhatsApp.
  String messageRappel(Client c) =>
      'Bonjour ${c.nom}, petit rappel de ${config.nom} : il reste '
      '${formatFrancs(c.solde)} à payer. Merci !';

  /// Lien WhatsApp vers le client avec le message de rappel ; nul sans numéro.
  Uri? lienRappel(Client c) {
    final chiffres = c.telephone.replaceAll(RegExp(r'[^0-9]'), '');
    if (chiffres.length < 8) return null;
    final numero = chiffres.length == 8 ? '228$chiffres' : chiffres;
    return Uri.https('wa.me', '/$numero', {'text': messageRappel(c)});
  }

  /// La personne connectée est-elle le patron ?
  bool get estPatron => utilisateurActuel?.role == Role.patron;

  /// Nom d'une personne d'après son identifiant (pour les listes).
  String nomDe(String id) =>
      _utilisateurs.where((u) => u.id == id).firstOrNull?.nom ?? '—';

  /// Arrivage de marchandise (patron seulement).
  Future<void> enregistrerArrivage({
    required Produit produit,
    Conditionnement? conditionnement,
    required int nombre,
    required int coutTotal,
  }) async {
    await journal.enregistrerArrivage(
      produitId: produit.id,
      conditionnementId: conditionnement?.id,
      nombre: nombre,
      coutTotal: coutTotal,
      auteurId: auteurActuel,
    );
    await rechargerProduits();
  }

  /// Ajoute à la boutique les produits choisis dans le catalogue (sans prix :
  /// le patron les fixe ensuite). Les produits déjà présents ne sont pas recréés.
  Future<void> ajouterDuCatalogue(Iterable<ProduitCatalogue> choisis) async {
    final dejaLa = {for (final p in _produits) p.catalogueId};
    for (final c in choisis) {
      if (dejaLa.contains(c.id)) continue;
      final id = await journal.definirProduit(
        nom: c.nom,
        uniteBase: c.unite,
        prixUnitaire: 0,
        emoji: c.emoji,
        catalogueId: c.id,
        auMontant: c.auMontant,
        emballage: c.emballage,
        auteurId: auteurActuel,
      );
      for (final k in c.conditionnements) {
        await journal.definirConditionnement(
          produitId: id,
          nom: k.nom,
          facteurMilliemes: k.unites * milliemesParUnite,
          prixVente: 0,
          aVerifier: k.aVerifier,
          auteurId: auteurActuel,
        );
      }
    }
    await rechargerProduits();
  }

  /// Fixe le prix d'un produit et de ses conditionnements (nouvelles versions).
  Future<void> fixerPrix(
    Produit p,
    int prixUnitaire,
    Map<Conditionnement, int> prixConditionnements,
  ) async {
    if (prixUnitaire != p.prixUnitaire) {
      await journal.definirProduit(
        produitId: p.id,
        nom: p.nom,
        uniteBase: p.uniteBase,
        prixUnitaire: prixUnitaire,
        seuilAlerteMilliemes: p.seuilAlerteMilliemes,
        emballage: p.emballage,
        consigne: p.consigne,
        emoji: p.emoji,
        catalogueId: p.catalogueId,
        auMontant: p.auMontant,
        photo: p.photo,
        auteurId: auteurActuel,
      );
    }
    for (final e in prixConditionnements.entries) {
      if (e.value == e.key.prixVente) continue;
      await journal.definirConditionnement(
        conditionnementId: e.key.id,
        produitId: p.id,
        nom: e.key.nom,
        facteurMilliemes: e.key.facteurMilliemes,
        prixVente: e.value,
        aVerifier: e.key.aVerifier,
        auteurId: auteurActuel,
      );
    }
    await rechargerProduits();
  }
}

/// Chiffres affichés dans le tableau du patron.
class TableauPatron {
  const TableauPatron({
    required this.periode,
    required this.ventes,
    required this.nombreVentes,
    required this.benefice,
    required this.depenses,
    this.credits = 0,
    required this.meilleurs,
    required this.stockBas,
  });

  final Periode periode;

  /// Argent des ventes (annulations déduites), tous moyens de paiement.
  final int ventes;
  final int nombreVentes;
  final ResumeBenefice benefice;
  final int depenses;

  /// Ce que les clients doivent encore (crédit), aujourd'hui, toutes périodes.
  final int credits;

  /// Les 3 produits qui ont rapporté le plus : (nom, montant).
  final List<(String, int)> meilleurs;

  /// Produits à racheter : (produit, stock en millièmes, raison).
  final List<(Produit, int, RaisonStockBas)> stockBas;
}
