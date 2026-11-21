/// Accès à la base locale : toute écriture passe par le JOURNAL des opérations.
///
/// Principe : chaque méthode d'écriture crée UNE opération (avec numéro d'ordre,
/// auteur, heure, empreinte chaînée), puis la « projette » dans les tables de
/// calcul, le tout dans une seule transaction. Si quoi que ce soit échoue, rien
/// n'est écrit.
///
/// La projection se fait uniquement à partir du contenu de l'opération : les
/// opérations reçues plus tard des autres téléphones (étape D3) seront projetées
/// exactement de la même façon.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

import '../domaine/argent.dart';
import '../domaine/boutique.dart';
import '../domaine/calculs.dart';
import '../domaine/licence.dart';
import '../domaine/operation.dart';
import '../domaine/quantites.dart';
import '../domaine/recu.dart';
import '../domaine/utilisateurs.dart';
import 'reglages.dart';
import 'schema.dart';

/// Moyens de paiement. Espèces, Flooz et Mixx ont chacun leur caisse ;
/// le crédit n'est PAS une caisse : l'argent arrivera plus tard (remboursement).
enum ModePaiement {
  especes('especes'),
  flooz('flooz'),
  mixx('mixx'),
  credit('credit');

  const ModePaiement(this.code);
  final String code;

  /// Les moyens de paiement qui ont une caisse (fermeture, dépenses…).
  static const List<ModePaiement> caisses = [especes, flooz, mixx];

  static ModePaiement depuisCode(String code) =>
      values.firstWhere((m) => m.code == code);
}

