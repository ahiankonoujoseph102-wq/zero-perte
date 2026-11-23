import 'dart:async';
import 'dart:convert';
import 'dart:math' show Random;

import 'package:flutter/foundation.dart';

import '../domaine/argent.dart';
import '../domaine/boutique.dart';
import '../domaine/catalogue.dart';
import '../domaine/dates.dart';
import '../domaine/inventaire.dart';
import '../domaine/licence.dart';
import '../domaine/messages_whatsapp.dart';
import '../domaine/operation.dart';
import '../domaine/panier.dart';
import '../domaine/quantites.dart';
import '../domaine/sauvegarde.dart';
import '../domaine/tableau.dart';
import '../domaine/utilisateurs.dart';
import '../donnees/journal_local.dart';
import '../services/google.dart' show ConnexionStockage;
import '../services/lecteur_qr.dart' show LecteurQr;
import '../services/notifications.dart' show sujetAlertes;
import '../services/partage.dart';
import '../synchro/drive.dart' show StockageDriveAppData;
import '../synchro/invitation.dart';
import '../synchro/relais.dart';
import '../synchro/synchro.dart';
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
    this.connecterDrive,
    this.choisirFichier,
    this.activerNotifications,
    this.codeGoogleServeur,
    this.lecteurQr,
    this.stockageParJeton,
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

  /// Connexion au Drive de la boutique (nul : pas possible ici).
  final Future<ConnexionStockage?> Function({bool silencieux})? connecterDrive;

  /// Abonne ce téléphone aux notifications d'alertes (nul : pas possible ici).
  final Future<bool> Function(String sujet)? activerNotifications;

  /// Choisit un fichier de sauvegarde sur l'appareil (nul si annulé).
  final Future<Uint8List?> Function()? choisirFichier;

  /// Téléphone du patron : demande à Google l'accord pour un vendeur (compte
  /// de la boutique, dossier caché de Zéro Perte) et rend le code d'échange à
  /// usage unique ; nul si la personne annule. Nul : pas possible ici.
  final Future<String?> Function(String idClientWeb)? codeGoogleServeur;

  /// Lecteur de QR code (Google Play services). Nul : pas de lecteur ici.
  final LecteurQr? lecteurQr;

  /// Dossier de la boutique pour un téléphone entré par invitation (tests ;
  /// par défaut, le vrai Google Drive).
  final StockageDistant Function(
    Future<String> Function({bool renouveler}) jeton,
  )?
  stockageParJeton;
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
    etat._appareilRetire = await journal.lireParametre(_cleRetire) == '1';
    etat._nbAppareils = int.tryParse(
      await journal.lireParametre('sync.appareils') ?? '',
    );
    etat._accesCoupe = await journal.lireParametre(_cleCoupe) == '1';
    etat._avertissements = _lireListe(
      await journal.lireParametre(_cleAvertissements),
    );
    return etat;
  }

  static List<String> _lireListe(String? brut) {
    if (brut == null || brut.isEmpty) return const [];
    try {
      return [for (final x in jsonDecode(brut) as List) '$x'];
    } catch (_) {
      return const [];
    }
  }

  // --- Avertissements de l'installation (Q1) --------------------------------

  static const _cleAvertissements = 'installation.avertissements';
  List<String> _avertissements = const [];

  /// Avertissements non bloquants trouvés à l'installation (peu de place,
  /// pas de voix française) : montrés une seule fois dans un bandeau orange
  /// après l'installation, jusqu'à « Compris ».
  List<String> get avertissementsInstallation =>
      installationTerminee ? _avertissements : const [];

  Future<void> noterAvertissementsInstallation(List<String> liste) async {
    _avertissements = List.unmodifiable(liste);
    await journal.ecrireParametre(_cleAvertissements, jsonEncode(liste));
    notifyListeners();
  }

  /// « Compris » : le bandeau ne revient plus.
  Future<void> avertissementsVus() => noterAvertissementsInstallation(const []);

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
    final probleme = problemePin(pin, longueur: longueurPinPatron);
    if (probleme != null) throw ErreurZeroPerte(probleme);
    await _verifierCodeLibre(pin, sauf: patron?.id);
    final sel = nouveauSel();
    final u = Utilisateur(
      id: patron?.id ?? nouvelIdentifiant(),
      nom: nom.trim().isEmpty ? 'Patron' : nom.trim(),
      role: Role.patron,
      sel: sel,
      hachage: await hacherPin(pin, sel, tours: toursPinPatron),
      longueurCode: longueurPinPatron,
      tours: toursPinPatron,
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

  /// Ajoute un vendeur. Son code est TIRÉ AU HASARD par l'application (jamais
  /// choisi par une personne) : ainsi personne ne peut découvrir, en
  /// essayant un code « déjà pris », qu'il appartient à quelqu'un d'autre.
  /// [pin] ne sert qu'aux tests et aux reprises de données.
  Future<({Utilisateur vendeur, String code})> ajouterVendeur({
    required String nom,
    String? pin,
  }) async {
    if (nom.trim().isEmpty) {
      throw const ErreurZeroPerte('Écrivez le prénom du vendeur.');
    }
    final code = pin ?? await tirerCodeVendeur();
    final probleme = problemePin(code);
    if (probleme != null) throw ErreurZeroPerte(probleme);
    await _verifierCodeLibre(code);
    final sel = nouveauSel();
    final u = Utilisateur(
      id: nouvelIdentifiant(),
      nom: nom.trim(),
      role: Role.vendeur,
      sel: sel,
      hachage: await hacherPin(code, sel),
    );
    await journal.definirUtilisateur(u, auteurId: auteurActuel);
    _utilisateurs = await journal.utilisateurs();
    notifyListeners();
    return (vendeur: u, code: code);
  }

  /// Tire au hasard un code de vendeur (4 chiffres) : pas trop facile
  /// (1111, 1234…) et différent de celui de toutes les autres personnes.
  Future<String> tirerCodeVendeur({String? sauf, Random? hasard}) async {
    final r = hasard ?? Random.secure();
    for (var essai = 0; essai < 200; essai++) {
      final code = r.nextInt(10000).toString().padLeft(longueurPin, '0');
      if (problemePin(code) != null) continue;
      if (await codeDejaUtilise(code, sauf: sauf)) continue;
      return code;
    }
    throw const ErreurZeroPerte('Impossible de créer un code. Réessayez.');
  }

  /// Donne au vendeur [u] un nouveau code tiré au hasard, et le renvoie
  /// (à lui remettre en privé : il ne sera plus jamais affiché).
  Future<String> nouveauCodeVendeur(Utilisateur u) async {
    final code = await tirerCodeVendeur(sauf: u.id);
    await changerPin(u, code);
    return code;
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
    final longueur = longueurPour(u.role);
    final probleme = problemePin(pin, longueur: longueur);
    if (probleme != null) throw ErreurZeroPerte(probleme);
    await _verifierCodeLibre(pin, sauf: u.id);
    final sel = nouveauSel();
    final tours = toursPour(u.role);
    final nouveau = Utilisateur(
      id: u.id,
      nom: u.nom,
      role: u.role,
      sel: sel,
      hachage: await hacherPin(pin, sel, tours: tours),
      actif: u.actif,
      longueurCode: longueur,
      tours: tours,
    );
    await journal.definirUtilisateur(nouveau, auteurId: auteurActuel);
    _utilisateurs = await journal.utilisateurs();
    if (_utilisateurActuel?.id == u.id) _utilisateurActuel = nouveau;
    notifyListeners();
  }

  /// Le patron installé avant la version 0.17 doit choisir un code de 6 chiffres.
  bool get patronDoitChangerCode =>
      installationTerminee && (patron?.doitPasserA6Chiffres ?? false);

  // ---------------------------------------------------------------------------
  // Session : qui utilise le téléphone
  // ---------------------------------------------------------------------------

  Utilisateur? _utilisateurActuel;

  /// Personne connectée (patron ou vendeur), nulle si personne.
  Utilisateur? get utilisateurActuel => _utilisateurActuel;

  /// Le menu complet (patron) : le patron connecté, ou personne n'est encore
  /// enregistré (boutique en cours d'installation). Le vendeur ne voit que
  /// Vendre, Ma caisse et Clients.
  bool get voitTout => estPatron || _utilisateurs.isEmpty;

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

  // --- Entrée directe par le code (comme sur un logiciel de caisse) ---------

  /// Codes faux tapés à l'entrée depuis le dernier bon code. Gardé dans les
  /// réglages : fermer et rouvrir l'application ne remet pas le compte à zéro.
  int _erreursCode = 0;
  static const _cleBlocageCode = 'pin.blocage.connexion';
  static const _cleErreursCode = 'pin.erreurs.connexion';

  /// Écran d'entrée bloqué jusqu'à cette heure (après 5 codes faux), ou nul.
  Future<DateTime?> entreeBloqueeJusqua() async {
    final ms = int.tryParse(await journal.lireParametre(_cleBlocageCode) ?? '');
    if (ms == null) return null;
    final fin = DateTime.fromMillisecondsSinceEpoch(ms);
    return fin.isAfter(maintenant()) ? fin : null;
  }

  /// On tape son code et on entre : le code reconnaît la personne.
  /// Nul si le code est faux. Après [essaisPin] codes faux : bloqué
  /// [dureeBlocagePin] (et alerte au patron).
  Future<Utilisateur?> connecterParCode(String code) async {
    if (await entreeBloqueeJusqua() != null) return null;
    _erreursCode =
        int.tryParse(await journal.lireParametre(_cleErreursCode) ?? '') ?? 0;
    for (final u in _utilisateurs.where((u) => u.longueurCode == code.length)) {
      if (await pinCorrect(u, code)) {
        if (!u.actif) {
          throw ErreurZeroPerte(
            'Le compte de ${u.nom} est bloqué. Voyez le patron.',
          );
        }
        _erreursCode = 0;
        await journal.ecrireParametre(_cleErreursCode, '0');
        _utilisateurActuel = u;
        notifyListeners();
        return u;
      }
    }
    _erreursCode++;
    if (_erreursCode >= essaisPin) {
      _erreursCode = 0;
      await journal.ecrireParametre(_cleErreursCode, '0');
      await journal.ecrireParametre(
        _cleBlocageCode,
        '${maintenant().add(dureeBlocagePin).millisecondsSinceEpoch}',
      );
      unawaited(
        alerter(
          'code',
          '$essaisPin codes faux à l\'entrée (appareil ${journal.prefixeRecu}).',
        ),
      );
    } else {
      await journal.ecrireParametre(_cleErreursCode, '$_erreursCode');
    }
    return null;
  }

  /// Codes faux restants avant le blocage de l'écran d'entrée.
  int get essaisEntreeRestants => essaisPin - _erreursCode;

  /// Vrai si ce code est déjà celui d'une autre personne (deux personnes ne
  /// peuvent pas avoir le même code : c'est lui qui les reconnaît).
  Future<bool> codeDejaUtilise(String code, {String? sauf}) async {
    for (final u in _utilisateurs.where(
      (u) => u.id != sauf && u.longueurCode == code.length,
    )) {
      if (await pinCorrect(u, code)) return true;
    }
    return false;
  }

  Future<void> _verifierCodeLibre(String code, {String? sauf}) async {
    if (await codeDejaUtilise(code, sauf: sauf)) {
      // Message neutre : il ne dit jamais que le code est celui de quelqu'un.
      throw const ErreurZeroPerte(
        'Ce code ne peut pas être utilisé. Choisissez-en un autre.',
      );
    }
  }

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
      unawaited(
        alerter(
          'code',
          '$essaisPin codes faux pour ${u.nom} (appareil ${journal.prefixeRecu}).',
        ),
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
                  prixImpose: l.prixDuDevis ? l.prixUnitaire : null,
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
    derniereVente = vente;
    return vente;
  }

  /// Dernière vente enregistrée sur cet appareil (pour marquer un devis
  /// vendu).
  VenteEnregistree? derniereVente;

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
    if (v.total >= seuilAlerteAnnulation) {
      unawaited(
        alerter(
          'annulation',
          '${nomDe(auteurActuel)} a annulé la vente ${v.recu} de '
              '${formatFrancs(v.total)} (« $motif »).',
        ),
      );
    }
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

  /// Page « Ma caisse » : ouverte ou non, fond initial, sessions passées.
  Future<EtatCaisseJour> etatCaisse() async {
    final ouverte = await caisseOuverte();
    final ouverture = ouverte ? await journal.derniereOuverture() : null;
    final enCours = await journal.caisseEnCours();
    return EtatCaisseJour(
      ouverte: ouverte,
      heureOuverture: ouverture?.heure,
      ouvertPar: ouverture == null ? null : nomDe(ouverture.auteurId),
      fonds: ouverte ? enCours[ModePaiement.especes]!.fondsDeCaisse : 0,
      // L'attendu n'est donné qu'au patron (fermeture aveugle du vendeur).
      attendus: voitTout
          ? {
              for (final e in enCours.entries)
                e.key: attenduAFermeture(e.key, e.value),
            }
          : const {},
      sessions: await journal.fermetures(limite: 15),
    );
  }

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
    for (final m in ModePaiement.caisses) {
      final r = f.resultat(m);
      if (-r.ecart >= seuilAlerteEcart) {
        unawaited(
          alerter(
            'ecart',
            'Caisse fermée par ${nomDe(f.auteurId)} : il manque '
                '${formatFrancs(-r.ecart)} (${m.code}).',
          ),
        );
      }
    }
    // Résumé du soir : part en notification au patron (relais et Firebase
    // branchés) ; sinon il le verra à l'ouverture de son application.
    if (!estPatron && !estDemo && transportAlertes != null) {
      unawaited(_envoyerResumeSoir(f));
    }
    return f;
  }

  Future<void> _envoyerResumeSoir(FermetureCaisse f) async {
    try {
      final r = await rapport(Periode.jour);
      final t = await tableau(Periode.jour);
      final resume = ResumeSoir(
        fermetureId: f.id,
        heure: f.heure,
        boutique: config.nom,
        date: '',
        ventes: r.ventes,
        nombreVentes: r.nombreVentes,
        benefice: r.benefice,
        depenses: r.depenses,
        ecart: f.ecartTotal,
        fermePar: nomDe(f.auteurId),
        stockBas: [for (final (p, _, _) in t.stockBas) p.nom],
      );
      await alerter(typeResumeSoir, 'Résumé du soir : ${resume.texteCourt()}');
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Retours partiels, devis, rapports
  // ---------------------------------------------------------------------------

  /// Retour partiel d'une vente. Au-delà du seuil d'alerte (5 000 F), il faut
  /// l'accord du patron ([accordPatronId], obtenu avec son code) quand ce
  /// n'est pas lui qui fait le retour. Le patron est prévenu de chaque retour
  /// fait par un vendeur.
  Future<OperationLue> retournerVente(
    VenteResume vente, {
    required Map<int, int> rendus,
    required ModePaiement mode,
    required String motif,
    String? accordPatronId,
  }) async {
    final op = await journal.enregistrerRetour(
      venteOperationId: vente.operationId,
      rendus: rendus,
      mode: mode,
      motif: motif,
      accordPatronId: accordPatronId ?? (estPatron ? patron?.id : null),
      auteurId: auteurActuel,
    );
    await rechargerProduits();
    final total = op.donnees['total'] as int;
    if (!estPatron) {
      unawaited(
        alerter(
          'retour',
          '${nomDe(auteurActuel)} a fait un retour sur la vente ${vente.recu} : '
              '${formatFrancs(total)} rendus (« $motif »).',
        ),
      );
    }
    notifyListeners();
    return OperationLue(
      id: op.id,
      heure: op.heureTelephone,
      auteurId: op.auteurId,
      donnees: op.donnees,
    );
  }

  /// Vrai si ce retour demande l'accord du patron.
  bool retourDemandeAccord(int total) =>
      !estPatron && total >= seuilAlerteAnnulation;

  /// Devis (facture proforma) créé depuis le panier : ni stock ni caisse.
  Future<OperationLue> creerDevis(Panier panier) async {
    final op = await journal.enregistrerDevis(
      clientId: panier.clientId,
      auteurId: auteurActuel,
      lignes: [
        for (final l in panier.lignes)
          {
            'produit': l.produitId,
            'conditionnement': l.conditionnement?.id,
            'nombre': l.nombre,
            'montant': l.montant,
            'libelle': l.libelle,
            'prix': l.prix,
          },
      ],
    );
    return OperationLue(
      id: op.id,
      heure: op.heureTelephone,
      auteurId: op.auteurId,
      donnees: op.donnees,
    );
  }

  /// Vrai si le devis est encore valable (7 jours par défaut, comptés
  /// jusqu'à la fin du dernier jour).
  bool devisValable(OperationLue devis) {
    final jours = devis.donnees['validite_jours'] as int? ?? 7;
    final cree = DateTime.fromMillisecondsSinceEpoch(devis.heure);
    final fin = DateTime(cree.year, cree.month, cree.day + jours + 1);
    return maintenant().isBefore(fin);
  }

  /// Panier refait à partir d'un devis. Devis encore valable : les prix du
  /// devis sont gardés, même si les prix ont changé. Devis expiré : prix du
  /// jour.
  Future<PanierDevis> panierDepuisDevis(OperationLue devis) async {
    final valable = devisValable(devis);
    final panier = Panier();
    for (final l in devis.lignes) {
      final p = _produits.where((p) => p.id == l['produit']).firstOrNull;
      if (p == null) continue;
      final condId = l['conditionnement'] as String?;
      final c = condId == null
          ? null
          : (await journal.conditionnements(p.id))
                .where((c) => c.id == condId)
                .firstOrNull;
      final montant = l['montant'] as int?;
      final nombre = montant == null ? (l['nombre'] as int? ?? 1) : null;
      final prixDuJour = c?.prixVente ?? p.prixUnitaire;
      final garderPrix = valable && nombre != null && nombre > 0;
      panier.ajouter(
        LignePanier(
          produitId: p.id,
          nomProduit: p.nom,
          uniteBase: p.uniteBase,
          emoji: p.emoji,
          conditionnement: c,
          nombre: nombre,
          montant: montant,
          prixUnitaire: garderPrix ? (l['prix'] as int) ~/ nombre : prixDuJour,
          prixDuDevis: garderPrix,
        ),
      );
    }
    final clientId = devis.donnees['client'] as String?;
    if (clientId != null) {
      final c = await journal.client(clientId);
      panier.choisirClient(clientId, c?.nom);
    }
    return PanierDevis(
      panier: panier,
      valable: valable,
      totalChange: panier.total != devis.total,
    );
  }

  /// Le devis est devenu la dernière vente enregistrée.
  Future<void> devisVendu(OperationLue devis) async {
    final v = derniereVente;
    if (v == null) return;
    await journal.marquerDevisVendu(
      devisId: devis.id,
      venteOperationId: v.operation.id,
      recu: v.recu,
      auteurId: auteurActuel,
    );
    notifyListeners();
  }

  /// Rapport d'une période : [decalage] 0 = la période en cours, −1 = la
  /// précédente…
  Future<Rapport> rapport(Periode periode, {int decalage = 0}) async {
    final m = maintenant();
    final aujourdhui = DateTime(m.year, m.month, m.day);
    late DateTime debut;
    late DateTime fin;
    switch (periode) {
      case Periode.jour:
        debut = DateTime(m.year, m.month, m.day + decalage);
        fin = DateTime(debut.year, debut.month, debut.day + 1);
      case Periode.semaine:
        final lundi = aujourdhui.subtract(Duration(days: m.weekday - 1));
        debut = DateTime(lundi.year, lundi.month, lundi.day + 7 * decalage);
        fin = DateTime(debut.year, debut.month, debut.day + 7);
      case Periode.mois:
        debut = DateTime(m.year, m.month + decalage);
        fin = DateTime(debut.year, debut.month + 1);
    }
    final d = debut.millisecondsSinceEpoch;
    final f = fin.millisecondsSinceEpoch;
    final jours = <JourRapport>[];
    if (periode != Periode.jour) {
      for (
        var j = debut;
        j.isBefore(fin);
        j = DateTime(j.year, j.month, j.day + 1)
      ) {
        if (j.isAfter(aujourdhui)) break;
        final a = j.millisecondsSinceEpoch;
        final b = DateTime(j.year, j.month, j.day + 1).millisecondsSinceEpoch;
        jours.add(
          JourRapport(
            jour: j,
            ventes: (await journal.resumeVentes(depuis: a, jusqua: b)).total,
            benefice: (await journal.beneficeEstime(
              depuis: a,
              jusqua: b - 1,
            )).benefice,
            depenses: await journal.totalDepenses(depuis: a, jusqua: b),
          ),
        );
      }
    }
    final ventes = await journal.resumeVentes(depuis: d, jusqua: f);
    final credit = await journal.mouvementsCredit(depuis: d, jusqua: f);
    final parProduit = await journal.ventesParProduit(depuis: d, jusqua: f);
    final classes =
        parProduit.entries.where((e) => e.value.montant > 0).toList()
          ..sort((a, b) => b.value.montant.compareTo(a.value.montant));
    final inventaires = [
      for (final i in await journal.inventaires(limite: 500))
        if (i.heure >= d && i.heure < f) i,
    ];
    return Rapport(
      periode: periode,
      debut: debut,
      fin: fin,
      ventes: ventes.total,
      nombreVentes: ventes.nombre,
      benefice: (await journal.beneficeEstime(
        depuis: d,
        jusqua: f - 1,
      )).benefice,
      depenses: await journal.totalDepenses(depuis: d, jusqua: f),
      retours: await journal.totalRetours(depuis: d, jusqua: f),
      creditAccorde: credit.accorde,
      creditRembourse: credit.rembourse,
      creditsDus: await journal.totalCredits(),
      inventaires: inventaires,
      meilleurs: [
        for (final e in classes.take(5))
          (
            _produits.where((p) => p.id == e.key).firstOrNull?.nom ?? 'Produit',
            e.value.montant,
          ),
      ],
      jours: jours,
    );
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

    final ilYa30Jours = DateTime(
      m.year,
      m.month,
      m.day - 29,
    ).millisecondsSinceEpoch;
    List<(String, int)> classer(
      Map<String, ({int milliemes, int montant})> parId,
      int n,
    ) {
      final l = parId.entries.where((e) => e.value.montant > 0).toList()
        ..sort((a, b) => b.value.montant.compareTo(a.value.montant));
      return [
        for (final e in l.take(n))
          (
            _produits.where((p) => p.id == e.key).firstOrNull?.nom ?? 'Produit',
            e.value.montant,
          ),
      ];
    }

    final trenteJours = await journal.ventesParProduit(depuis: ilYa30Jours);
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
      septJours: await ventesSeptJours(),
      meilleurs: classer(parProduit, 3),
      meilleurs30Jours: classer(trenteJours, 5),
      stockBas: bas,
    );
  }

  static const _cleResumeVu = 'resume_soir.vu';

  /// Résumé du soir pour le patron : la dernière fermeture de caisse faite par
  /// un autre que lui, pas encore vue, de moins de 36 heures. Nul sinon.
  Future<ResumeSoir?> resumeDuSoir() async {
    if (!estPatron || estDemo) return null;
    final fermetures = await journal.fermetures(limite: 20);
    final f = fermetures.firstOrNull;
    if (f == null || f.auteurId == patron?.id) return null;
    final vu =
        int.tryParse(await journal.lireParametre(_cleResumeVu) ?? '') ?? 0;
    if (f.heure <= vu) return null;
    final m = maintenant();
    if (m.millisecondsSinceEpoch - f.heure > 36 * 3600 * 1000) return null;
    final jour = DateTime.fromMillisecondsSinceEpoch(f.heure);
    final debutJour = DateTime(jour.year, jour.month, jour.day);
    final decalage = debutJour
        .difference(DateTime(m.year, m.month, m.day))
        .inDays;
    final r = await rapport(Periode.jour, decalage: decalage);
    final ecart = fermetures
        .where((x) {
          final d = DateTime.fromMillisecondsSinceEpoch(x.heure);
          return d.year == jour.year &&
              d.month == jour.month &&
              d.day == jour.day;
        })
        .fold<int>(0, (s, x) => s + x.ecartTotal);
    final t = await tableau(Periode.jour);
    return ResumeSoir(
      fermetureId: f.id,
      heure: f.heure,
      boutique: config.nom,
      date: dateEnFrancais(debutJour),
      ventes: r.ventes,
      nombreVentes: r.nombreVentes,
      benefice: r.benefice,
      depenses: r.depenses,
      ecart: ecart,
      fermePar: nomDe(f.auteurId),
      stockBas: [for (final (p, _, _) in t.stockBas) p.nom],
    );
  }

  /// Le patron a vu ce résumé : il ne s'affiche plus.
  Future<void> marquerResumeVu(ResumeSoir r) =>
      journal.ecrireParametre(_cleResumeVu, '${r.heure}');

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
    await rechargerTout();
    return n;
  }

  /// Relit tout depuis le journal (après une restauration, ou quand des
  /// opérations d'un autre appareil arrivent par la synchronisation).
  Future<void> rechargerTout() async {
    _codes
      ..clear()
      ..addAll(await journal.codesActives());
    _config = await journal.configuration() ?? const ConfigBoutique();
    _utilisateurs = await journal.utilisateurs();
    final actuel = _utilisateurActuel;
    if (actuel != null) {
      _utilisateurActuel = _utilisateurs
          .where((u) => u.id == actuel.id)
          .firstOrNull;
    }
    _produits = await journal.produits();
    _stocks = await journal.stocks();
    notifyListeners();
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

  /// Crée ou modifie une fiche client. Le vendeur peut seulement AJOUTER ;
  /// modifier, supprimer et exporter sont réservés au patron. Seul le patron
  /// choisit le plafond.
  Future<String> enregistrerClient({
    Client? existant,
    required String nom,
    String telephone = '',
    String? photo,
    int? plafond,
    String quartier = '',
    String email = '',
  }) async {
    if (existant != null && !estPatron) {
      throw const ErreurZeroPerte('Seul le patron peut modifier un client.');
    }
    final p = estPatron
        ? (plafond ?? existant?.plafond ?? plafondParDefaut)
        : (existant?.plafond ?? plafondParDefaut);
    final id = await journal.definirClient(
      clientId: existant?.id,
      nom: nom,
      telephone: normaliserTelephone(telephone) ?? telephone.trim(),
      photo: photo ?? existant?.photo,
      plafond: p,
      quartier: quartier,
      email: email,
      auteurId: auteurActuel,
    );
    notifyListeners();
    return id;
  }

  /// « Ne plus faire crédit » (plafond à 0) ou « Refaire crédit » (patron).
  Future<void> changerCredit(Client c, {required bool autorise}) async {
    if (!estPatron) {
      throw const ErreurZeroPerte('Seul le patron peut changer le crédit.');
    }
    await journal.definirClient(
      clientId: c.id,
      nom: c.nom,
      telephone: c.telephone,
      photo: c.photo,
      plafond: autorise ? plafondParDefaut : 0,
      quartier: c.quartier,
      email: c.email,
      auteurId: auteurActuel,
    );
    notifyListeners();
  }

  /// Inventaire complet (patron) : quantités comptées, en millièmes.
  Future<Inventaire> faireInventaire(Map<String, int> comptes) async {
    final inv = await journal.enregistrerInventaire(
      comptes,
      auteurId: auteurActuel,
    );
    await rechargerProduits();
    return inv;
  }

  /// Produits à compter aujourd'hui (inventaire tournant) : 3, ou 5 si la
  /// boutique a plus de 30 produits.
  Future<List<Produit>> produitsAInventorierAujourdhui() async {
    final m = maintenant();
    final semaine = await journal.ventesParProduit(
      depuis: DateTime(m.year, m.month, m.day - 6).millisecondsSinceEpoch,
    );
    final stocks = await journal.stocks();
    final poids = {
      for (final p in _produits)
        if ((stocks[p.id] ?? 0) > 0 && p.prixUnitaire > 0)
          p.id: p.prixUnitaire * ((semaine[p.id]?.milliemes ?? 0) ~/ 1000 + 1),
    };
    final ids = produitsDuJour(
      jour: m,
      poids: poids,
      nombre: _produits.length > 30 ? 5 : 3,
    );
    return [for (final id in ids) _produits.firstWhere((p) => p.id == id)];
  }

  /// Écarts d'inventaire (en francs) par personne qui a compté, depuis [depuis].
  Future<Map<String, int>> ecartsParPersonne({required int depuis}) async {
    final r = <String, int>{};
    for (final inv in await journal.inventaires(limite: 500)) {
      if (inv.heure < depuis) continue;
      r[inv.auteurId] = (r[inv.auteurId] ?? 0) + inv.ecartFrancs;
    }
    return r;
  }

  // --- Crédit fournisseur (patron) -----------------------------------------

  Future<List<Fournisseur>> fournisseurs() => journal.fournisseurs();

  Future<String> ajouterFournisseur({
    required String nom,
    String telephone = '',
  }) async {
    final id = await journal.definirFournisseur(
      nom: nom,
      telephone: normaliserTelephone(telephone) ?? telephone.trim(),
      auteurId: auteurActuel,
    );
    notifyListeners();
    return id;
  }

  Future<void> achatFournisseur(Fournisseur f, int montant) async {
    await journal.enregistrerAchatFournisseur(
      fournisseurId: f.id,
      montant: montant,
      auteurId: auteurActuel,
    );
    notifyListeners();
  }

  Future<void> payerFournisseur(
    Fournisseur f,
    int montant, {
    required ModePaiement mode,
  }) async {
    await journal.enregistrerPaiementFournisseur(
      fournisseurId: f.id,
      montant: montant,
      mode: mode,
      auteurId: auteurActuel,
    );
    notifyListeners();
  }

  /// Supprime un client du carnet (patron seulement, et s'il ne doit rien).
  /// Rien n'est effacé du journal : la fiche est seulement désactivée.
  Future<void> supprimerClient(Client c) async {
    if (!estPatron) {
      throw const ErreurZeroPerte('Seul le patron peut supprimer un client.');
    }
    if (c.solde > 0) {
      throw ErreurZeroPerte(
        '${c.nom} doit encore ${formatFrancs(c.solde)} : impossible de le supprimer.',
      );
    }
    await journal.definirClient(
      clientId: c.id,
      nom: c.nom,
      telephone: c.telephone,
      photo: c.photo,
      plafond: c.plafond,
      quartier: c.quartier,
      email: c.email,
      actif: false,
      auteurId: auteurActuel,
    );
    notifyListeners();
  }

  /// Carnet de clients en CSV (patron seulement), pour un tableur.
  Future<String> exporterClientsCsv() async {
    if (!estPatron) {
      throw const ErreurZeroPerte('Seul le patron peut exporter les clients.');
    }
    String champ(String v) => '"${v.replaceAll('"', '""')}"';
    final lignes = [
      'nom;telephone;quartier;email;doit (F);plafond (F)',
      for (final c in await clients())
        [
          champ(c.nom),
          champ(c.telephone),
          champ(c.quartier),
          champ(c.email),
          '${c.solde}',
          '${c.plafond}',
        ].join(';'),
    ];
    return '${lignes.join('\r\n')}\r\n';
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

  /// Crédits en retard (voir [joursRetardCredit]) : le client et le nombre de
  /// jours sans rien payer, le plus ancien d'abord.
  Future<List<(Client, int)>> creditsEnRetard() async {
    final refs = await journal.referencesCredits();
    final m = maintenant().millisecondsSinceEpoch;
    final l = <(Client, int)>[];
    for (final c in await clients()) {
      final r = refs[c.id];
      if (r == null || c.solde <= 0) continue;
      final jours = (m - r) ~/ Duration.millisecondsPerDay;
      if (jours >= joursRetardCredit) l.add((c, jours));
    }
    l.sort((a, b) => b.$2.compareTo(a.$2));
    return l;
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

  /// Ventes de chacun des 7 derniers jours (le plus ancien d'abord).
  Future<List<(DateTime, int)>> ventesSeptJours() async {
    final m = maintenant();
    final aujourdhui = DateTime(m.year, m.month, m.day);
    final jours = [
      for (var i = 6; i >= 0; i--)
        DateTime(aujourdhui.year, aujourdhui.month, aujourdhui.day - i),
    ];
    final totaux = List<int>.filled(7, 0);
    for (final (h, t) in await journal.ventesDetaillees(
      depuis: jours.first.millisecondsSinceEpoch,
    )) {
      final d = DateTime.fromMillisecondsSinceEpoch(h);
      final i = jours.indexWhere(
        (j) => j.year == d.year && j.month == d.month && j.day == d.day,
      );
      if (i >= 0) totaux[i] += t;
    }
    return [for (var i = 0; i < 7; i++) (jours[i], totaux[i])];
  }

  // ---------------------------------------------------------------------------
  // Synchronisation (bloc D)
  // ---------------------------------------------------------------------------

  Synchroniseur? _synchro;
  String? _compteSynchro;
  bool _synchroEnCours = false;
  Timer? _minuterie;

  /// Compte Google de la boutique (nul : pas encore connecté).
  String? get compteSynchro => _compteSynchro;
  bool get synchroEnCours => _synchroEnCours;

  /// Connecte le dossier de la boutique. Faux si annulé ou impossible.
  Future<bool> connecterSynchro({bool silencieux = false}) async {
    if (await journal.lireParametre(_cleModeSync) == _modeInvitation) {
      return _connecterParRelais();
    }
    final f = services.connecterDrive;
    if (f == null) return false;
    final c = await f(silencieux: silencieux);
    if (c == null) return false;
    _synchro = Synchroniseur(journal: journal, stockage: c.stockage);
    _compteSynchro = c.compte;
    await journal.ecrireParametre('sync.compte', c.compte);
    notifyListeners();
    return true;
  }

  /// Envoie ce qui est nouveau ici, reçoit ce qui vient des autres appareils.
  /// Les erreurs sont gardées (affichées au patron), jamais bloquantes.
  Future<ResultatSynchro?> synchroniser() async {
    if (_synchroEnCours || estDemo || _appareilRetire) return null;
    if (_synchro == null) {
      if (await journal.lireParametre('sync.compte') == null) return null;
      if (!await connecterSynchro(silencieux: true)) return null;
    }
    _synchroEnCours = true;
    notifyListeners();
    try {
      final r = await _synchro!.synchroniser(
        maxAppareils: licence?.telephones,
        nomAppareil:
            await journal.lireParametre(_cleNomAppareil) ??
            utilisateurActuel?.nom ??
            patron?.nom ??
            '',
        boutiqueId: licence?.boutiqueId,
      );
      if (_accesCoupe) {
        _accesCoupe = false;
        await journal.ecrireParametre(_cleCoupe, '');
      }
      await journal.ecrireParametre(
        'sync.derniere',
        '${maintenant().millisecondsSinceEpoch}',
      );
      await journal.ecrireParametre('sync.erreur', '');
      await journal.ecrireParametre('sync.appareils', '${r.appareils.length}');
      _nbAppareils = r.appareils.length;
      if (r.recues > 0) await rechargerTout();
      // Le réseau est là : on envoie aussi les alertes en attente.
      unawaited(envoyerAlertesEnAttente());
      return r;
    } on ErreurAppareilRetire {
      await _marquerRetire();
      return null;
    } on ErreurAccesRetire {
      await _marquerRetire();
      return null;
    } on ErreurAccesCoupe catch (e) {
      _accesCoupe = true;
      await journal.ecrireParametre(_cleCoupe, '1');
      await journal.ecrireParametre('sync.erreur', '$e');
      return null;
    } catch (e) {
      await journal.ecrireParametre('sync.erreur', '$e');
      return null;
    } finally {
      _synchroEnCours = false;
      notifyListeners();
    }
  }

  // --- Alertes graves (relais) ---------------------------------------------

  /// Transport des alertes (nul : relais non configuré dans cette version).
  TransportAlertes? transportAlertes;
  final List<Alerte> _alertes = [];
  Timer? _minuterieAlertes;

  /// Alertes reçues pas encore vues par le patron.
  List<Alerte> get alertes => List.unmodifiable(_alertes);

  void effacerAlertes() {
    _alertes.clear();
    notifyListeners();
  }

  Future<String?> _jetonRelais() async {
    final j = await journal.lireParametre('relais.jeton');
    if (j != null && j.isNotEmpty) return j;
    final infos = await _synchro?.infosBoutique();
    final nouveau = infos?['jeton_relais'] as String?;
    if (nouveau != null) await journal.ecrireParametre('relais.jeton', nouveau);
    return nouveau;
  }

  /// Envoie une alerte grave au patron (jamais bloquant ; rien si c'est le
  /// patron lui-même qui agit, ou en démonstration).
  Future<void> alerter(String type, String message) async {
    if (estDemo || estPatron) return;
    // Pas de relais dans cette version : rien à envoyer, rien à garder.
    if (transportAlertes == null) return;
    // L'alerte est d'abord gardée sur l'appareil, puis envoyée : sans réseau,
    // elle part dès que le réseau revient (même règle pour toutes les alertes
    // graves : caisse, annulation, retour, codes faux).
    final attente = await _alertesEnAttente();
    attente.add({
      'type': type,
      'message': message,
      'heure': maintenant().millisecondsSinceEpoch,
    });
    if (attente.length > maxAlertesEnAttente) attente.removeAt(0);
    await _garderAlertes();
    await envoyerAlertesEnAttente();
  }

  static const _cleAlertesAttente = 'alertes.attente';

  /// Au plus ce nombre d'alertes gardées sans réseau (au-delà, la plus
  /// ancienne est oubliée).
  static const maxAlertesEnAttente = 50;

  /// File des alertes pas encore parties : une seule liste en mémoire,
  /// recopiée dans les réglages à chaque changement (rien ne se perd si
  /// l'application est fermée).
  List<Map<String, Object?>>? _attente;

  Future<List<Map<String, Object?>>> _alertesEnAttente() async {
    final deja = _attente;
    if (deja != null) return deja;
    final brut = await journal.lireParametre(_cleAlertesAttente);
    var liste = <Map<String, Object?>>[];
    if (brut != null && brut.isNotEmpty) {
      try {
        liste = [
          for (final a in jsonDecode(brut) as List)
            (a as Map).cast<String, Object?>(),
        ];
      } catch (_) {}
    }
    return _attente ??= liste;
  }

  Future<void> _garderAlertes() => journal.ecrireParametre(
    _cleAlertesAttente,
    jsonEncode(_attente ?? const []),
  );

  /// Nombre d'alertes graves pas encore parties (pas de réseau).
  Future<int> nombreAlertesEnAttente() async =>
      (await _alertesEnAttente()).length;

  bool _envoiAlertesEnCours = false;

  /// Envoie les alertes gardées sur l'appareil, dans l'ordre. S'arrête à la
  /// première qui ne part pas (pas de réseau) : elle sera renvoyée plus tard.
  /// Renvoie le nombre d'alertes envoyées.
  Future<int> envoyerAlertesEnAttente() async {
    if (_envoiAlertesEnCours || estDemo) return 0;
    final t = transportAlertes;
    if (t == null) return 0;
    _envoiAlertesEnCours = true;
    var envoyees = 0;
    try {
      final attente = await _alertesEnAttente();
      if (attente.isEmpty) return 0;
      final jeton = await _jetonRelais();
      if (jeton == null) return 0;
      while (attente.isNotEmpty) {
        final a = attente.first;
        final heure = a['heure'] as int? ?? 0;
        final maintenantMs = maintenant().millisecondsSinceEpoch;
        var message = a['message'] as String? ?? '';
        // Partie en retard : on dit à quelle heure c'est arrivé.
        if (maintenantMs - heure > 60000) {
          final h = DateTime.fromMillisecondsSinceEpoch(heure);
          message +=
              ' (le ${h.day.toString().padLeft(2, '0')}/${h.month.toString().padLeft(2, '0')} '
              'à ${h.hour.toString().padLeft(2, '0')}:${h.minute.toString().padLeft(2, '0')}, '
              'envoyée au retour du réseau)';
        }
        try {
          await t.envoyer(
            jeton,
            Alerte(
              type: a['type'] as String? ?? '',
              message: message,
              heure: maintenantMs,
              appareil: journal.prefixeRecu,
            ),
          );
        } catch (_) {
          break; // pas de réseau : on garde la suite pour plus tard
        }
        attente.remove(a);
        envoyees++;
        await _garderAlertes();
      }
      return envoyees;
    } finally {
      _envoiAlertesEnCours = false;
    }
  }

  /// Relève les nouvelles alertes (appareil du patron).
  Future<int> releverAlertes() async {
    final t = transportAlertes;
    final jeton = await _jetonRelais();
    if (t == null || jeton == null || estDemo) return 0;
    try {
      final depuis =
          int.tryParse(await journal.lireParametre('relais.depuis') ?? '') ?? 0;
      final recues = await t.relever(jeton, depuis);
      if (recues.isEmpty) return 0;
      await journal.ecrireParametre(
        'relais.depuis',
        '${recues.map((a) => a.heure).reduce((a, b) => a > b ? a : b)}',
      );
      // Le résumé du soir n'est pas une alerte grave : il s'affiche à part
      // (après la synchronisation), sans bandeau rouge ni voix.
      final nouvelles = [
        for (final a in recues)
          if (a.type != typeResumeSoir) a,
      ];
      if (nouvelles.isEmpty) return 0;
      _alertes.addAll(nouvelles);
      await services.voix.dire('Alerte. ${nouvelles.last.message}');
      notifyListeners();
      return nouvelles.length;
    } catch (_) {
      return 0;
    }
  }

  bool _notificationsActivees = false;

  /// Téléphone du patron : abonnement aux notifications (application fermée).
  Future<bool> activerNotificationsPatron() async {
    if (_notificationsActivees || !estPatron || estDemo) {
      return _notificationsActivees;
    }
    final f = services.activerNotifications;
    final jeton = await _jetonRelais();
    if (f == null || jeton == null) return false;
    _notificationsActivees = await f(sujetAlertes(jeton));
    return _notificationsActivees;
  }

  /// Relève les alertes chaque minute tant que l'application est ouverte.
  void demarrerAlertesAuto({Duration periode = const Duration(minutes: 1)}) {
    _minuterieAlertes?.cancel();
    _minuterieAlertes = Timer.periodic(periode, (_) {
      // Tout appareil : renvoie les alertes gardées faute de réseau.
      envoyerAlertesEnAttente();
      if (estPatron) {
        releverAlertes();
        activerNotificationsPatron();
      }
    });
  }

  /// Appareils inscrits dans la boutique (nul si pas connecté).
  Future<List<Appareil>?> appareilsSynchro() async => _synchro?.appareils();

  /// Relève automatique tant que l'application est ouverte (Android impose
  /// 15 minutes au minimum pour une relève en arrière-plan ; ici, au premier
  /// plan, toutes les 15 minutes aussi, plus à chaque ouverture).
  void demarrerSynchroAuto({Duration periode = const Duration(minutes: 15)}) {
    _minuterie?.cancel();
    synchroniser();
    _minuterie = Timer.periodic(periode, (_) => synchroniser());
  }

  /// Nouveau téléphone : récupère toute la boutique depuis le Drive.
  /// Avec [remplace], il prend la place de cet ancien appareil.
  Future<int> retrouverBoutiqueDepuisDrive({Appareil? remplace}) async {
    final s = _synchro;
    if (s == null) {
      throw const ErreurZeroPerte('Connectez d\'abord le compte Google.');
    }
    final n = await s.recupererBoutique(remplace: remplace);
    await rechargerTout();
    if (n > 0) await allerA(EtapeAssistant.termine);
    return n;
  }

  /// Nouveau téléphone : remet une sauvegarde (fichier .zps).
  Future<int> retrouverBoutiqueDepuisFichier(
    List<int> fichier,
    String code,
  ) async {
    final n = await restaurerSauvegarde(fichier, code);
    if (n > 0) await allerA(EtapeAssistant.termine);
    return n;
  }

  // ---------------------------------------------------------------------------
  // Ajout d'un vendeur par QR code (0.35, docs/conception-ajout-vendeur.md)
  // ---------------------------------------------------------------------------

  static const String _cleModeSync = 'sync.mode';
  static const String _modeInvitation = 'invitation';
  static const String _cleJetonLong = 'sync.jeton_long';
  static const String _cleInvitation = 'sync.invitation';
  static const String _cleNomAppareil = 'appareil.nom';
  static const String _cleRetire = 'appareil.retire';
  static const String _cleCoupe = 'sync.coupe';

  /// Relais pour l'ajout des vendeurs (nul : pas de relais dans cette version).
  RelaisInvitations? relaisInvitations;

  bool _appareilRetire = false;
  bool _accesCoupe = false;
  int? _nbAppareils;

  /// Montrer « Ajouter mon vendeur » sur l'accueil du patron : seulement s'il
  /// reste de la place dans la licence (sinon, il passe par Gestion).
  bool get proposerAjoutVendeur {
    final lic = licence;
    return voitTout &&
        ajoutParQrPossible &&
        lic != null &&
        (_nbAppareils ?? 1) < lic.telephones;
  }

  /// Ce téléphone a été retiré par le patron : il est bloqué.
  bool get appareilRetire => _appareilRetire;

  /// Google a coupé l'accès de ce téléphone : refaire un QR code (les ventes
  /// faites ici sont gardées et partiront après le nouveau QR code).
  bool get accesCoupe => _accesCoupe;

  /// Ce téléphone est entré par QR code (ou code de secours).
  Future<bool> estEntreParInvitation() async =>
      await journal.lireParametre(_cleModeSync) == _modeInvitation;

  /// Ce téléphone (patron) peut-il ajouter un vendeur par QR code ?
  bool get ajoutParQrPossible =>
      relaisInvitations != null && services.codeGoogleServeur != null;

  /// Ce téléphone (vendeur) peut-il scanner un QR code ?
  bool get scannerPossible => services.lecteurQr != null;

  Future<void> _marquerRetire() async {
    _appareilRetire = true;
    _synchro = null;
    _minuterie?.cancel();
    await journal.ecrireParametre(_cleRetire, '1');
    // Le jeton Google est oublié : ce téléphone ne peut plus rien lire.
    await journal.ecrireParametre(_cleJetonLong, '');
    _utilisateurActuel = null;
    notifyListeners();
  }

  RelaisInvitations _relais() {
    final r = relaisInvitations;
    if (r == null) {
      throw const ErreurZeroPerte(
        'Cette version ne permet pas l\'ajout par QR code (relais absent). '
        'Mettez l\'application à jour.',
      );
    }
    return r;
  }

  StockageDistant _stockageParRelais(RelaisInvitations r, String jetonLong) {
    final j = JetonParRelais(r, jetonLong);
    final f = services.stockageParJeton;
    return f != null ? f(j.jeton) : StockageDriveAppData(jeton: j.jeton);
  }

  Future<bool> _connecterParRelais() async {
    final r = relaisInvitations;
    final jl = await journal.lireParametre(_cleJetonLong);
    if (r == null || jl == null || jl.isEmpty) return false;
    _synchro = Synchroniseur(
      journal: journal,
      stockage: _stockageParRelais(r, jl),
    );
    _compteSynchro = await journal.lireParametre('sync.compte');
    notifyListeners();
    return true;
  }

  /// Appareils encore dans la boutique, avec ceux qui ont été retirés à part
  /// (nul si le Drive n'est pas connecté).
  Future<({List<Appareil> actifs, Set<String> retires})?> mesAppareils() async {
    if (_synchro == null &&
        await journal.lireParametre('sync.compte') != null) {
      await connecterSynchro(silencieux: true);
    }
    final s = _synchro;
    if (s == null) return null;
    final r = await s.retraits();
    final tous = await s.appareils();
    return (
      actifs: [
        for (final a in tous)
          if (!r.containsKey(a.id)) a,
      ],
      retires: r.keys.toSet(),
    );
  }

  /// Identifiant de CE téléphone (pour le reconnaître dans la liste).
  String get idCeTelephone => journal.telephoneId;

  /// PATRON — 1re partie : contrôles, accord de Google (un toucher sur
  /// « Continuer »), création du vendeur et de son code. Rend le paquet secret
  /// à remettre par QR code ou par code de secours.
  Future<PaquetInvitation> preparerInvitation(String prenom) async {
    if (!voitTout) {
      throw const ErreurZeroPerte('Seul le patron peut ajouter un vendeur.');
    }
    final nom = prenom.trim();
    if (nom.isEmpty) {
      throw const ErreurZeroPerte('Écrivez le prénom du vendeur.');
    }
    final relais = _relais();
    final demanderCode = services.codeGoogleServeur;
    if (demanderCode == null) {
      throw const ErreurZeroPerte(
        'Sur cet appareil, ajoutez le vendeur avec « Autres façons ».',
      );
    }
    final lic = licence;
    if (lic == null) {
      throw const ErreurZeroPerte(
        'Activez d\'abord la licence de la boutique.',
      );
    }
    // Le Drive de la boutique doit être relié sur le téléphone du patron.
    if (_synchro == null && !await connecterSynchro()) {
      throw const ErreurZeroPerte(
        'Reliez d\'abord le compte Google de la boutique : '
        'Gestion, « Appareils et Drive ».',
      );
    }
    final r = await synchroniser();
    if (r == null) {
      throw ErreurZeroPerte(
        'Synchronisation impossible : vérifiez Internet. '
                '${await journal.lireParametre('sync.erreur') ?? ''}'
            .trim(),
      );
    }
    // Licence pleine : refusé, sauf pour refaire le QR code d'un vendeur dont
    // le téléphone est déjà dans la liste (même téléphone, pas de place en
    // plus ; un AUTRE téléphone serait refusé à son arrivée).
    final dejaLa = r.appareils.any(
      (a) =>
          a.parInvitation &&
          a.nom.toLowerCase() == 'téléphone de ${nom.toLowerCase()}',
    );
    if (r.appareils.length >= lic.telephones && !dejaLa) {
      throw ErreurLicencePleine(lic.telephones);
    }
    final idWeb = await relais.idClientWeb();
    if (idWeb == null || idWeb.isEmpty) {
      throw const ErreurZeroPerte(
        'Le relais n\'est pas encore prêt pour l\'ajout par QR code '
        '(identifiant Google à mettre dans Cloudflare).',
      );
    }
    final code = await demanderCode(idWeb);
    if (code == null) {
      throw const ErreurZeroPerte('Accord de Google annulé. Réessayez.');
    }
    final jetonRelais = await _jetonRelais();
    if (jetonRelais == null) {
      throw const ErreurZeroPerte('Synchronisez d\'abord la boutique.');
    }
    final jetonLong = await relais.echangerCode(jetonRelais, code);

    // Le vendeur : nouveau, ou le même prénom déjà là (nouveau code).
    final existant = vendeurs
        .where((v) => v.actif && v.nom.toLowerCase() == nom.toLowerCase())
        .firstOrNull;
    final String vendeurId;
    final String codeVendeur;
    if (existant != null) {
      vendeurId = existant.id;
      codeVendeur = await nouveauCodeVendeur(existant);
    } else {
      final v = await ajouterVendeur(nom: nom);
      vendeurId = v.vendeur.id;
      codeVendeur = v.code;
    }
    // Le vendeur doit être dans le Drive avant que son téléphone n'arrive.
    await synchroniser();
    return PaquetInvitation(
      invitation: _hexAleatoire(16),
      compte: _compteSynchro ?? '',
      jetonLong: jetonLong,
      jetonRelais: jetonRelais,
      vendeurId: vendeurId,
      vendeurNom: existant?.nom ?? nom,
      codeVendeur: codeVendeur,
      nomBoutique: config.nom,
    );
  }

  static String _hexAleatoire(int n) =>
      [for (final b in octetsAleatoires(n)) b.toRadixString(16).padLeft(2, '0')]
          .join();

  /// PATRON — 2e partie (QR code) : dépose le paquet chiffré sur le relais et
  /// rend ce qu'il faut afficher dans le QR code.
  Future<QrInvitation> publierQr(PaquetInvitation p) async {
    final relais = _relais();
    final qr = QrInvitation.nouveau();
    await relais.deposer(
      p.jetonRelais,
      qr.idBoite,
      await chiffrerPourQr(p, qr),
    );
    return qr;
  }

  /// PATRON : le vendeur a-t-il pris le paquet du QR code ?
  Future<bool> invitationPrise(QrInvitation qr) async =>
      !await _relais().present(qr.idBoite);

  /// PATRON — code de secours : ouvre l'attente sur le relais, rend le code.
  Future<String> ouvrirCodeSecours(PaquetInvitation p) async {
    final code = nouveauCodeSecours();
    await _relais().ouvrirAttente(p.jetonRelais, boiteDuCode(code));
    return code;
  }

  /// PATRON — code de secours : un téléphone a-t-il demandé à entrer ?
  Future<DemandeEntree?> demandeRecue(PaquetInvitation p, String code) =>
      _relais().lireDemande(p.jetonRelais, boiteDuCode(code));

  /// PATRON — code de secours : « OUI », le paquet part vers CE téléphone.
  Future<void> accepterDemande(
    PaquetInvitation p,
    String code,
    DemandeEntree d,
  ) async {
    final paquet = await chiffrerPourDemande(p, code, d.clePublique);
    await _relais().deposer(p.jetonRelais, boiteDuCode(code), paquet);
  }

  /// PATRON : le vendeur a-t-il pris le paquet du code de secours ?
  Future<bool> codeSecoursUtilise(String code) async =>
      !await _relais().present(boiteDuCode(code));

  /// VENDEUR : entre dans la boutique avec le texte du QR code.
  Future<PaquetInvitation> entrerParQr(String texte) async {
    final qr = QrInvitation.lire(texte);
    final brut = await _relais().prendre(qr.idBoite);
    if (brut == null) {
      throw const ErreurInvitation(
        'Ce QR code a expiré ou a déjà servi. Demandez au patron d\'en refaire un.',
      );
    }
    final p = await dechiffrerDepuisQr(brut, qr);
    await _rejoindre(p);
    return p;
  }

  /// VENDEUR — code de secours : demande à entrer. Nul si le patron n'attend
  /// pas ce code (faux ou expiré).
  Future<DemandeParCode?> demanderParCode(String code, String appareil) async {
    final d = await DemandeParCode.nouvelle(code);
    final ok = await _relais().demander(d.idBoite, d.clePublique, appareil);
    return ok ? d : null;
  }

  /// VENDEUR — code de secours : le patron a-t-il dit OUI ? Nul : pas encore.
  Future<PaquetInvitation?> verifierReponse(DemandeParCode d) async {
    final brut = await _relais().prendre(d.idBoite);
    if (brut == null) return null;
    final p = await d.ouvrir(brut);
    await _rejoindre(p);
    return p;
  }

  /// Le téléphone du vendeur se relie au Drive de la boutique avec le jeton
  /// du paquet, récupère la boutique et s'inscrit (licence contrôlée).
  Future<void> _rejoindre(PaquetInvitation p) async {
    if (_appareilRetire) throw const ErreurAppareilRetire();
    final relais = _relais();
    final ancienJeton = await journal.lireParametre('relais.jeton');
    final dejaInstalle = await journal.dernierNumero(journal.telephoneId) > 0;
    if (dejaInstalle && ancienJeton != null && ancienJeton != p.jetonRelais) {
      throw const ErreurZeroPerte(
        'Ce téléphone appartient déjà à une autre boutique.',
      );
    }
    final synchro = Synchroniseur(
      journal: journal,
      stockage: _stockageParRelais(relais, p.jetonLong),
    );
    final fichiers = await synchro.stockage.lister();
    // Une seule fois : un autre téléphone est-il déjà entré avec ce code ?
    if ((await synchro.appareils(fichiers)).any(
      (a) => a.invitation == p.invitation && a.id != journal.telephoneId,
    )) {
      throw const ErreurInvitationUtilisee();
    }
    await journal.ecrireParametre('relais.jeton', p.jetonRelais);
    if (!dejaInstalle) {
      await synchro.recupererBoutique();
      await rechargerTout();
    }
    final infos = await journal.lireParametre(_cleNomAppareil);
    final nomAppareil = infos ?? 'Téléphone de ${p.vendeurNom}';
    try {
      await synchro.synchroniser(
        maxAppareils: licence?.telephones,
        nomAppareil: nomAppareil,
        boutiqueId: licence?.boutiqueId,
        invitation: p.invitation,
        empreinte: empreinteJeton(p.jetonLong),
      );
    } on ErreurAppareilRetire {
      await _marquerRetire();
      rethrow;
    }
    await journal.ecrireParametre(_cleModeSync, _modeInvitation);
    await journal.ecrireParametre(_cleJetonLong, p.jetonLong);
    await journal.ecrireParametre(_cleInvitation, p.invitation);
    await journal.ecrireParametre(_cleNomAppareil, nomAppareil);
    await journal.ecrireParametre('sync.compte', p.compte);
    await journal.ecrireParametre(
      'sync.derniere',
      '${maintenant().millisecondsSinceEpoch}',
    );
    await journal.ecrireParametre('sync.erreur', '');
    await journal.ecrireParametre(_cleCoupe, '');
    _accesCoupe = false;
    _synchro = synchro;
    _compteSynchro = p.compte;
    await rechargerTout();
    if (etape != EtapeAssistant.termine) await allerA(EtapeAssistant.termine);
    notifyListeners();
  }

  /// PATRON : retire un appareil de la boutique.
  Future<void> retirerAppareil(Appareil a) async {
    if (!voitTout) {
      throw const ErreurZeroPerte('Seul le patron peut retirer un appareil.');
    }
    final s = _synchro;
    if (s == null) {
      throw const ErreurZeroPerte(
        'Reliez d\'abord le compte Google de la boutique.',
      );
    }
    // D'abord le relais (plus aucun accès), puis la boutique (licence libérée).
    if (a.empreinte != null) {
      final j = await _jetonRelais();
      if (j == null) throw const ErreurZeroPerte('Synchronisez d\'abord.');
      await _relais().retirer(j, a.empreinte!);
    }
    await s.retirer(
      a,
      quand: maintenant().millisecondsSinceEpoch,
      par: utilisateurActuel?.nom ?? '',
    );
    notifyListeners();
  }

  /// PATRON : « Couper tous les vendeurs » — annule chez Google toutes les
  /// autorisations données par QR code, et retire tous ces téléphones.
  /// Rend le nombre de téléphones retirés.
  Future<int> couperTousLesVendeurs() async {
    if (!voitTout) {
      throw const ErreurZeroPerte('Seul le patron peut faire cela.');
    }
    final relais = _relais();
    final demanderCode = services.codeGoogleServeur;
    final s = _synchro;
    if (demanderCode == null || s == null) {
      throw const ErreurZeroPerte(
        'Reliez d\'abord le compte Google de la boutique.',
      );
    }
    final j = await _jetonRelais();
    if (j == null) throw const ErreurZeroPerte('Synchronisez d\'abord.');
    final idWeb = await relais.idClientWeb();
    if (idWeb == null) {
      throw const ErreurZeroPerte('Le relais n\'est pas prêt.');
    }
    final code = await demanderCode(idWeb);
    if (code == null) {
      throw const ErreurZeroPerte(
        'Accord de Google annulé. Rien n\'a été coupé.',
      );
    }
    await relais.couper(j, code);
    final quand = maintenant().millisecondsSinceEpoch;
    var n = 0;
    for (final a in (await mesAppareils())?.actifs ?? const <Appareil>[]) {
      if (!a.parInvitation || a.id == journal.telephoneId) continue;
      if (a.empreinte != null) await relais.retirer(j, a.empreinte!);
      await s.retirer(a, quand: quand, par: utilisateurActuel?.nom ?? '');
      n++;
    }
    notifyListeners();
    return n;
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

  // --- Produits et prix après l'installation (patron seul) -------------------

  void _patronSeul() {
    if (!voitTout) {
      throw const ErreurZeroPerte(
        'Seul le patron peut changer les produits et les prix.',
      );
    }
  }

  /// Nouveau produit : nom, unité, prix de vente, prix d'achat, seuil de
  /// stock bas, image, emballages (« carton de 12 »), stock de départ.
  Future<Produit> creerProduit({
    required String nom,
    required String uniteBase,
    required int prixVente,
    int? prixAchat,
    int seuilAlerteMilliemes = 0,
    String? emoji,
    String? photo,
    List<(String, int, int)> conditionnements = const [],
    int stockDepart = 0,
  }) async {
    _patronSeul();
    final n = nom.trim();
    if (n.isEmpty) throw const ErreurZeroPerte('Donnez un nom au produit.');
    if (prixVente <= 0) {
      throw const ErreurZeroPerte(
        'Le prix de vente doit être plus grand que 0.',
      );
    }
    final existe = _produits.any(
      (p) => p.nom.trim().toLowerCase() == n.toLowerCase(),
    );
    if (existe) {
      throw ErreurZeroPerte('Un produit s\'appelle déjà « $n ».');
    }
    final id = await journal.definirProduit(
      nom: n,
      uniteBase: uniteBase.trim().isEmpty ? 'pièce' : uniteBase.trim(),
      prixUnitaire: prixVente,
      prixAchat: prixAchat,
      seuilAlerteMilliemes: seuilAlerteMilliemes,
      emoji: emoji,
      photo: photo,
      auteurId: auteurActuel,
    );
    for (final (nomC, unites, prix) in conditionnements) {
      if (nomC.trim().isEmpty || unites <= 0) continue;
      await journal.definirConditionnement(
        produitId: id,
        nom: nomC.trim(),
        facteurMilliemes: unites * milliemesParUnite,
        prixVente: prix,
        auteurId: auteurActuel,
      );
    }
    if (stockDepart > 0) {
      await journal.enregistrerArrivage(
        produitId: id,
        nombre: stockDepart,
        coutTotal: (prixAchat ?? 0) * stockDepart,
        auteurId: auteurActuel,
      );
    }
    await rechargerProduits();
    return journal.produit(id);
  }

  /// Modifie un produit (nouvelle version ; les ventes passées ne changent
  /// pas). Un changement de prix écrit l'ancien prix dans le journal.
  Future<void> modifierProduit(
    Produit p, {
    String? nom,
    String? uniteBase,
    int? prixVente,
    int? prixAchat,
    int? seuilAlerteMilliemes,
    String? emoji,
    String? photo,
    bool effacerPhoto = false,
    bool? actif,
  }) async {
    _patronSeul();
    final n = (nom ?? p.nom).trim();
    if (n.isEmpty) throw const ErreurZeroPerte('Donnez un nom au produit.');
    final prix = prixVente ?? p.prixUnitaire;
    if (prix <= 0 && (actif ?? p.actif)) {
      throw const ErreurZeroPerte(
        'Le prix de vente doit être plus grand que 0.',
      );
    }
    final autre = _produits.any(
      (x) => x.id != p.id && x.nom.trim().toLowerCase() == n.toLowerCase(),
    );
    if (autre) throw ErreurZeroPerte('Un produit s\'appelle déjà « $n ».');
    await journal.definirProduit(
      produitId: p.id,
      nom: n,
      uniteBase: (uniteBase ?? p.uniteBase).trim().isEmpty
          ? p.uniteBase
          : (uniteBase ?? p.uniteBase).trim(),
      prixUnitaire: prix,
      seuilAlerteMilliemes: seuilAlerteMilliemes ?? p.seuilAlerteMilliemes,
      emballage: p.emballage,
      consigne: p.consigne,
      emoji: emoji ?? p.emoji,
      catalogueId: p.catalogueId,
      auMontant: p.auMontant,
      photo: effacerPhoto ? null : (photo ?? p.photo),
      actif: actif ?? p.actif,
      prixAchat: prixAchat ?? p.prixAchat,
      prixPrecedent: prix != p.prixUnitaire && p.prixUnitaire > 0
          ? p.prixUnitaire
          : null,
      auteurId: auteurActuel,
    );
    await rechargerProduits();
  }

  /// Masque un produit qui ne se vend plus (il disparaît de « Vendre ») ou le
  /// fait revenir. Rien n'est effacé : ventes et historique restent.
  Future<void> masquerProduit(Produit p, {bool masquer = true}) =>
      modifierProduit(p, actif: !masquer);

  /// Tous les produits, masqués compris (page « Produits et prix »).
  Future<List<Produit>> tousLesProduits() =>
      journal.produits(memeInactifs: true);

  /// Change le prix d'un emballage (« carton de 12 »).
  Future<void> changerPrixConditionnement(
    Produit p,
    Conditionnement c,
    int prix,
  ) async {
    _patronSeul();
    if (prix < 0) {
      throw const ErreurZeroPerte('Un prix ne peut pas être négatif.');
    }
    await journal.definirConditionnement(
      conditionnementId: c.id,
      produitId: p.id,
      nom: c.nom,
      facteurMilliemes: c.facteurMilliemes,
      prixVente: prix,
      aVerifier: false,
      auteurId: auteurActuel,
    );
    await rechargerProduits();
  }

  /// Ajoute un emballage à un produit existant.
  Future<void> ajouterConditionnement(
    Produit p, {
    required String nom,
    required int unites,
    required int prix,
  }) async {
    _patronSeul();
    if (nom.trim().isEmpty) {
      throw const ErreurZeroPerte('Donnez un nom (ex. « carton de 12 »).');
    }
    await journal.definirConditionnement(
      produitId: p.id,
      nom: nom.trim(),
      facteurMilliemes: unites * milliemesParUnite,
      prixVente: prix,
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
        prixAchat: p.prixAchat,
        // Premier prix (installation) : pas d'« ancien prix ».
        prixPrecedent: p.prixUnitaire > 0 ? p.prixUnitaire : null,
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
    this.septJours = const [],
    required this.meilleurs,
    this.meilleurs30Jours = const [],
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

  /// Ventes des 7 derniers jours : (jour, total).
  final List<(DateTime, int)> septJours;

  /// Les 3 produits qui ont rapporté le plus : (nom, montant).
  final List<(String, int)> meilleurs;

  /// Les 5 produits qui ont rapporté le plus sur les 30 derniers jours.
  final List<(String, int)> meilleurs30Jours;

  /// Produits à racheter : (produit, stock en millièmes, raison).
  final List<(Produit, int, RaisonStockBas)> stockBas;
}

/// Ce que montre la page « Ma caisse ».
class EtatCaisseJour {
  const EtatCaisseJour({
    required this.ouverte,
    required this.fonds,
    required this.attendus,
    required this.sessions,
    this.heureOuverture,
    this.ouvertPar,
  });

  final bool ouverte;
  final int? heureOuverture;
  final String? ouvertPar;

  /// Fond initial (espèces laissées pour rendre la monnaie).
  final int fonds;

  /// Ce qui doit être dans chaque caisse (vide pour un vendeur).
  final Map<ModePaiement, int> attendus;

  /// Dernières caisses fermées (la plus récente d'abord).
  final List<FermetureCaisse> sessions;
}

/// Un jour d'un rapport (semaine ou mois).
class JourRapport {
  const JourRapport({
    required this.jour,
    required this.ventes,
    required this.benefice,
    required this.depenses,
  });
  final DateTime jour;
  final int ventes;
  final int benefice;
  final int depenses;
}

/// Rapport du patron pour un jour, une semaine ou un mois.
class Rapport {
  const Rapport({
    required this.periode,
    required this.debut,
    required this.fin,
    required this.ventes,
    required this.nombreVentes,
    required this.benefice,
    required this.depenses,
    required this.retours,
    required this.creditAccorde,
    required this.creditRembourse,
    required this.creditsDus,
    required this.inventaires,
    required this.meilleurs,
    required this.jours,
  });

  final Periode periode;
  final DateTime debut;

  /// Fin exclue (minuit du jour suivant la période).
  final DateTime fin;

  /// Ventes encaissées (annulations et retours déduits).
  final int ventes;
  final int nombreVentes;
  final int benefice;
  final int depenses;

  /// Argent rendu aux clients (retours partiels).
  final int retours;

  /// Crédit donné pendant la période (ventes à crédit, après retours).
  final int creditAccorde;

  /// Crédit remboursé par les clients pendant la période.
  final int creditRembourse;

  /// Ce que les clients doivent aujourd'hui.
  final int creditsDus;
  final List<Inventaire> inventaires;
  final List<(String, int)> meilleurs;
  final List<JourRapport> jours;

  /// Marchandise manquante (−) ou en trop (+) constatée aux inventaires.
  int get ecartsInventaires => inventaires.fold(0, (s, i) => s + i.ecartFrancs);
}

/// Panier refait depuis un devis.
class PanierDevis {
  const PanierDevis({
    required this.panier,
    required this.valable,
    required this.totalChange,
  });
  final Panier panier;

  /// Devis encore valable : ses prix sont gardés.
  final bool valable;

  /// Le total n'est plus celui du devis (devis expiré et prix changés, ou
  /// produit disparu).
  final bool totalChange;
}
