// Relais simulé pour l'ajout des vendeurs : mêmes règles que relais/worker.js
// (10 minutes, une seule lecture, liste noire, « Couper tous »).
import 'package:zero_perte/synchro/invitation.dart';
import 'package:zero_perte/synchro/synchro.dart';

class FauxRelaisInvitations implements RelaisInvitations {
  FauxRelaisInvitations({DateTime Function()? horloge})
    : horloge = horloge ?? DateTime.now;

  DateTime Function() horloge;

  /// Vrai : le relais ne répond pas (pas de réseau).
  bool horsLigne = false;

  /// Nul : le propriétaire n'a pas encore mis l'identifiant dans Cloudflare.
  String? idWeb = 'id-web.apps.googleusercontent.com';

  final Map<String, (String, DateTime)> boites = {};
  final Set<String> attentes = {};
  final Map<String, DemandeEntree> demandes = {};
  final Set<String> listeNoire = {};
  final Set<String> jetonsDonnes = {};
  final Set<String> jetonsAnnules = {};
  final List<String> appels = [];
  int _n = 0;

  void _reseau(String appel) {
    appels.add(appel);
    if (horsLigne) {
      throw const ErreurRelais('Pas de réseau, ou le relais ne répond pas.');
    }
  }

  @override
  Future<String?> idClientWeb() async {
    _reseau('id');
    return idWeb;
  }

  @override
  Future<String> echangerCode(String jetonRelais, String code) async {
    _reseau('echange');
    if (code != 'code-google-ok') throw const ErreurRelais('refusé par Google');
    final j = 'jeton-long-${++_n}';
    jetonsDonnes.add(j);
    return j;
  }

  @override
  Future<AccesGoogle> acces(String jetonLong) async {
    _reseau('acces');
    if (listeNoire.contains(empreinteJeton(jetonLong))) {
      throw const ErreurAccesRetire();
    }
    if (!jetonsDonnes.contains(jetonLong) ||
        jetonsAnnules.contains(jetonLong)) {
      throw const ErreurAccesCoupe();
    }
    return AccesGoogle(
      'acces-$jetonLong',
      horloge().add(const Duration(hours: 1)),
    );
  }

  /// Google refuse un accès si l'autorisation a été annulée (« Couper »).
  /// (La liste noire, elle, n'annule pas un accès déjà donné : au plus 1 h.)
  bool accesValide(String acces) =>
      !jetonsAnnules.contains(acces.replaceFirst('acces-', ''));

  @override
  Future<void> retirer(String jetonRelais, String empreinte) async {
    _reseau('retirer');
    listeNoire.add(empreinte);
  }

  @override
  Future<void> couper(String jetonRelais, String code) async {
    _reseau('couper');
    if (code != 'code-google-ok') throw const ErreurRelais('refusé par Google');
    jetonsAnnules.addAll(jetonsDonnes);
  }

  @override
  Future<void> deposer(String jetonRelais, String boite, String paquet) async {
    _reseau('deposer');
    boites[boite] = (paquet, horloge().add(dureeInvitation));
  }

  @override
  Future<String?> prendre(String boite) async {
    _reseau('prendre');
    final b = boites.remove(boite);
    if (b == null || horloge().isAfter(b.$2)) return null;
    return b.$1;
  }

  @override
  Future<bool> present(String boite) async {
    _reseau('present');
    final b = boites[boite];
    return b != null && !horloge().isAfter(b.$2);
  }

  @override
  Future<void> ouvrirAttente(String jetonRelais, String boite) async {
    _reseau('attente');
    attentes.add(boite);
  }

  @override
  Future<bool> demander(
    String boite,
    String clePublique,
    String appareil,
  ) async {
    _reseau('demander');
    if (!attentes.contains(boite) || demandes.containsKey(boite)) return false;
    demandes[boite] = DemandeEntree(
      clePublique: clePublique,
      appareil: appareil,
    );
    return true;
  }

  @override
  Future<DemandeEntree?> lireDemande(String jetonRelais, String boite) async {
    _reseau('lireDemande');
    return demandes[boite];
  }
}

/// Le Drive de la boutique vu par un téléphone entré par QR code : chaque
/// accès demande d'abord un jeton au relais (comme le vrai Google Drive).
class DriveParJeton implements StockageDistant {
  DriveParJeton(this.drive, this.jeton, {this.reseau});
  final StockageMemoire drive;
  final Future<String> Function({bool renouveler}) jeton;

  /// Partagé avec le relais simulé : « hors ligne » coupe aussi Google Drive.
  final FauxRelaisInvitations? reseau;

  Future<void> _verifier() async {
    final r = reseau;
    if (r?.horsLigne ?? false) throw const ErreurRelais('Pas de réseau.');
    final t = await jeton();
    // Comme Google : un accès dont l'autorisation a été annulée est refusé
    // (401), et le téléphone redemande un accès au relais.
    if (r != null && !r.accesValide(t)) await jeton(renouveler: true);
  }

  @override
  Future<List<FichierDistant>> lister() async {
    await _verifier();
    return drive.lister();
  }

  @override
  Future<List<int>> lire(FichierDistant fichier) async {
    await _verifier();
    return drive.lire(fichier);
  }

  @override
  Future<void> ecrire(String nom, List<int> contenu) async {
    await _verifier();
    await drive.ecrire(nom, contenu);
  }
}