/// Erreur métier à montrer à l'utilisateur (message en français simple).
class ErreurZeroPerte implements Exception {
  const ErreurZeroPerte(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Une ligne demandée par le vendeur.
class LigneDemandee {
  /// « 2 sacs », « 3 bols » : un nombre d'un conditionnement
  /// (ou de l'unité de base si [conditionnementId] est nul).
  const LigneDemandee.quantite({
    required this.produitId,
    this.conditionnementId,
    required int this.nombre,
  }) : montant = null;

  /// « Donne pour 100 F » : vente au montant.
  const LigneDemandee.auMontant({
    required this.produitId,
    required int this.montant,
  }) : nombre = null,
       conditionnementId = null;

  final String produitId;
  final String? conditionnementId;
  final int? nombre;
  final int? montant;
}

/// Version actuelle d'un produit.
class Produit {
  const Produit({
    required this.id,
    required this.nom,
    required this.uniteBase,
    required this.prixUnitaire,
    required this.seuilAlerteMilliemes,
    this.emballage,
    this.consigne = 0,
    this.emoji,
    this.catalogueId,
    this.auMontant = false,
    this.photo,
    this.actif = true,
  });
  final String id;
  final String nom;
  final String uniteBase;

  /// Prix de vente d'UNE unité de base (F).
  final int prixUnitaire;
  final int seuilAlerteMilliemes;
  final String? emballage;
  final int consigne;

  /// Pictogramme (emoji) du catalogue, ou nul.
  final String? emoji;

  /// Identifiant du produit dans le catalogue prérempli, ou nul.
  final String? catalogueId;

  /// Vrai si on peut le vendre « au montant » (« donne pour 100 F »).
  final bool auMontant;

  /// Photo prise par le patron (JPEG en base64), ou nulle.
  final String? photo;
  final bool actif;

  /// Vrai si le patron a fixé un prix (un produit sans prix ne peut pas être vendu).
  bool get aUnPrix => prixUnitaire > 0;
}

/// Résultat d'une vente enregistrée.
class VenteEnregistree {
  const VenteEnregistree({
    required this.operation,
    required this.recu,
    required this.total,
    required this.monnaie,
  });
  final Operation operation;

  /// Numéro du reçu, par ex. « A-000042 ».
  final String recu;
  final int total;

  /// Monnaie à rendre (espèces) ; nul pour Mobile Money.
  final MonnaieARendre? monnaie;
}

/// Résumé d'une vente (pour la liste des ventes du jour).
class VenteResume {
  const VenteResume({
    required this.operationId,
    required this.heure,
    required this.auteurId,
    required this.donnees,
    this.motifAnnulation,
  });

  final String operationId;
  final int heure;
  final String auteurId;
  final Map<String, Object?> donnees;

  /// Motif si la vente a été annulée, sinon nul.
  final String? motifAnnulation;

  bool get annulee => motifAnnulation != null;
  String get recu => donnees['recu'] as String;
  int get total => donnees['total'] as int;
  ModePaiement get mode =>
      ModePaiement.depuisCode(donnees['mode_paiement'] as String);
  List<Map<String, Object?>> get lignes => [
    for (final l in (donnees['lignes'] as List))
      (l as Map).cast<String, Object?>(),
  ];
}

/// Bénéfice estimé sur une période.
class ResumeBenefice {
  const ResumeBenefice({
    required this.ventes,
    required this.couts,
    required this.lignesSansCout,
  });
  final int ventes;
  final int couts;

  /// Lignes vendues dont on ne connaît pas encore le prix d'achat (aucun
  /// arrivage enregistré) : elles ne comptent pas dans le bénéfice.
  final int lignesSansCout;
  int get benefice => ventes - couts;
}

class JournalLocal implements ReglagesLocaux {
  JournalLocal._(this._db, this._telephoneId, this._prefixeRecu, this._horloge);

  final Database _db;

  /// Identifiant unique de CE téléphone (repris d'une sauvegarde restaurée).
  String get telephoneId => _telephoneId;
  String _telephoneId;

  /// Préfixe des reçus de ce téléphone (A, B, P…).
  String get prefixeRecu => _prefixeRecu;
  String _prefixeRecu;

  final int Function() _horloge;

  /// Ouvre (ou crée) la base. [horloge] permet aux tests de fixer l'heure.
  static Future<JournalLocal> ouvrir({
    required DatabaseFactory fabrique,
    required String chemin,
    String prefixeRecu = 'A',
    int Function()? horloge,
  }) async {
    if (!prefixeRecuValide(prefixeRecu)) {
      throw ErreurZeroPerte('Préfixe de reçu invalide : « $prefixeRecu ».');
    }
    final db = await fabrique.openDatabase(
      chemin,
      options: OpenDatabaseOptions(
        version: versionSchema,
        onCreate: (db, version) async {
          final lot = db.batch();
          for (final sql in [...creationTables, ...creationDeclencheurs]) {
            lot.execute(sql);
          }
          for (var v = 2; v <= version; v++) {
            for (final sql in migrations[v] ?? const <String>[]) {
              lot.execute(sql);
            }
          }
          await lot.commit(noResult: true);
        },
        onUpgrade: (db, ancienne, nouvelle) async {
          final lot = db.batch();
          for (var v = ancienne + 1; v <= nouvelle; v++) {
            for (final sql in migrations[v] ?? const <String>[]) {
              lot.execute(sql);
            }
          }
          await lot.commit(noResult: true);
        },
      ),
    );
    var telephoneId = await _lireParametre(db, 'telephone_id');
    if (telephoneId == null) {
      telephoneId = nouvelIdentifiant();
      await _ecrireParametre(db, 'telephone_id', telephoneId);
    }
    var prefixe = await _lireParametre(db, 'prefixe_recu');
    if (prefixe == null) {
      prefixe = prefixeRecu;
      await _ecrireParametre(db, 'prefixe_recu', prefixe);
    }
    return JournalLocal._(
      db,
      telephoneId,
      prefixe,
      horloge ?? () => DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> fermer() => _db.close();

  /// Réglage local du téléphone (seule table modifiable).
  @override
  Future<String?> lireParametre(String cle) => _lireParametre(_db, cle);

  /// Écrit un réglage local du téléphone.
  @override
  Future<void> ecrireParametre(String cle, String valeur) =>
      _ecrireParametre(_db, cle, valeur);

  static Future<String?> _lireParametre(DatabaseExecutor db, String cle) async {
    final r = await db.query('parametres', where: 'cle = ?', whereArgs: [cle]);
    return r.isEmpty ? null : r.first['valeur'] as String;
  }

  static Future<void> _ecrireParametre(
    DatabaseExecutor db,
    String cle,
    String valeur,
  ) => db.rawInsert(
    'INSERT OR REPLACE INTO parametres (cle, valeur) VALUES (?, ?)',
    [cle, valeur],
  );

  // ---------------------------------------------------------------------------
  // Journal
  // ---------------------------------------------------------------------------

  /// Ajoute une opération de CE téléphone et la projette (dans la transaction [t]).
  Future<Operation> _ajouter(
    Transaction t, {
    required String type,
    required String auteurId,
    required Map<String, Object?> donnees,
  }) async {
    // Vérifie tout de suite qu'il n'y a pas de nombre à virgule.
    jsonCanonique(donnees);
    final derniere = await t.rawQuery(
      'SELECT numero, empreinte FROM operations WHERE telephone_id = ? '
      'ORDER BY numero DESC LIMIT 1',
      [telephoneId],
    );
    final numero = derniere.isEmpty ? 1 : (derniere.first['numero'] as int) + 1;
    final precedente = derniere.isEmpty
        ? ''
        : derniere.first['empreinte'] as String;
    final id = nouvelIdentifiant();
    final heure = _horloge();
    final empreinte = calculerEmpreinte(
      id: id,
      telephoneId: telephoneId,
      numero: numero,
      type: type,
      auteurId: auteurId,
      heureTelephone: heure,
      donnees: donnees,
      empreintePrecedente: precedente,
    );
    final op = Operation(
      id: id,
      telephoneId: telephoneId,
      numero: numero,
      type: type,
      auteurId: auteurId,
      heureTelephone: heure,
      donnees: donnees,
      empreintePrecedente: precedente,
      empreinte: empreinte,
    );
    await t.insert('operations', {
      'id': op.id,
      'telephone_id': op.telephoneId,
      'numero': op.numero,
      'type': op.type,
      'auteur_id': op.auteurId,
      'heure_telephone': op.heureTelephone,
      'donnees': jsonCanonique(op.donnees),
      'empreinte_precedente': op.empreintePrecedente,
      'empreinte': op.empreinte,
      'signature': op.signature,
    });
    await projeter(t, op);
    return op;
  }

  /// Remplit les tables de calcul à partir d'une opération (de ce téléphone ou,
  /// plus tard, d'un autre téléphone de la boutique).
  static Future<void> projeter(DatabaseExecutor t, Operation op) async {
    final d = op.donnees;
    switch (op.type) {
      case TypeOperation.produitDefini:
        await t.insert('produits_versions', {
          'operation_id': op.id,
          'produit_id': d['produit'],
          'nom': d['nom'],
          'unite_base': d['unite_base'],
          'prix_unitaire': d['prix_unitaire'],
          'seuil_alerte_milliemes': d['seuil_alerte_milliemes'] ?? 0,
          'emballage': d['emballage'],
          'consigne': d['consigne'] ?? 0,
          'actif': (d['actif'] ?? true) == true ? 1 : 0,
          'emoji': d['emoji'],
          'catalogue_id': d['catalogue'],
          'au_montant': d['au_montant'] == true ? 1 : 0,
          'photo': d['photo'],
        });
      case TypeOperation.conditionnementDefini:
        await t.insert('conditionnements_versions', {
          'operation_id': op.id,
          'conditionnement_id': d['conditionnement'],
          'produit_id': d['produit'],
          'nom': d['nom'],
          'facteur_milliemes': d['facteur_milliemes'],
          'prix_vente': d['prix_vente'],
          'actif': (d['actif'] ?? true) == true ? 1 : 0,
          'a_verifier': d['a_verifier'] == true ? 1 : 0,
        });
      case TypeOperation.arrivage:
      case TypeOperation.perte:
        await t.insert('mouvements_stock', {
          'operation_id': op.id,
          'ligne': 1,
          'produit_id': d['produit'],
          'quantite_milliemes': d['quantite_milliemes'],
          'nature': op.type == TypeOperation.arrivage ? 'arrivage' : 'perte',
          'prix_total': 0,
          'cout_total': d['cout_total'],
        });
      case TypeOperation.inventaire:
        // Le stock prend la valeur comptée : écart = compté − attendu.
        final lignes = (d['lignes'] as List).cast<Map>();
        for (var i = 0; i < lignes.length; i++) {
          final l = lignes[i];
          final ecart = (l['compte'] as int) - (l['attendu'] as int);
          if (ecart == 0) continue;
          await t.insert('mouvements_stock', {
            'operation_id': op.id,
            'ligne': i + 1,
            'produit_id': l['produit'],
            'quantite_milliemes': ecart,
            'nature': 'inventaire',
            'prix_total': 0,
            'cout_total': null,
          });
        }
      case TypeOperation.vente:
      case TypeOperation.venteAnnulee:
        final annulation = op.type == TypeOperation.venteAnnulee;
        final lignes = (d['lignes'] as List).cast<Map>();
        for (var i = 0; i < lignes.length; i++) {
          final l = lignes[i];
          final signe = annulation ? 1 : -1;
          await t.insert('mouvements_stock', {
            'operation_id': op.id,
            'ligne': i + 1,
            'produit_id': l['produit'],
            'quantite_milliemes': signe * (l['quantite_milliemes'] as int),
            'nature': annulation ? 'annulation' : 'vente',
            'prix_total': -signe * (l['prix_total'] as int),
            'cout_total': l['cout_total'] == null
                ? null
                : -signe * (l['cout_total'] as int),
          });
        }
        if (d['mode_paiement'] == ModePaiement.credit.code &&
            d['client'] != null) {
          await t.insert('mouvements_credit', {
            'operation_id': op.id,
            'client_id': d['client'],
            'montant': annulation ? -(d['total'] as int) : d['total'],
            'nature': annulation ? 'annulation' : 'vente',
            'mode_paiement': null,
          });
        }
        if (annulation) {
          await t.insert('ventes_annulees', {
            'operation_id': op.id,
            'vente_operation_id': d['vente'],
            'motif': d['motif'],
            'total': d['total'],
            'mode_paiement': d['mode_paiement'],
          });
        } else {
          await t.insert('ventes', {
            'operation_id': op.id,
            'telephone_id': op.telephoneId,
            'numero_recu': d['numero_recu'],
            'recu': d['recu'],
            'total': d['total'],
            'mode_paiement': d['mode_paiement'],
            'montant_recu': d['montant_recu'],
            'monnaie_rendue': d['monnaie_rendue'],
            'reference_paiement': d['reference_paiement'],
            'client_id': d['client'],
          });
        }
      case TypeOperation.venteRetour:
        // La marchandise rendue revient en stock ; l'argent sort de la caisse
        // choisie (ou le crédit du client diminue).
        final lignes = (d['lignes'] as List).cast<Map>();
        for (var i = 0; i < lignes.length; i++) {
          final l = lignes[i];
          await t.insert('mouvements_stock', {
            'operation_id': op.id,
            'ligne': i + 1,
            'produit_id': l['produit'],
            'quantite_milliemes': l['quantite_milliemes'],
            'nature': 'retour',
            'prix_total': -(l['prix_total'] as int),
            'cout_total': l['cout_total'] == null
                ? null
                : -(l['cout_total'] as int),
          });
        }
        if (d['mode_paiement'] == ModePaiement.credit.code) {
          if (d['client'] != null) {
            await t.insert('mouvements_credit', {
              'operation_id': op.id,
              'client_id': d['client'],
              'montant': -(d['total'] as int),
              'nature': 'retour',
              'mode_paiement': null,
            });
          }
        } else {
          await t.insert('mouvements_caisse', {
            'operation_id': op.id,
            'nature': op.type,
            'mode_paiement': d['mode_paiement'],
            'montant': d['total'],
            'motif': d['motif'],
          });
        }
      case TypeOperation.emballage:
        await t.insert('mouvements_emballages', {
          'operation_id': op.id,
          'ligne': 1,
          'emballage': d['emballage'],
          'quantite': d['quantite'],
          'consigne': d['consigne'] ?? 0,
        });
      case TypeOperation.clientDefini:
        await t.insert('clients_versions', {
          'operation_id': op.id,
          'client_id': d['client'],
          'nom': d['nom'],
          'telephone': d['telephone'] ?? '',
          'photo': d['photo'],
          'plafond': d['plafond'],
          'actif': (d['actif'] ?? true) == true ? 1 : 0,
          'quartier': d['quartier'],
          'email': d['email'],
        });
      case TypeOperation.fournisseurDefini:
        await t.insert('fournisseurs_versions', {
          'operation_id': op.id,
          'fournisseur_id': d['fournisseur'],
          'nom': d['nom'],
          'telephone': d['telephone'] ?? '',
          'actif': (d['actif'] ?? true) == true ? 1 : 0,
        });
      case TypeOperation.achatFournisseur:
        await t.insert('mouvements_fournisseur', {
          'operation_id': op.id,
          'fournisseur_id': d['fournisseur'],
          'montant': d['montant'],
          'nature': 'achat',
          'note': d['note'],
          'mode_paiement': null,
        });
      case TypeOperation.paiementFournisseur:
        await t.insert('mouvements_fournisseur', {
          'operation_id': op.id,
          'fournisseur_id': d['fournisseur'],
          'montant': -(d['montant'] as int),
          'nature': 'paiement',
          'note': null,
          'mode_paiement': d['mode_paiement'],
        });
        // Le paiement sort de la caisse de ce moyen de paiement.
        await t.insert('mouvements_caisse', {
          'operation_id': op.id,
          'nature': op.type,
          'mode_paiement': d['mode_paiement'],
          'montant': d['montant'],
          'motif': 'Fournisseur',
        });
      case TypeOperation.remboursementCredit:
        await t.insert('mouvements_credit', {
          'operation_id': op.id,
          'client_id': d['client'],
          'montant': -(d['montant'] as int),
          'nature': 'remboursement',
          'mode_paiement': d['mode_paiement'],
        });
        // L'argent du remboursement entre dans la caisse de ce moyen de paiement.
        await t.insert('mouvements_caisse', {
          'operation_id': op.id,
          'nature': op.type,
          'mode_paiement': d['mode_paiement'],
          'montant': d['montant'],
          'motif': null,
        });
      case TypeOperation.fondsDeCaisse:
      case TypeOperation.depense:
      case TypeOperation.retraitPatron:
        await t.insert('mouvements_caisse', {
          'operation_id': op.id,
          'nature': op.type,
          'mode_paiement': d['mode_paiement'],
          'montant': d['montant'],
          'motif': d['motif'],
        });
      default:
        // Type inconnu (opération venant d'une version plus récente) : il reste
        // dans le journal, sans projection. Rien n'est perdu.
        break;
    }
  }

  /// Toutes les opérations d'un téléphone, dans l'ordre.
  Future<List<Operation>> operationsDuTelephone(String idTelephone) async {
    final lignes = await _db.query(
      'operations',
      where: 'telephone_id = ?',
      whereArgs: [idTelephone],
      orderBy: 'numero',
    );
    return [
      for (final l in lignes)
        Operation(
          id: l['id'] as String,
          telephoneId: l['telephone_id'] as String,
          numero: l['numero'] as int,
          type: l['type'] as String,
          auteurId: l['auteur_id'] as String,
          heureTelephone: l['heure_telephone'] as int,
          donnees: (jsonDecode(l['donnees'] as String) as Map)
              .cast<String, Object?>(),
          empreintePrecedente: l['empreinte_precedente'] as String,
          empreinte: l['empreinte'] as String,
          signature: l['signature'] as String?,
        ),
    ];
  }

  // ---------------------------------------------------------------------------
  // Crédit client
  // ---------------------------------------------------------------------------

  /// Crée ([clientId] nul) ou modifie une fiche client. Renvoie son identifiant.
  Future<String> definirClient({
    String? clientId,
    required String nom,
    String telephone = '',
    String? photo,
    required int plafond,
    bool actif = true,
    String quartier = '',
    String email = '',
    required String auteurId,
  }) async {
    if (nom.trim().isEmpty) {
      throw const ErreurZeroPerte('Écrivez le nom du client.');
    }
    final mail = email.trim();
    if (mail.isNotEmpty &&
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(mail)) {
      throw const ErreurZeroPerte('Adresse e-mail incorrecte.');
    }
    if (plafond < 0) {
      throw const ErreurZeroPerte('Le plafond ne peut pas être négatif.');
    }
    final id = clientId ?? nouvelIdentifiant();
    await _db.transaction(
      (t) => _ajouter(
        t,
        type: TypeOperation.clientDefini,
        auteurId: auteurId,
        donnees: {
          'client': id,
          'nom': nom.trim(),
          'telephone': telephone.trim(),
          'photo': photo,
          'plafond': plafond,
          'actif': actif,
          if (quartier.trim().isNotEmpty) 'quartier': quartier.trim(),
          if (mail.isNotEmpty) 'email': mail,
        },
      ),
    );
    return id;
  }

  static Client _lireClient(Map<String, Object?> l, int solde) => Client(
    id: l['client_id'] as String,
    nom: l['nom'] as String,
    telephone: l['telephone'] as String,
    photo: l['photo'] as String?,
    plafond: l['plafond'] as int,
    actif: (l['actif'] as int) == 1,
    solde: solde,
    quartier: (l['quartier'] as String?) ?? '',
    email: (l['email'] as String?) ?? '',
  );

  static const _derniereVersionClient =
      'SELECT cv.* FROM clients_versions cv JOIN operations o ON o.id = cv.operation_id '
      'WHERE cv.client_id = ? ORDER BY o.heure_telephone DESC, o.numero DESC LIMIT 1';

  static Future<Client?> _clientActuel(DatabaseExecutor t, String id) async {
    final r = await t.rawQuery(_derniereVersionClient, [id]);
    return r.isEmpty ? null : _lireClient(r.first, 0);
  }

  static Future<int> _solde(DatabaseExecutor t, String clientId) async =>
      ((await t.rawQuery(
            'SELECT SUM(montant) AS s FROM mouvements_credit WHERE client_id = ?',
            [clientId],
          )).first['s']
          as int?) ??
      0;

  /// Solde (ce que le client doit encore) ; 0 s'il ne doit rien.
  Future<int> soldeClient(String clientId) => _solde(_db, clientId);

  /// Un client avec son solde, ou nul.
  Future<Client?> client(String clientId) async {
    final r = await _db.rawQuery(_derniereVersionClient, [clientId]);
    if (r.isEmpty) return null;
    return _lireClient(r.first, await _solde(_db, clientId));
  }

  /// Tous les clients (dernière version), avec leur solde.
  Future<List<Client>> clients() async {
    final ids = await _db.rawQuery(
      'SELECT DISTINCT client_id AS c FROM clients_versions',
    );
    final soldes = {
      for (final l in await _db.rawQuery(
        'SELECT client_id AS c, SUM(montant) AS s FROM mouvements_credit GROUP BY client_id',
      ))
        l['c'] as String: (l['s'] as int?) ?? 0,
    };
    final liste = <Client>[];
    for (final l in ids) {
      final id = l['c'] as String;
      final r = await _db.rawQuery(_derniereVersionClient, [id]);
      liste.add(_lireClient(r.first, soldes[id] ?? 0));
    }
    return liste;
  }

  /// Le client rembourse [montant] (tout ou partie de sa dette) ; l'argent
  /// entre dans la caisse de [mode].
  Future<Operation> enregistrerRemboursement({
    required String clientId,
    required int montant,
    required ModePaiement mode,
    required String auteurId,
  }) {
    if (montant <= 0) {
      throw const ErreurZeroPerte('Le montant doit être positif.');
    }
    if (mode == ModePaiement.credit) {
      throw const ErreurZeroPerte(
        'Un remboursement se fait en espèces, Flooz ou Mixx.',
      );
    }
    return _db.transaction((t) async {
      final solde = await _solde(t, clientId);
      if (montant > solde) {
        throw ErreurZeroPerte(
          solde <= 0
              ? 'Ce client ne doit rien.'
              : 'Le client doit seulement ${formatFrancs(solde)}.',
        );
      }
      return _ajouter(
        t,
        type: TypeOperation.remboursementCredit,
        auteurId: auteurId,
        donnees: {
          'client': clientId,
          'montant': montant,
          'mode_paiement': mode.code,
          'reste': solde - montant,
        },
      );
    });
  }

  /// Historique du crédit d'un client, le plus récent d'abord.
  Future<List<MouvementCredit>> historiqueCredit(String clientId) async {
    final r = await _db.rawQuery(
      'SELECT m.*, o.heure_telephone AS h, o.donnees AS d FROM mouvements_credit m '
      'JOIN operations o ON o.id = m.operation_id WHERE m.client_id = ? '
      'ORDER BY o.heure_telephone DESC, o.numero DESC',
      [clientId],
    );
    return [
      for (final l in r)
        MouvementCredit(
          operationId: l['operation_id'] as String,
          heure: l['h'] as int,
          montant: l['montant'] as int,
          nature: l['nature'] as String,
          recu: (jsonDecode(l['d'] as String) as Map)['recu'] as String?,
          mode: l['mode_paiement'] == null
              ? null
              : ModePaiement.depuisCode(l['mode_paiement'] as String),
        ),
    ];
  }

  /// Total que tous les clients doivent encore.
  Future<int> totalCredits() async =>
      ((await _db.rawQuery('SELECT SUM(montant) AS s FROM mouvements_credit'))
              .first['s']
          as int?) ??
      0;

  // ---------------------------------------------------------------------------
  // Crédit fournisseur (C4)
  // ---------------------------------------------------------------------------

  Future<String> definirFournisseur({
    String? fournisseurId,
    required String nom,
    String telephone = '',
    bool actif = true,
    required String auteurId,
  }) async {
    if (nom.trim().isEmpty) {
      throw const ErreurZeroPerte('Écrivez le nom du fournisseur.');
    }
    final id = fournisseurId ?? nouvelIdentifiant();
    await _db.transaction(
      (t) => _ajouter(
        t,
        type: TypeOperation.fournisseurDefini,
        auteurId: auteurId,
        donnees: {
          'fournisseur': id,
          'nom': nom.trim(),
          'telephone': telephone.trim(),
          'actif': actif,
        },
      ),
    );
    return id;
  }

  /// Fournisseurs actifs avec ce que la boutique leur doit.
  Future<List<Fournisseur>> fournisseurs() async {
    final ids = await _db.rawQuery(
      'SELECT DISTINCT fournisseur_id AS f FROM fournisseurs_versions',
    );
    final soldes = {
      for (final l in await _db.rawQuery(
        'SELECT fournisseur_id AS f, SUM(montant) AS s FROM mouvements_fournisseur GROUP BY fournisseur_id',
      ))
        l['f'] as String: (l['s'] as int?) ?? 0,
    };
    final liste = <Fournisseur>[];
    for (final l in ids) {
      final id = l['f'] as String;
      final r = await _db.rawQuery(
        'SELECT fv.* FROM fournisseurs_versions fv JOIN operations o ON o.id = fv.operation_id '
        'WHERE fv.fournisseur_id = ? ORDER BY o.heure_telephone DESC, o.numero DESC LIMIT 1',
        [id],
      );
      final v = r.first;
      if ((v['actif'] as int) != 1) continue;
      liste.add(
        Fournisseur(
          id: id,
          nom: v['nom'] as String,
          telephone: v['telephone'] as String,
          doit: soldes[id] ?? 0,
        ),
      );
    }
    liste.sort((a, b) => b.doit.compareTo(a.doit));
    return liste;
  }

  /// Achat à crédit chez un fournisseur (la boutique lui doit [montant]).
  Future<void> enregistrerAchatFournisseur({
    required String fournisseurId,
    required int montant,
    String note = '',
    required String auteurId,
  }) async {
    if (montant <= 0) {
      throw const ErreurZeroPerte('Le montant doit être positif.');
    }
    await _db.transaction(
      (t) => _ajouter(
        t,
        type: TypeOperation.achatFournisseur,
        auteurId: auteurId,
        donnees: {
          'fournisseur': fournisseurId,
          'montant': montant,
          if (note.trim().isNotEmpty) 'note': note.trim(),
        },
      ),
    );
  }

  /// La boutique paie (tout ou partie de) sa dette ; l'argent sort de la caisse.
  Future<void> enregistrerPaiementFournisseur({
    required String fournisseurId,
    required int montant,
    required ModePaiement mode,
    required String auteurId,
  }) async {
    if (montant <= 0) {
      throw const ErreurZeroPerte('Le montant doit être positif.');
    }
    if (mode == ModePaiement.credit) {
      throw const ErreurZeroPerte('Payez en espèces, Flooz ou Mixx.');
    }
    await _db.transaction((t) async {
      final doit =
          ((await t.rawQuery(
                'SELECT SUM(montant) AS s FROM mouvements_fournisseur WHERE fournisseur_id = ?',
                [fournisseurId],
              )).first['s']
              as int?) ??
          0;
      if (montant > doit) {
        throw ErreurZeroPerte(
          doit <= 0
              ? 'La boutique ne doit rien à ce fournisseur.'
              : 'La boutique doit seulement ${formatFrancs(doit)}.',
        );
      }
      await _ajouter(
        t,
        type: TypeOperation.paiementFournisseur,
        auteurId: auteurId,
        donnees: {
          'fournisseur': fournisseurId,
          'montant': montant,
          'mode_paiement': mode.code,
        },
      );
    });
  }

  /// Historique d'un fournisseur, le plus récent d'abord : (heure, montant, note).
  Future<List<(int, int, String?)>> historiqueFournisseur(String id) async => [
    for (final l in await _db.rawQuery(
      'SELECT m.montant AS m, m.note AS n, o.heure_telephone AS h FROM mouvements_fournisseur m '
      'JOIN operations o ON o.id = m.operation_id WHERE m.fournisseur_id = ? '
      'ORDER BY o.heure_telephone DESC, o.numero DESC',
      [id],
    ))
      (l['h'] as int, l['m'] as int, l['n'] as String?),
  ];

  // ---------------------------------------------------------------------------
  // Synchronisation entre appareils (bloc D)
  // ---------------------------------------------------------------------------

  /// Dernier numéro d'opération connu pour un téléphone (0 si aucune).
  Future<int> dernierNumero(String idTelephone) async =>
      ((await _db.rawQuery(
            'SELECT MAX(numero) AS n FROM operations WHERE telephone_id = ?',
            [idTelephone],
          )).first['n']
          as int?) ??
      0;

  /// Téléphones présents dans le journal (le nôtre et ceux déjà importés).
  Future<Set<String>> telephonesConnus() async => {
    for (final l in await _db.rawQuery(
      'SELECT DISTINCT telephone_id AS t FROM operations',
    ))
      l['t'] as String,
  };

  /// Opérations de ce téléphone après le numéro [apres] (pour l'envoi).
  Future<List<Operation>> mesOperationsApres(int apres) async =>
      (await operationsDuTelephone(telephoneId))
          .where((o) => o.numero > apres)
          .toList();

  /// Ajoute des opérations venues d'AUTRES appareils de la boutique.
  /// Chaque chaîne est vérifiée (suite sans trou, empreintes) avant d'écrire ;
  /// les opérations déjà connues sont ignorées. Renvoie le nombre ajouté.
  Future<int> importerOperations(List<Operation> recues) async {
    final parTelephone = <String, List<Operation>>{};
    for (final op in recues) {
      // Jamais nos propres opérations.
      if (op.telephoneId == telephoneId) {
        continue;
      }
      parTelephone.putIfAbsent(op.telephoneId, () => []).add(op);
    }
    final aAjouter = <Operation>[];
    for (final MapEntry(key: tel, value: liste) in parTelephone.entries) {
      liste.sort((a, b) => a.numero.compareTo(b.numero));
      final connues = await operationsDuTelephone(tel);
      final dernier = connues.isEmpty ? 0 : connues.last.numero;
      final nouvelles = liste.where((o) => o.numero > dernier).toList();
      if (nouvelles.isEmpty) continue;
      // La suite doit continuer exactement la chaîne déjà connue.
      final chaine = [...connues, ...nouvelles];
      final problemes = verifierChaine(chaine);
      if (problemes.isNotEmpty) {
        throw ErreurZeroPerte(
          'Données reçues d\'un autre appareil refusées : ${problemes.first}',
        );
      }
      aAjouter.addAll(nouvelles);
    }
    if (aAjouter.isEmpty) return 0;
    aAjouter.sort(
      (a, b) => a.heureTelephone != b.heureTelephone
          ? a.heureTelephone.compareTo(b.heureTelephone)
          : a.numero.compareTo(b.numero),
    );
    await _db.transaction((t) async {
      for (final op in aAjouter) {
        await t.insert('operations', {
          'id': op.id,
          'telephone_id': op.telephoneId,
          'numero': op.numero,
          'type': op.type,
          'auteur_id': op.auteurId,
          'heure_telephone': op.heureTelephone,
          'donnees': jsonCanonique(op.donnees),
          'empreinte_precedente': op.empreintePrecedente,
          'empreinte': op.empreinte,
          'signature': op.signature,
        });
        await projeter(t, op);
      }
    });
    return aAjouter.length;
  }

  /// Ce téléphone prend l'identité d'un ancien appareil de la boutique (perdu
  /// ou cassé) : il continue sa chaîne et ses numéros de reçus. Possible
  /// seulement si ce téléphone n'a encore rien écrit lui-même.
  Future<void> reprendreIdentite(String idTelephone, String prefixe) async {
    if ((await dernierNumero(telephoneId)) > 0 && idTelephone != telephoneId) {
      throw const ErreurZeroPerte(
        'Ce téléphone a déjà des opérations : il ne peut pas remplacer un autre appareil.',
      );
    }
    await _ecrireParametre(_db, 'telephone_id', idTelephone);
    await _ecrireParametre(_db, 'prefixe_recu', prefixe);
    _telephoneId = idTelephone;
    _prefixeRecu = prefixe;
  }

  /// Remet les opérations de CE téléphone (reprises d'un ancien appareil).
  /// Le journal ne doit encore rien contenir pour ce téléphone.
  Future<int> restaurerOperationsPropres(List<Operation> ops) async {
    if (ops.isEmpty) return 0;
    if (await dernierNumero(telephoneId) > 0) {
      throw const ErreurZeroPerte(
        'Ce téléphone a déjà ses propres opérations.',
      );
    }
    final miennes = ops.where((o) => o.telephoneId == telephoneId).toList()
      ..sort((a, b) => a.numero.compareTo(b.numero));
    if (verifierChaine(miennes).isNotEmpty) {
      throw const ErreurZeroPerte(
        'Données de l\'ancien appareil modifiées ou incomplètes.',
      );
    }
    await _db.transaction((t) async {
      for (final op in miennes) {
        await t.insert('operations', {
          'id': op.id,
          'telephone_id': op.telephoneId,
          'numero': op.numero,
          'type': op.type,
          'auteur_id': op.auteurId,
          'heure_telephone': op.heureTelephone,
          'donnees': jsonCanonique(op.donnees),
          'empreinte_precedente': op.empreintePrecedente,
          'empreinte': op.empreinte,
          'signature': op.signature,
        });
        await projeter(t, op);
      }
    });
    return miennes.length;
  }

  /// Change le préfixe des reçus (nouvel appareil d'une boutique existante).
  Future<void> changerPrefixeRecu(String prefixe) async {
    if (!prefixeRecuValide(prefixe)) {
      throw ErreurZeroPerte('Préfixe de reçu invalide : « $prefixe ».');
    }
    await _ecrireParametre(_db, 'prefixe_recu', prefixe);
    _prefixeRecu = prefixe;
  }

  /// Opérations venues de ce fichier JSON (format des fichiers de synchronisation).
  static List<Operation> operationsDepuisJson(List<int> json) {
    final d = (jsonDecode(utf8.decode(json)) as Map).cast<String, Object?>();
    return [
      for (final l in (d['operations'] as List).cast<Map>())
        Operation(
          id: l['id'] as String,
          telephoneId: l['telephone_id'] as String,
          numero: l['numero'] as int,
          type: l['type'] as String,
          auteurId: l['auteur_id'] as String,
          heureTelephone: l['heure_telephone'] as int,
          donnees: (jsonDecode(l['donnees'] as String) as Map)
              .cast<String, Object?>(),
          empreintePrecedente: l['empreinte_precedente'] as String,
          empreinte: l['empreinte'] as String,
          signature: l['signature'] as String?,
        ),
    ];
  }

  /// Fichier JSON contenant [ops] (même format que la sauvegarde).
  static List<int> operationsVersJson(List<Operation> ops) => utf8.encode(
    jsonEncode({
      'format': 1,
      'operations': [
        for (final op in ops)
          {
            'id': op.id,
            'telephone_id': op.telephoneId,
            'numero': op.numero,
            'type': op.type,
            'auteur_id': op.auteurId,
            'heure_telephone': op.heureTelephone,
            'donnees': jsonCanonique(op.donnees),
            'empreinte_precedente': op.empreintePrecedente,
            'empreinte': op.empreinte,
            'signature': op.signature,
          },
      ],
    }),
  );

  // ---------------------------------------------------------------------------
  // Sauvegarde
  // ---------------------------------------------------------------------------

  /// Tout le journal (JSON, en clair) : la seule source des calculs.
  Future<Uint8List> exporterJournal() async {
    final lignes = await _db.query(
      'operations',
      orderBy: 'telephone_id, numero',
    );
    return Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'format': 1,
          'telephone_id': telephoneId,
          'prefixe_recu': prefixeRecu,
          'operations': lignes,
        }),
      ),
    );
  }

  /// Nombre d'opérations enregistrées.
  Future<int> nombreOperations() async =>
      (await _db.rawQuery('SELECT COUNT(*) AS n FROM operations')).first['n']
          as int;

  /// Restaure une sauvegarde dans un journal VIDE (nouveau téléphone).
  /// Chaque chaîne est vérifiée avant d'écrire quoi que ce soit. Le téléphone
  /// reprend l'identité (et le préfixe de reçu) du téléphone sauvegardé.
  /// Renvoie le nombre d'opérations restaurées.
  Future<int> restaurerJournal(List<int> json) async {
    if (await nombreOperations() > 0) {
      throw const ErreurZeroPerte(
        'Ce téléphone contient déjà des ventes : restauration impossible.',
      );
    }
    final Map<String, Object?> d;
    try {
      d = (jsonDecode(utf8.decode(json)) as Map).cast<String, Object?>();
    } catch (_) {
      throw const ErreurZeroPerte('Sauvegarde illisible.');
    }
    if (d['format'] != 1) {
      throw const ErreurZeroPerte('Sauvegarde d\'une version inconnue.');
    }
    final ops = [
      for (final l in (d['operations'] as List).cast<Map>())
        Operation(
          id: l['id'] as String,
          telephoneId: l['telephone_id'] as String,
          numero: l['numero'] as int,
          type: l['type'] as String,
          auteurId: l['auteur_id'] as String,
          heureTelephone: l['heure_telephone'] as int,
          donnees: (jsonDecode(l['donnees'] as String) as Map)
              .cast<String, Object?>(),
          empreintePrecedente: l['empreinte_precedente'] as String,
          empreinte: l['empreinte'] as String,
          signature: l['signature'] as String?,
        ),
    ];
    final parTelephone = <String, List<Operation>>{};
    for (final op in ops) {
      parTelephone.putIfAbsent(op.telephoneId, () => []).add(op);
    }
    for (final liste in parTelephone.values) {
      liste.sort((a, b) => a.numero.compareTo(b.numero));
      if (verifierChaine(liste).isNotEmpty) {
        throw const ErreurZeroPerte(
          'Sauvegarde modifiée ou incomplète : restauration refusée.',
        );
      }
    }
    ops.sort(
      (a, b) => a.heureTelephone != b.heureTelephone
          ? a.heureTelephone.compareTo(b.heureTelephone)
          : a.numero.compareTo(b.numero),
    );
    final idTelephone = d['telephone_id'] as String;
    final prefixe = d['prefixe_recu'] as String;
    await _db.transaction((t) async {
      for (final op in ops) {
        await t.insert('operations', {
          'id': op.id,
          'telephone_id': op.telephoneId,
          'numero': op.numero,
          'type': op.type,
          'auteur_id': op.auteurId,
          'heure_telephone': op.heureTelephone,
          'donnees': jsonCanonique(op.donnees),
          'empreinte_precedente': op.empreintePrecedente,
          'empreinte': op.empreinte,
          'signature': op.signature,
        });
        await projeter(t, op);
      }
      await _ecrireParametre(t, 'telephone_id', idTelephone);
      await _ecrireParametre(t, 'prefixe_recu', prefixe);
    });
    _telephoneId = idTelephone;
    _prefixeRecu = prefixe;
    return ops.length;
  }

  /// Vérifie la chaîne des opérations de ce téléphone. Liste vide = tout est en ordre.
  Future<List<String>> verifierMaChaine() async =>
      verifierChaine(await operationsDuTelephone(telephoneId));

  // ---------------------------------------------------------------------------
  // Produits et conditionnements (réservés au patron : contrôle des rôles en B7)
  // ---------------------------------------------------------------------------

  /// Crée un produit, ou enregistre une nouvelle version d'un produit existant
  /// (nouveau prix, nouveau nom…). L'ancienne version reste dans l'historique.
  Future<String> definirProduit({
    String? produitId,
    required String nom,
    required String uniteBase,
    required int prixUnitaire,
    int seuilAlerteMilliemes = 0,
    String? emballage,
    int consigne = 0,
    String? emoji,
    String? catalogueId,
    bool auMontant = false,
    String? photo,
    bool actif = true,
    required String auteurId,
  }) async {
    if (prixUnitaire < 0 || consigne < 0) {
      throw const ErreurZeroPerte('Un prix ne peut pas être négatif.');
    }
    final id = produitId ?? nouvelIdentifiant();
    await _db.transaction(
      (t) => _ajouter(
        t,
        type: TypeOperation.produitDefini,
        auteurId: auteurId,
        donnees: {
          'produit': id,
          'nom': nom,
          'unite_base': uniteBase,
          'prix_unitaire': prixUnitaire,
          'seuil_alerte_milliemes': seuilAlerteMilliemes,
          'emballage': emballage,
          'consigne': consigne,
          'actif': actif,
          'emoji': emoji,
          'catalogue': catalogueId,
          'au_montant': auMontant,
          'photo': photo,
        },
      ),
    );
    return id;
  }

  /// Crée (ou change) un conditionnement : « sac = 40 bols, 23 000 F ».
  Future<String> definirConditionnement({
    String? conditionnementId,
    required String produitId,
    required String nom,
    required int facteurMilliemes,
    required int prixVente,
    bool aVerifier = false,
    bool actif = true,
    required String auteurId,
  }) async {
    if (facteurMilliemes <= 0) {
      throw const ErreurZeroPerte(
        'Un conditionnement doit contenir quelque chose.',
      );
    }
    if (prixVente < 0) {
      throw const ErreurZeroPerte('Un prix ne peut pas être négatif.');
    }
    final id = conditionnementId ?? nouvelIdentifiant();
    await _db.transaction((t) async {
      await _produitActuel(t, produitId); // le produit doit exister
      await _ajouter(
        t,
        type: TypeOperation.conditionnementDefini,
        auteurId: auteurId,
        donnees: {
          'conditionnement': id,
          'produit': produitId,
          'nom': nom,
          'facteur_milliemes': facteurMilliemes,
          'prix_vente': prixVente,
          'actif': actif,
          'a_verifier': aVerifier,
        },
      );
    });
    return id;
  }

  /// Version actuelle d'un produit (la plus récente).
  Future<Produit> produit(String produitId) => _produitActuel(_db, produitId);

  static Future<Produit> _produitActuel(
    DatabaseExecutor t,
    String produitId,
  ) async {
    final r = await t.rawQuery(
      'SELECT pv.* FROM produits_versions pv JOIN operations o ON o.id = pv.operation_id '
      'WHERE pv.produit_id = ? ORDER BY o.heure_telephone DESC, o.numero DESC LIMIT 1',
      [produitId],
    );
    if (r.isEmpty) throw const ErreurZeroPerte('Produit introuvable.');
    final l = r.first;
    return Produit(
      id: l['produit_id'] as String,
      nom: l['nom'] as String,
      uniteBase: l['unite_base'] as String,
      prixUnitaire: l['prix_unitaire'] as int,
      seuilAlerteMilliemes: l['seuil_alerte_milliemes'] as int,
      emballage: l['emballage'] as String?,
      consigne: l['consigne'] as int,
      emoji: l['emoji'] as String?,
      catalogueId: l['catalogue_id'] as String?,
      auMontant: l['au_montant'] == 1,
      photo: l['photo'] as String?,
      actif: l['actif'] == 1,
    );
  }

  static Produit _produitDepuisLigne(Map<String, Object?> l) => Produit(
    id: l['produit_id'] as String,
    nom: l['nom'] as String,
    uniteBase: l['unite_base'] as String,
    prixUnitaire: l['prix_unitaire'] as int,
    seuilAlerteMilliemes: l['seuil_alerte_milliemes'] as int,
    emballage: l['emballage'] as String?,
    consigne: l['consigne'] as int,
    emoji: l['emoji'] as String?,
    catalogueId: l['catalogue_id'] as String?,
    auMontant: l['au_montant'] == 1,
    photo: l['photo'] as String?,
    actif: l['actif'] == 1,
  );

  /// Tous les produits (version actuelle de chacun), actifs seulement par défaut,
  /// triés par nom.
  Future<List<Produit>> produits({bool memeInactifs = false}) async {
    final r = await _db.rawQuery(
      'SELECT pv.*, o.heure_telephone AS h, o.numero AS n FROM produits_versions pv '
      'JOIN operations o ON o.id = pv.operation_id ORDER BY h, n',
    );
    final parId = <String, Map<String, Object?>>{};
    for (final l in r) {
      parId[l['produit_id'] as String] = l;
    }
    final liste = [
      for (final l in parId.values)
        if (memeInactifs || l['actif'] == 1) _produitDepuisLigne(l),
    ]..sort((a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()));
    return liste;
  }

  /// Conditionnements actuels d'un produit.
  Future<List<Conditionnement>> conditionnements(String produitId) =>
      _conditionnements(_db, produitId);

  static Future<List<Conditionnement>> _conditionnements(
    DatabaseExecutor t,
    String produitId,
  ) async {
    final r = await t.rawQuery(
      'SELECT cv.*, o.heure_telephone AS h, o.numero AS n FROM conditionnements_versions cv '
      'JOIN operations o ON o.id = cv.operation_id WHERE cv.produit_id = ? '
      'ORDER BY h, n',
      [produitId],
    );
    // La dernière version de chaque conditionnement l'emporte.
    final parId = <String, Map<String, Object?>>{};
    for (final l in r) {
      parId[l['conditionnement_id'] as String] = l;
    }
    return [
      for (final l in parId.values)
        if (l['actif'] == 1)
          Conditionnement(
            id: l['conditionnement_id'] as String,
            nom: l['nom'] as String,
            facteurMilliemes: l['facteur_milliemes'] as int,
            prixVente: l['prix_vente'] as int,
            aVerifier: l['a_verifier'] == 1,
          ),
    ];
  }

  // ---------------------------------------------------------------------------
  // Stock
  // ---------------------------------------------------------------------------

  /// Arrivage de marchandise (patron) : [nombre] conditionnements (ou unités de
  /// base) achetés pour [coutTotal] F au total.
  Future<Operation> enregistrerArrivage({
    required String produitId,
    String? conditionnementId,
    required int nombre,
    required int coutTotal,
    required String auteurId,
  }) {
    if (nombre <= 0) {
      throw const ErreurZeroPerte('La quantité doit être positive.');
    }
    if (coutTotal < 0) {
      throw const ErreurZeroPerte('Un coût ne peut pas être négatif.');
    }
    return _db.transaction((t) async {
      await _produitActuel(t, produitId);
      final milliemes = await _versMilliemes(
        t,
        produitId,
        conditionnementId,
        nombre,
      );
      return _ajouter(
        t,
        type: TypeOperation.arrivage,
        auteurId: auteurId,
        donnees: {
          'produit': produitId,
          'conditionnement': conditionnementId,
          'nombre': nombre,
          'quantite_milliemes': milliemes,
          'cout_total': coutTotal,
        },
      );
    });
  }

  /// Perte déclarée (casse, périmé, pourri…), avec un motif obligatoire.
  Future<Operation> enregistrerPerte({
    required String produitId,
    required int milliemes,
    required String motif,
    required String auteurId,
  }) {
    if (milliemes <= 0) {
      throw const ErreurZeroPerte('La quantité doit être positive.');
    }
    if (motif.trim().isEmpty) {
      throw const ErreurZeroPerte('Le motif est obligatoire.');
    }
    return _db.transaction((t) async {
      final cout = await _coutEstime(t, produitId, milliemes);
      return _ajouter(
        t,
        type: TypeOperation.perte,
        auteurId: auteurId,
        donnees: {
          'produit': produitId,
          'quantite_milliemes': -milliemes,
          'cout_total': cout,
          'motif': motif.trim(),
        },
      );
    });
  }

  /// Inventaire complet : [comptes] = quantité comptée par produit
  /// (millièmes). L'attendu est calculé ICI (le compteur ne le voit pas) ;
  /// le stock prend ensuite la valeur comptée.
  Future<Inventaire> enregistrerInventaire(
    Map<String, int> comptes, {
    required String auteurId,
  }) async {
    if (comptes.isEmpty) {
      throw const ErreurZeroPerte('Aucun produit compté.');
    }
    if (comptes.values.any((v) => v < 0)) {
      throw const ErreurZeroPerte(
        'Une quantité comptée ne peut pas être négative.',
      );
    }
    final op = await _db.transaction((t) async {
      final stocks = {
        for (final l in await t.rawQuery(
          'SELECT produit_id AS p, SUM(quantite_milliemes) AS s FROM mouvements_stock GROUP BY produit_id',
        ))
          l['p'] as String: (l['s'] as int?) ?? 0,
      };
      final lignes = <Map<String, Object?>>[];
      for (final MapEntry(key: id, value: compte) in comptes.entries) {
        final p = await _produitActuel(t, id);
        lignes.add({
          'produit': id,
          'attendu': stocks[id] ?? 0,
          'compte': compte,
          'prix_unitaire': p.prixUnitaire,
        });
      }
      return _ajouter(
        t,
        type: TypeOperation.inventaire,
        auteurId: auteurId,
        donnees: {'lignes': lignes},
      );
    });
    return Inventaire.depuisOperation(
      op.id,
      op.heureTelephone,
      op.auteurId,
      op.donnees,
    );
  }

  /// Inventaires passés, le plus récent d'abord.
  Future<List<Inventaire>> inventaires({int limite = 30}) async {
    final r = await _db.query(
      'operations',
      columns: ['id', 'heure_telephone', 'auteur_id', 'donnees'],
      where: 'type = ?',
      whereArgs: [TypeOperation.inventaire],
      orderBy: 'heure_telephone DESC, numero DESC',
      limit: limite,
    );
    return [
      for (final l in r)
        Inventaire.depuisOperation(
          l['id'] as String,
          l['heure_telephone'] as int,
          l['auteur_id'] as String,
          (jsonDecode(l['donnees'] as String) as Map).cast<String, Object?>(),
        ),
    ];
  }

  /// Stock actuel d'un produit, en millièmes d'unité de base.
  Future<int> stockMilliemes(String produitId) async {
    final r = await _db.rawQuery(
      'SELECT quantite_milliemes AS q FROM mouvements_stock WHERE produit_id = ?',
      [produitId],
    );
    return stockDepuisMouvements(r.map((l) => l['q'] as int));
  }

  /// Stock de tous les produits (millièmes d'unité de base), en une requête.
  Future<Map<String, int>> stocks() async {
    final r = await _db.rawQuery(
      'SELECT produit_id AS p, SUM(quantite_milliemes) AS s FROM mouvements_stock GROUP BY produit_id',
    );
    return {for (final l in r) l['p'] as String: (l['s'] as int?) ?? 0};
  }

  static Future<int> _versMilliemes(
    DatabaseExecutor t,
    String produitId,
    String? conditionnementId,
    int nombre,
  ) async {
    if (conditionnementId == null) return nombre * milliemesParUnite;
    final c = (await _conditionnements(
      t,
      produitId,
    )).where((c) => c.id == conditionnementId).firstOrNull;
    if (c == null) throw const ErreurZeroPerte('Conditionnement introuvable.');
    return versMilliemes(nombre, c);
  }

  /// Coût estimé d'une quantité, d'après le DERNIER arrivage du produit.
  /// Nul si aucun arrivage n'a encore été enregistré.
  static Future<int?> _coutEstime(
    DatabaseExecutor t,
    String produitId,
    int milliemes,
  ) async {
    final r = await t.rawQuery(
      'SELECT m.cout_total AS c, m.quantite_milliemes AS q FROM mouvements_stock m '
      'JOIN operations o ON o.id = m.operation_id '
      "WHERE m.produit_id = ? AND m.nature = 'arrivage' "
      'ORDER BY o.heure_telephone DESC, o.numero DESC LIMIT 1',
      [produitId],
    );
    if (r.isEmpty) return null;
    return coutPourQuantite(
      milliemes: milliemes,
      coutAchat: r.first['c'] as int,
      milliemesAchetes: r.first['q'] as int,
    );
  }

  // ---------------------------------------------------------------------------
  // Ventes
  // ---------------------------------------------------------------------------

  /// Enregistre une vente et son paiement. Le reçu reçoit le numéro suivant de ce
  /// téléphone (sans trou). En espèces, [montantRecu] est obligatoire et doit
  /// couvrir le total.
  Future<VenteEnregistree> enregistrerVente({
    required List<LigneDemandee> lignes,
    required ModePaiement mode,
    int? montantRecu,
    String? referencePaiement,
    String? clientId,
    required String auteurId,
  }) {
    if (lignes.isEmpty) throw const ErreurZeroPerte('La vente est vide.');
    if (mode == ModePaiement.credit && clientId == null) {
      throw const ErreurZeroPerte('Choisissez le client qui prend à crédit.');
    }
    return _db.transaction((t) async {
      final details = <Map<String, Object?>>[];
      var total = 0;
      for (final l in lignes) {
        final p = await _produitActuel(t, l.produitId);
        int milliemes;
        int prix;
        if (l.montant != null) {
          if (l.montant! <= 0) {
            throw const ErreurZeroPerte('Le montant doit être positif.');
          }
          milliemes = quantitePourMontant(
            montant: l.montant!,
            prixUnitaire: p.prixUnitaire,
          );
          prix = l.montant!;
        } else {
          final nombre = l.nombre!;
          if (nombre <= 0) {
            throw const ErreurZeroPerte('La quantité doit être positive.');
          }
          if (l.conditionnementId == null) {
            milliemes = nombre * milliemesParUnite;
            prix = nombre * p.prixUnitaire;
          } else {
            final c = (await _conditionnements(
              t,
              l.produitId,
            )).where((c) => c.id == l.conditionnementId).firstOrNull;
            if (c == null) {
              throw const ErreurZeroPerte('Conditionnement introuvable.');
            }
            milliemes = versMilliemes(nombre, c);
            prix = nombre * c.prixVente;
          }
        }
        details.add({
          'produit': p.id,
          'conditionnement': l.conditionnementId,
          'nombre': l.nombre,
          'au_montant': l.montant != null,
          'quantite_milliemes': milliemes,
          'prix_total': prix,
          'cout_total': await _coutEstime(t, p.id, milliemes),
        });
        total += prix;
      }

      MonnaieARendre? monnaie;
      if (mode == ModePaiement.especes) {
        if (montantRecu == null) {
          throw const ErreurZeroPerte('Indiquez l\'argent reçu du client.');
        }
        monnaie = calculerMonnaie(total: total, recu: montantRecu);
        if (!monnaie.suffisant) {
          throw ErreurZeroPerte('Il manque ${formatFrancs(monnaie.manque)}.');
        }
      }

      if (mode == ModePaiement.credit) {
        final c = await _clientActuel(t, clientId!);
        if (c == null || !c.actif) {
          throw const ErreurZeroPerte('Client introuvable.');
        }
        if (c.telephone.trim().isEmpty) {
          throw ErreurZeroPerte(
            'Ajoutez le téléphone de ${c.nom} pour lui faire crédit.',
          );
        }
        if (c.plafond == 0) {
          throw ErreurZeroPerte('Le patron ne fait plus crédit à ${c.nom}.');
        }
        final solde = await _solde(t, clientId);
        if (solde + total > c.plafond) {
          final reste = c.plafond - solde;
          throw ErreurZeroPerte(
            reste <= 0
                ? '${c.nom} a déjà atteint son plafond de ${formatFrancs(c.plafond)}.'
                : 'Plafond dépassé : ${c.nom} peut encore prendre ${formatFrancs(reste)} à crédit.',
          );
        }
      }

      final dernier = await t.rawQuery(
        'SELECT MAX(numero_recu) AS n FROM ventes WHERE telephone_id = ?',
        [telephoneId],
      );
      final numeroRecu = ((dernier.first['n'] as int?) ?? 0) + 1;
      final recu = formatNumeroRecu(prefixeRecu, numeroRecu);

      final op = await _ajouter(
        t,
        type: TypeOperation.vente,
        auteurId: auteurId,
        donnees: {
          'numero_recu': numeroRecu,
          'recu': recu,
          'lignes': details,
          'total': total,
          'mode_paiement': mode.code,
          'montant_recu': montantRecu,
          'monnaie_rendue': monnaie?.aRendre,
          'reference_paiement': referencePaiement,
          'client': ?clientId,
        },
      );
      return VenteEnregistree(
        operation: op,
        recu: recu,
        total: total,
        monnaie: monnaie,
      );
    });
  }

  /// Annule une vente (jamais de suppression) : la marchandise revient en stock,
  /// l'argent est déduit de la caisse. Le motif est obligatoire.
  Future<Operation> annulerVente({
    required String venteOperationId,
    required String motif,
    required String auteurId,
  }) {
    if (motif.trim().isEmpty) {
      throw const ErreurZeroPerte('Le motif est obligatoire.');
    }
    return _db.transaction((t) async {
      final deja = await t.query(
        'ventes_annulees',
        where: 'vente_operation_id = ?',
        whereArgs: [venteOperationId],
      );
      if (deja.isNotEmpty) {
        throw const ErreurZeroPerte('Cette vente est déjà annulée.');
      }
      final v = await t.rawQuery(
        'SELECT o.donnees FROM operations o WHERE o.id = ? AND o.type = ?',
        [venteOperationId, TypeOperation.vente],
      );
      if (v.isEmpty) throw const ErreurZeroPerte('Vente introuvable.');
      // Une vente qui a déjà eu un retour ne s'annule plus en entier (le
      // stock et l'argent rendus seraient comptés deux fois) : on fait un
      // retour pour le reste.
      if ((await _dejaRendus(t, venteOperationId)).isNotEmpty) {
        throw const ErreurZeroPerte(
          'Cette vente a déjà eu un retour : faites « Retour » pour le reste.',
        );
      }
      final vente =
          jsonDecode(v.first['donnees'] as String) as Map<String, Object?>;
      return _ajouter(
        t,
        type: TypeOperation.venteAnnulee,
        auteurId: auteurId,
        donnees: {
          'vente': venteOperationId,
          'recu': vente['recu'],
          'motif': motif.trim(),
          'lignes': vente['lignes'],
          'total': vente['total'],
          'mode_paiement': vente['mode_paiement'],
          if (vente['client'] != null) 'client': vente['client'],
        },
      );
    });
  }

  /// Ce qui a déjà été rendu pour chaque ligne d'une vente :
  /// index de la ligne → nombre d'unités rendues (1 = tout, pour une ligne
  /// vendue au montant).
  Future<Map<int, int>> dejaRendus(String venteOperationId) =>
      _dejaRendus(_db, venteOperationId);

  static Future<Map<int, int>> _dejaRendus(
    DatabaseExecutor t,
    String venteOperationId,
  ) async {
    final r = await t.rawQuery(
      'SELECT donnees FROM operations WHERE type = ?',
      [TypeOperation.venteRetour],
    );
    final rendus = <int, int>{};
    for (final l in r) {
      final d = jsonDecode(l['donnees'] as String) as Map;
      if (d['vente'] != venteOperationId) continue;
      for (final x in (d['lignes'] as List).cast<Map>()) {
        final i = x['ligne'] as int;
        rendus[i] = (rendus[i] ?? 0) + (x['nombre'] as int);
      }
    }
    return rendus;
  }

  /// Retour partiel d'une vente. [rendus] : index de la ligne → nombre
  /// d'unités rendues (pour une ligne vendue au montant : 1 = toute la ligne).
  /// La marchandise revient en stock ; le client est remboursé depuis la
  /// caisse [mode] (pour une vente à crédit : son crédit diminue).
  Future<Operation> enregistrerRetour({
    required String venteOperationId,
    required Map<int, int> rendus,
    required ModePaiement mode,
    required String motif,
    String? accordPatronId,
    required String auteurId,
  }) {
    if (motif.trim().isEmpty) {
      throw const ErreurZeroPerte('Le motif est obligatoire.');
    }
    return _db.transaction((t) async {
      final v = await t.rawQuery(
        'SELECT o.donnees FROM operations o WHERE o.id = ? AND o.type = ?',
        [venteOperationId, TypeOperation.vente],
      );
      if (v.isEmpty) throw const ErreurZeroPerte('Vente introuvable.');
      final annulee = await t.query(
        'ventes_annulees',
        where: 'vente_operation_id = ?',
        whereArgs: [venteOperationId],
      );
      if (annulee.isNotEmpty) {
        throw const ErreurZeroPerte('Cette vente est annulée.');
      }
      final vente =
          jsonDecode(v.first['donnees'] as String) as Map<String, Object?>;
      final lignesVente = (vente['lignes'] as List).cast<Map>();
      final deja = await _dejaRendus(t, venteOperationId);
      final lignes = <Map<String, Object?>>[];
      var total = 0;
      for (final e in rendus.entries) {
        if (e.value <= 0) continue;
        if (e.key < 0 || e.key >= lignesVente.length) {
          throw const ErreurZeroPerte('Ligne de vente introuvable.');
        }
        final l = lignesVente[e.key];
        final vendu = l['au_montant'] == true ? 1 : (l['nombre'] as int);
        final reste = vendu - (deja[e.key] ?? 0);
        if (e.value > reste) {
          throw ErreurZeroPerte(
            reste <= 0
                ? 'Cet article a déjà été rendu.'
                : 'On ne peut rendre que $reste de cet article.',
          );
        }
        // Part rendue : exacte si tout le reste de la ligne revient.
        int part(int valeur) =>
            e.value == vendu ? valeur : valeur * e.value ~/ vendu;
        final cout = l['cout_total'] as int?;
        final prix = part(l['prix_total'] as int);
        lignes.add({
          'ligne': e.key,
          'produit': l['produit'],
          'nombre': e.value,
          'quantite_milliemes': part(l['quantite_milliemes'] as int),
          'prix_total': prix,
          'cout_total': cout == null ? null : part(cout),
        });
        total += prix;
      }
      if (lignes.isEmpty) {
        throw const ErreurZeroPerte('Choisissez ce que le client rend.');
      }
      final aCredit = vente['mode_paiement'] == ModePaiement.credit.code;
      final modeRetour = aCredit ? ModePaiement.credit : mode;
      if (!aCredit && modeRetour == ModePaiement.credit) {
        throw const ErreurZeroPerte('Choisissez la caisse qui rembourse.');
      }
      return _ajouter(
        t,
        type: TypeOperation.venteRetour,
        auteurId: auteurId,
        donnees: {
          'vente': venteOperationId,
          'recu': vente['recu'],
          'motif': motif.trim(),
          'lignes': lignes,
          'total': total,
          'mode_paiement': modeRetour.code,
          if (vente['client'] != null) 'client': vente['client'],
          'accord': ?accordPatronId,
        },
      );
    });
  }

  /// Retours (les plus récents d'abord).
  Future<List<OperationLue>> retours({int depuis = 0, int limite = 200}) =>
      _operationsDuType(TypeOperation.venteRetour, depuis, limite);

  Future<List<OperationLue>> _operationsDuType(
    String type,
    int depuis,
    int limite,
  ) async {
    final r = await _db.query(
      'operations',
      columns: ['id', 'heure_telephone', 'auteur_id', 'donnees'],
      where: 'type = ? AND heure_telephone >= ?',
      whereArgs: [type, depuis],
      orderBy: 'heure_telephone DESC, numero DESC',
      limit: limite,
    );
    return [
      for (final l in r)
        OperationLue(
          id: l['id'] as String,
          heure: l['heure_telephone'] as int,
          auteurId: l['auteur_id'] as String,
          donnees: (jsonDecode(l['donnees'] as String) as Map)
              .cast<String, Object?>(),
        ),
    ];
  }

  /// Nouveau devis (facture proforma). Ne touche ni le stock ni la caisse.
  /// [lignes] : produit, conditionnement, nombre ou montant, libellé, prix.
  Future<Operation> enregistrerDevis({
    required List<Map<String, Object?>> lignes,
    String? clientId,
    int validiteJours = 7,
    required String auteurId,
  }) {
    if (lignes.isEmpty) throw const ErreurZeroPerte('Le devis est vide.');
    return _db.transaction((t) async {
      final n = await t.rawQuery(
        'SELECT COUNT(*) AS n FROM operations WHERE type = ? AND telephone_id = ?',
        [TypeOperation.devisCree, telephoneId],
      );
      final numero = (n.first['n'] as int) + 1;
      return _ajouter(
        t,
        type: TypeOperation.devisCree,
        auteurId: auteurId,
        donnees: {
          'numero': numero,
          'recu': 'DV-$prefixeRecu-${numero.toString().padLeft(4, '0')}',
          'lignes': lignes,
          'total': lignes.fold<int>(0, (s, l) => s + (l['prix'] as int)),
          'validite_jours': validiteJours,
          'client': ?clientId,
        },
      );
    });
  }

  /// Devis (les plus récents d'abord), avec la vente qui l'a transformé.
  Future<List<(OperationLue, String?)>> devis({int limite = 200}) async {
    final liste = await _operationsDuType(TypeOperation.devisCree, 0, limite);
    final vendus = await _operationsDuType(TypeOperation.devisVendu, 0, 100000);
    final venteDe = {
      for (final v in vendus)
        v.donnees['devis'] as String: v.donnees['recu'] as String?,
    };
    return [
      for (final d in liste)
        (d, venteDe.containsKey(d.id) ? (venteDe[d.id] ?? '') : null),
    ];
  }

  /// Le devis est devenu la vente [venteOperationId] (reçu [recu]).
  Future<Operation> marquerDevisVendu({
    required String devisId,
    required String venteOperationId,
    required String recu,
    required String auteurId,
  }) => _db.transaction(
    (t) => _ajouter(
      t,
      type: TypeOperation.devisVendu,
      auteurId: auteurId,
      donnees: {'devis': devisId, 'vente': venteOperationId, 'recu': recu},
    ),
  );

  /// Ventes depuis une heure donnée (millisecondes), les plus récentes d'abord,
  /// avec leur état (annulée ou non).
  Future<List<VenteResume>> ventesDepuis(int depuis) async {
    final r = await _db.rawQuery(
      'SELECT o.id, o.heure_telephone AS h, o.auteur_id AS a, o.donnees AS d, '
      'an.motif AS motif FROM operations o '
      'LEFT JOIN ventes_annulees an ON an.vente_operation_id = o.id '
      'WHERE o.type = ? AND o.heure_telephone >= ? ORDER BY o.heure_telephone DESC, o.numero DESC',
      [TypeOperation.vente, depuis],
    );
    return [
      for (final l in r)
        VenteResume(
          operationId: l['id'] as String,
          heure: l['h'] as int,
          auteurId: l['a'] as String,
          donnees: (jsonDecode(l['d'] as String) as Map)
              .cast<String, Object?>(),
          motifAnnulation: l['motif'] as String?,
        ),
    ];
  }

  /// Quantités vendues par produit depuis [depuis] (millièmes, annulations
  /// déduites), et chiffre d'affaires par produit.
  Future<Map<String, ({int milliemes, int montant})>> ventesParProduit({
    required int depuis,
    int? jusqua,
  }) async {
    final r = await _db.rawQuery(
      'SELECT m.produit_id AS p, -SUM(m.quantite_milliemes) AS q, SUM(m.prix_total) AS t '
      'FROM mouvements_stock m JOIN operations o ON o.id = m.operation_id '
      "WHERE m.nature IN ('vente', 'annulation', 'retour') "
      'AND o.heure_telephone >= ? AND o.heure_telephone < ? '
      'GROUP BY m.produit_id',
      [depuis, jusqua ?? 9007199254740991],
    );
    return {
      for (final l in r)
        l['p'] as String: (
          milliemes: (l['q'] as int?) ?? 0,
          montant: (l['t'] as int?) ?? 0,
        ),
    };
  }

  /// Produits ayant déjà reçu au moins un arrivage.
  Future<Set<String>> produitsDejaRecus() async {
    final r = await _db.rawQuery(
      "SELECT DISTINCT produit_id AS p FROM mouvements_stock WHERE nature = 'arrivage'",
    );
    return {for (final l in r) l['p'] as String};
  }

  /// Chiffres des ventes depuis [depuis] : total encaissé (annulations
  /// déduites) et nombre de ventes non annulées.
  Future<({int total, int nombre})> resumeVentes({
    required int depuis,
    int? jusqua,
  }) async {
    final fin = jusqua ?? 9007199254740991;
    final r = await _db.rawQuery(
      'SELECT COALESCE(SUM(v.total), 0) AS t, COUNT(*) AS n FROM ventes v '
      'JOIN operations o ON o.id = v.operation_id '
      'LEFT JOIN ventes_annulees an ON an.vente_operation_id = v.operation_id '
      'WHERE o.heure_telephone >= ? AND o.heure_telephone < ? '
      'AND an.operation_id IS NULL',
      [depuis, fin],
    );
    // Les retours partiels sont déduits du jour où ils sont faits.
    final rendus = await totalRetours(depuis: depuis, jusqua: fin);
    return (total: (r.first['t'] as int) - rendus, nombre: r.first['n'] as int);
  }

  /// Argent rendu aux clients (retours partiels) entre deux heures.
  Future<int> totalRetours({required int depuis, int? jusqua}) async {
    final r = await _db.rawQuery(
      'SELECT COALESCE(-SUM(m.prix_total), 0) AS s FROM mouvements_stock m '
      'JOIN operations o ON o.id = m.operation_id '
      "WHERE m.nature = 'retour' AND o.heure_telephone >= ? AND o.heure_telephone < ?",
      [depuis, jusqua ?? 9007199254740991],
    );
    return r.first['s'] as int;
  }

  /// Crédit accordé (ventes à crédit non annulées) et remboursements reçus
  /// entre deux heures.
  Future<({int accorde, int rembourse})> mouvementsCredit({
    required int depuis,
    int? jusqua,
  }) async {
    final r = await _db.rawQuery(
      'SELECT '
      "COALESCE(SUM(CASE WHEN c.nature IN ('vente', 'annulation', 'retour') THEN c.montant ELSE 0 END), 0) AS a, "
      "COALESCE(-SUM(CASE WHEN c.nature = 'remboursement' THEN c.montant ELSE 0 END), 0) AS r "
      'FROM mouvements_credit c JOIN operations o ON o.id = c.operation_id '
      'WHERE o.heure_telephone >= ? AND o.heure_telephone < ?',
      [depuis, jusqua ?? 9007199254740991],
    );
    return (accorde: r.first['a'] as int, rembourse: r.first['r'] as int);
  }

  /// Ventes non annulées depuis [depuis] : (heure, total), pour les graphiques.
  Future<List<(int, int)>> ventesDetaillees({required int depuis}) async {
    final r = await _db.rawQuery(
      'SELECT o.heure_telephone AS h, v.total AS t FROM ventes v '
      'JOIN operations o ON o.id = v.operation_id '
      'LEFT JOIN ventes_annulees an ON an.vente_operation_id = v.operation_id '
      'WHERE o.heure_telephone >= ? AND an.operation_id IS NULL',
      [depuis],
    );
    final rendus = await _db.rawQuery(
      'SELECT o.heure_telephone AS h, SUM(m.prix_total) AS t FROM mouvements_stock m '
      'JOIN operations o ON o.id = m.operation_id '
      "WHERE m.nature = 'retour' AND o.heure_telephone >= ? GROUP BY o.id",
      [depuis],
    );
    return [
      for (final l in r) (l['h'] as int, l['t'] as int),
      for (final l in rendus) (l['h'] as int, l['t'] as int),
    ];
  }

  /// Total des dépenses (tous moyens de paiement) depuis [depuis].
  Future<int> totalDepenses({required int depuis, int? jusqua}) async {
    final r = await _db.rawQuery(
      'SELECT COALESCE(SUM(c.montant), 0) AS s FROM mouvements_caisse c '
      'JOIN operations o ON o.id = c.operation_id '
      'WHERE c.nature = ? AND o.heure_telephone >= ? AND o.heure_telephone < ?',
      [TypeOperation.depense, depuis, jusqua ?? 9007199254740991],
    );
    return r.first['s'] as int;
  }

  /// Bénéfice estimé entre deux heures (millisecondes), bornes comprises.
  Future<ResumeBenefice> beneficeEstime({int? depuis, int? jusqua}) async {
    final r = await _db.rawQuery(
      'SELECT COALESCE(SUM(m.prix_total), 0) AS ventes, '
      'COALESCE(SUM(CASE WHEN m.cout_total IS NULL THEN 0 ELSE m.prix_total END), 0) AS ventes_avec_cout, '
      'COALESCE(SUM(m.cout_total), 0) AS couts, '
      'SUM(CASE WHEN m.cout_total IS NULL THEN 1 ELSE 0 END) AS sans_cout '
      'FROM mouvements_stock m JOIN operations o ON o.id = m.operation_id '
      "WHERE m.nature IN ('vente', 'annulation', 'retour') AND o.heure_telephone >= ? AND o.heure_telephone <= ?",
      [depuis ?? 0, jusqua ?? 9007199254740991],
    );
    final l = r.first;
    return ResumeBenefice(
      ventes: l['ventes_avec_cout'] as int,
      couts: l['couts'] as int,
      lignesSansCout: (l['sans_cout'] as int?) ?? 0,
    );
  }

  // ---------------------------------------------------------------------------
  // Caisse
  // ---------------------------------------------------------------------------

  Future<Operation> _mouvementCaisse(
    String type,
    ModePaiement mode,
    int montant,
    String? motif,
    String auteurId, {
    bool zeroPermis = false,
  }) {
    if (montant < 0 || (montant == 0 && !zeroPermis)) {
      throw const ErreurZeroPerte('Le montant doit être positif.');
    }
    return _db.transaction(
      (t) => _ajouter(
        t,
        type: type,
        auteurId: auteurId,
        donnees: {
          'mode_paiement': mode.code,
          'montant': montant,
          'motif': motif?.trim(),
        },
      ),
    );
  }

  /// Fonds de caisse du matin (argent laissé pour rendre la monnaie).
  Future<Operation> enregistrerFondsDeCaisse(
    int montant, {
    required String auteurId,
  }) => _mouvementCaisse(
    TypeOperation.fondsDeCaisse,
    ModePaiement.especes,
    montant,
    null,
    auteurId,
    zeroPermis: true,
  );

  /// Type du dernier événement de caisse (ouverture = fonds de caisse, ou fermeture),
  /// ou nul s'il n'y en a jamais eu.
  Future<String?> dernierEvenementCaisse() async {
    final r = await _db.query(
      'operations',
      columns: ['type'],
      where: 'type IN (?, ?)',
      whereArgs: [TypeOperation.fondsDeCaisse, TypeOperation.fermetureCaisse],
      orderBy: 'heure_telephone DESC, numero DESC',
      limit: 1,
    );
    return r.isEmpty ? null : r.first['type'] as String;
  }

  /// Dernière ouverture de caisse (fonds de caisse) : heure et auteur.
  Future<({int heure, String auteurId})?> derniereOuverture() async {
    final r = await _db.query(
      'operations',
      columns: ['heure_telephone', 'auteur_id'],
      where: 'type = ?',
      whereArgs: [TypeOperation.fondsDeCaisse],
      orderBy: 'heure_telephone DESC, numero DESC',
      limit: 1,
    );
    if (r.isEmpty) return null;
    return (
      heure: r.first['heure_telephone'] as int,
      auteurId: r.first['auteur_id'] as String,
    );
  }

  /// Heure de la dernière fermeture de caisse (0 s'il n'y en a jamais eu).
  Future<int> derniereFermeture() async {
    final r = await _db.rawQuery(
      'SELECT MAX(heure_telephone) AS h FROM operations WHERE type = ?',
      [TypeOperation.fermetureCaisse],
    );
    return (r.first['h'] as int?) ?? 0;
  }

  /// Repère (heure, numéro) de la dernière fermeture, ou nul.
  Future<RepereOperation?> _repereDerniereFermeture() async {
    final r = await _db.query(
      'operations',
      columns: ['heure_telephone', 'numero'],
      where: 'type = ?',
      whereArgs: [TypeOperation.fermetureCaisse],
      orderBy: 'heure_telephone DESC, numero DESC',
      limit: 1,
    );
    if (r.isEmpty) return null;
    return (
      heure: r.first['heure_telephone'] as int,
      numero: r.first['numero'] as int,
    );
  }

  /// Ce qui doit se trouver dans chaque caisse depuis la dernière fermeture.
  Future<Map<ModePaiement, MouvementsCaisse>> caisseEnCours() async {
    final apres = await _repereDerniereFermeture();
    return {
      for (final m in ModePaiement.caisses)
        m: await mouvementsCaisse(m, apres: apres),
    };
  }

  /// Fermeture en comptage aveugle : [comptes] = argent compté par moyen de
  /// paiement. L'attendu est calculé ici et enregistré avec la fermeture, pour
  /// que le patron voie l'écart plus tard ; le vendeur ne le voit jamais.
  Future<FermetureCaisse> enregistrerFermeture(
    Map<ModePaiement, int> comptes, {
    required String auteurId,
  }) async {
    if (comptes.values.any((v) => v < 0)) {
      throw const ErreurZeroPerte(
        'Un montant compté ne peut pas être négatif.',
      );
    }
    final enCours = await caisseEnCours();
    final attendus = {
      for (final e in enCours.entries) e.key: attenduAFermeture(e.key, e.value),
    };
    final op = await _db.transaction(
      (t) => _ajouter(
        t,
        type: TypeOperation.fermetureCaisse,
        auteurId: auteurId,
        donnees: {
          'comptes': {
            for (final m in ModePaiement.caisses) m.code: comptes[m] ?? 0,
          },
          'attendus': {
            for (final m in ModePaiement.caisses) m.code: attendus[m],
          },
        },
      ),
    );
    return FermetureCaisse._depuis(
      op.id,
      op.heureTelephone,
      auteurId,
      op.donnees,
    );
  }

  /// Fermetures de caisse, la plus récente d'abord.
  Future<List<FermetureCaisse>> fermetures({int limite = 60}) async {
    final r = await _db.query(
      'operations',
      columns: ['id', 'heure_telephone', 'auteur_id', 'donnees'],
      where: 'type = ?',
      whereArgs: [TypeOperation.fermetureCaisse],
      orderBy: 'heure_telephone DESC, numero DESC',
      limit: limite,
    );
    return [
      for (final l in r)
        FermetureCaisse._depuis(
          l['id'] as String,
          l['heure_telephone'] as int,
          l['auteur_id'] as String,
          json.decode(l['donnees'] as String) as Map<String, dynamic>,
        ),
    ];
  }

  /// Dépense payée avec la caisse, motif obligatoire.
  Future<Operation> enregistrerDepense(
    int montant, {
    required String motif,
    ModePaiement mode = ModePaiement.especes,
    required String auteurId,
  }) {
    if (motif.trim().isEmpty) {
      throw const ErreurZeroPerte('Le motif est obligatoire.');
    }
    return _mouvementCaisse(
      TypeOperation.depense,
      mode,
      montant,
      motif,
      auteurId,
    );
  }

  /// Argent pris par le patron.
  Future<Operation> enregistrerRetraitPatron(
    int montant, {
    ModePaiement mode = ModePaiement.especes,
    required String auteurId,
  }) => _mouvementCaisse(
    TypeOperation.retraitPatron,
    mode,
    montant,
    null,
    auteurId,
  );

  /// Ce qui doit se trouver dans la caisse d'un moyen de paiement sur une période.
  Future<MouvementsCaisse> mouvementsCaisse(
    ModePaiement mode, {
    int? depuis,
    int? jusqua,
    RepereOperation? apres,
  }) async {
    final bornes = <Object?>[
      depuis ?? 0,
      jusqua ?? 9007199254740991,
      if (apres != null) ...[apres.heure, apres.heure, apres.numero],
    ];
    Future<int> somme(String sql, List<Object?> args) async =>
        ((await _db.rawQuery(sql, args)).first['s'] as int?) ?? 0;
    final filtre =
        'o.heure_telephone >= ? AND o.heure_telephone <= ?'
        '${apres == null ? '' : ' AND (o.heure_telephone > ? OR (o.heure_telephone = ? AND o.numero > ?))'}';
    final ventes = await somme(
      'SELECT SUM(v.total) AS s FROM ventes v JOIN operations o ON o.id = v.operation_id '
      'WHERE v.mode_paiement = ? AND $filtre',
      [mode.code, ...bornes],
    );
    final annulations = await somme(
      'SELECT SUM(a.total) AS s FROM ventes_annulees a JOIN operations o ON o.id = a.operation_id '
      'WHERE a.mode_paiement = ? AND $filtre',
      [mode.code, ...bornes],
    );
    Future<int> caisse(String nature) => somme(
      'SELECT SUM(c.montant) AS s FROM mouvements_caisse c JOIN operations o ON o.id = c.operation_id '
      'WHERE c.nature = ? AND c.mode_paiement = ? AND $filtre',
      [nature, mode.code, ...bornes],
    );
    // Consignes : comptées en espèces.
    var consignesEncaissees = 0;
    var consignesRendues = 0;
    if (mode == ModePaiement.especes) {
      consignesEncaissees = await somme(
        'SELECT SUM(e.consigne) AS s FROM mouvements_emballages e JOIN operations o ON o.id = e.operation_id '
        'WHERE e.consigne > 0 AND $filtre',
        bornes,
      );
      consignesRendues = -await somme(
        'SELECT SUM(e.consigne) AS s FROM mouvements_emballages e JOIN operations o ON o.id = e.operation_id '
        'WHERE e.consigne < 0 AND $filtre',
        bornes,
      );
    }
    return MouvementsCaisse(
      fondsDeCaisse: await caisse(TypeOperation.fondsDeCaisse),
      ventes: ventes - annulations - await caisse(TypeOperation.venteRetour),
      remboursementsCredits: await caisse(TypeOperation.remboursementCredit),
      depenses:
          await caisse(TypeOperation.depense) +
          await caisse(TypeOperation.paiementFournisseur),
      retraitsPatron: await caisse(TypeOperation.retraitPatron),
      consignesEncaissees: consignesEncaissees,
      consignesRendues: consignesRendues,
    );
  }

  // ---------------------------------------------------------------------------
  // Emballages consignés
  // ---------------------------------------------------------------------------

  /// Mouvement d'emballages : [quantite] positive = emballages qui entrent
  /// (arrivage plein, client qui ramène), négative = emballages qui partent.
  /// [consigne] : argent encaissé (+) ou rendu (−) au client, en espèces.
  Future<Operation> enregistrerEmballage({
    required String emballage,
    required int quantite,
    int consigne = 0,
    required String auteurId,
  }) {
    if (quantite == 0) {
      throw const ErreurZeroPerte('La quantité ne peut pas être nulle.');
    }
    return _db.transaction(
      (t) => _ajouter(
        t,
        type: TypeOperation.emballage,
        auteurId: auteurId,
        donnees: {
          'emballage': emballage,
          'quantite': quantite,
          'consigne': consigne,
        },
      ),
    );
  }

  /// Nombre d'emballages présents en boutique.
  Future<int> soldeEmballage(String emballage) async {
    final r = await _db.rawQuery(
      'SELECT quantite AS q FROM mouvements_emballages WHERE emballage = ?',
      [emballage],
    );
    return soldeEmballages(r.map((l) => l['q'] as int));
  }

  // ---------------------------------------------------------------------------
  // Boutique et utilisateurs (patron, vendeurs)
  // ---------------------------------------------------------------------------

  /// Enregistre la configuration de la boutique (nouvelle version).
  Future<Operation> configurerBoutique(
    ConfigBoutique config, {
    required String auteurId,
  }) => _db.transaction(
    (t) => _ajouter(
      t,
      type: TypeOperation.boutiqueConfiguree,
      auteurId: auteurId,
      donnees: config.versDonnees(),
    ),
  );

  /// Configuration actuelle de la boutique (la plus récente), ou nulle.
  Future<ConfigBoutique?> configuration() async {
    final r = await _db.query(
      'operations',
      columns: ['donnees'],
      where: 'type = ?',
      whereArgs: [TypeOperation.boutiqueConfiguree],
      orderBy: 'heure_telephone DESC, numero DESC',
      limit: 1,
    );
    if (r.isEmpty) return null;
    return ConfigBoutique.depuisDonnees(
      (jsonDecode(r.first['donnees'] as String) as Map).cast<String, Object?>(),
    );
  }

  /// Crée ou modifie un utilisateur (nouvelle version ; l'ancienne reste dans l'historique).
  Future<Operation> definirUtilisateur(
    Utilisateur u, {
    required String auteurId,
  }) => _db.transaction(
    (t) => _ajouter(
      t,
      type: TypeOperation.utilisateurDefini,
      auteurId: auteurId,
      donnees: u.versDonnees(),
    ),
  );

  /// Utilisateurs (version actuelle de chacun), patron d'abord.
  Future<List<Utilisateur>> utilisateurs() async {
    final r = await _db.query(
      'operations',
      columns: ['donnees'],
      where: 'type = ?',
      whereArgs: [TypeOperation.utilisateurDefini],
      orderBy: 'heure_telephone, numero',
    );
    final parId = <String, Utilisateur>{};
    for (final l in r) {
      final u = Utilisateur.depuisDonnees(
        (jsonDecode(l['donnees'] as String) as Map).cast<String, Object?>(),
      );
      parId[u.id] = u;
    }
    return parId.values.toList()
      ..sort((a, b) => a.role.index.compareTo(b.role.index));
  }

  // ---------------------------------------------------------------------------
  // Licence
  // ---------------------------------------------------------------------------

  /// Enregistre un code d'activation DÉJÀ VÉRIFIÉ (signature contrôlée avant).
  Future<Operation> enregistrerActivation(
    CodeActivation code, {
    required String auteurId,
  }) => _db.transaction(
    (t) => _ajouter(
      t,
      type: TypeOperation.licenceActivee,
      auteurId: auteurId,
      donnees: {
        'code': code.texte,
        'code_id': code.codeId,
        'boutique': code.boutiqueId,
        'type': code.type.name,
        'telephones': code.telephones,
      },
    ),
  );

  /// Codes activés (tous téléphones), dans l'ordre d'activation.
  Future<List<CodeActivation>> codesActives() async {
    final r = await _db.query(
      'operations',
      columns: ['donnees'],
      where: 'type = ?',
      whereArgs: [TypeOperation.licenceActivee],
      orderBy: 'heure_telephone, numero',
    );
    final codes = <CodeActivation>[];
    for (final l in r) {
      final d = jsonDecode(l['donnees'] as String) as Map<String, Object?>;
      try {
        codes.add(lireCode(d['code'] as String));
      } on ErreurCode {
        // Code illisible : ignoré (il reste dans le journal).
      }
    }
    return codes;
  }

  /// Accès brut à la base, réservé aux tests.
  Database get baseBrutePourTests => _db;
}

/// Ce qu'on compare au comptage : toute la caisse pour les espèces ; pour
/// Flooz et Mixx, seulement l'argent reçu (le vendeur additionne les messages
/// de paiement reçus ; les dépenses payées par Mobile Money restent notées à part).
int attenduAFermeture(ModePaiement mode, MouvementsCaisse m) =>
    mode == ModePaiement.especes
    ? m.attendu
    : m.ventes + m.remboursementsCredits;

/// Repère d'une opération dans le journal (pour « tout ce qui suit »).
typedef RepereOperation = ({int heure, int numero});

/// Une fermeture de caisse enregistrée : compté et attendu par moyen de paiement.
class FermetureCaisse {
  const FermetureCaisse({
    required this.id,
    required this.heure,
    required this.auteurId,
    required this.comptes,
    required this.attendus,
  });

  factory FermetureCaisse._depuis(
    String id,
    int heure,
    String auteurId,
    Map<String, dynamic> d,
  ) {
    Map<ModePaiement, int> lire(Object? m) => {
      for (final e in ((m as Map?) ?? const {}).entries)
        ModePaiement.depuisCode(e.key as String): (e.value as num).toInt(),
    };
    return FermetureCaisse(
      id: id,
      heure: heure,
      auteurId: auteurId,
      comptes: lire(d['comptes']),
      attendus: lire(d['attendus']),
    );
  }

  final String id;
  final int heure;
  final String auteurId;
  final Map<ModePaiement, int> comptes;
  final Map<ModePaiement, int> attendus;

  ResultatCaisse resultat(ModePaiement m) =>
      ResultatCaisse(attendu: attendus[m] ?? 0, compte: comptes[m] ?? 0);

  /// Somme des écarts de tous les moyens de paiement.
  int get ecartTotal =>
      ModePaiement.caisses.fold(0, (s, m) => s + resultat(m).ecart);
}

/// Fiche d'un client qui peut acheter à crédit.
class Client {
  const Client({
    required this.id,
    required this.nom,
    required this.telephone,
    required this.photo,
    required this.plafond,
    required this.actif,
    required this.solde,
    this.quartier = '',
    this.email = '',
  });

  final String id;
  final String nom;
  final String telephone;
  final String quartier;
  final String email;

  /// Photo JPEG en base64, ou nulle.
  final String? photo;

  /// Dette maximale autorisée (F).
  final int plafond;
  final bool actif;

  /// Ce que le client doit encore (F).
  final int solde;

  /// Ce qu'il peut encore prendre à crédit.
  int get disponible => plafond - solde < 0 ? 0 : plafond - solde;

  /// Le crédit demande un numéro (pour le rappel WhatsApp).
  bool get peutPrendreCredit => actif && telephone.trim().isNotEmpty;
}

/// Une ligne de l'historique du crédit d'un client.
class MouvementCredit {
  const MouvementCredit({
    required this.operationId,
    required this.heure,
    required this.montant,
    required this.nature,
    this.recu,
    this.mode,
  });

  final String operationId;
  final int heure;

  /// > 0 : le client doit plus ; < 0 : il doit moins.
  final int montant;

  /// « vente », « annulation » ou « remboursement ».
  final String nature;
  final String? recu;
  final ModePaiement? mode;
}

/// Une ligne d'inventaire : attendu et compté (millièmes de l'unité de base).
class LigneInventaire {
  const LigneInventaire({
    required this.produitId,
    required this.attendu,
    required this.compte,
    required this.prixUnitaire,
  });

  final String produitId;
  final int attendu;
  final int compte;
  final int prixUnitaire;

  /// > 0 : en trop ; < 0 : il manque.
  int get ecart => compte - attendu;

  /// Écart en francs (au prix de vente de l'unité de base).
  int get ecartFrancs =>
      diviserArrondi(ecart * prixUnitaire, milliemesParUnite);
}

/// Un inventaire complet enregistré.
class Inventaire {
  const Inventaire({
    required this.id,
    required this.heure,
    required this.auteurId,
    required this.lignes,
  });

  factory Inventaire.depuisOperation(
    String id,
    int heure,
    String auteurId,
    Map<String, Object?> d,
  ) => Inventaire(
    id: id,
    heure: heure,
    auteurId: auteurId,
    lignes: [
      for (final l in (d['lignes'] as List).cast<Map>())
        LigneInventaire(
          produitId: l['produit'] as String,
          attendu: l['attendu'] as int,
          compte: l['compte'] as int,
          prixUnitaire: (l['prix_unitaire'] as int?) ?? 0,
        ),
    ],
  );

  final String id;
  final int heure;
  final String auteurId;
  final List<LigneInventaire> lignes;

  int get ecartFrancs => lignes.fold(0, (s, l) => s + l.ecartFrancs);
}

/// Un fournisseur et ce que la boutique lui doit.
class Fournisseur {
  const Fournisseur({
    required this.id,
    required this.nom,
    required this.telephone,
    required this.doit,
  });

  final String id;
  final String nom;
  final String telephone;

  /// Ce que la boutique doit encore à ce fournisseur (F).
  final int doit;
}

/// Une opération relue du journal (devis, retour…).
class OperationLue {
  const OperationLue({
    required this.id,
    required this.heure,
    required this.auteurId,
    required this.donnees,
  });

  final String id;
  final int heure;
  final String auteurId;
  final Map<String, Object?> donnees;

  String get recu => donnees['recu'] as String? ?? '';
  int get total => donnees['total'] as int? ?? 0;
  List<Map<String, Object?>> get lignes => [
    for (final l in (donnees['lignes'] as List? ?? const []))
      (l as Map).cast<String, Object?>(),
  ];
}
