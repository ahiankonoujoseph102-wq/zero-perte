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

/// Moyens de paiement. Chacun a sa propre caisse (espèces et Mobile Money séparés).
/// Le crédit client arrive à l'étape C1.
enum ModePaiement {
  especes('especes'),
  flooz('flooz'),
  mixx('mixx');

  const ModePaiement(this.code);
  final String code;

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
  JournalLocal._(this._db, this.telephoneId, this.prefixeRecu, this._horloge);

  final Database _db;

  /// Identifiant unique de CE téléphone.
  final String telephoneId;

  /// Préfixe des reçus de ce téléphone (A, B, P…).
  final String prefixeRecu;

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

  /// Stock actuel d'un produit, en millièmes d'unité de base.
  Future<int> stockMilliemes(String produitId) async {
    final r = await _db.rawQuery(
      'SELECT quantite_milliemes AS q FROM mouvements_stock WHERE produit_id = ?',
      [produitId],
    );
    return stockDepuisMouvements(r.map((l) => l['q'] as int));
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
    required String auteurId,
  }) {
    if (lignes.isEmpty) throw const ErreurZeroPerte('La vente est vide.');
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
        },
      );
    });
  }

  /// Bénéfice estimé entre deux heures (millisecondes), bornes comprises.
  Future<ResumeBenefice> beneficeEstime({int? depuis, int? jusqua}) async {
    final r = await _db.rawQuery(
      'SELECT COALESCE(SUM(m.prix_total), 0) AS ventes, '
      'COALESCE(SUM(CASE WHEN m.cout_total IS NULL THEN 0 ELSE m.prix_total END), 0) AS ventes_avec_cout, '
      'COALESCE(SUM(m.cout_total), 0) AS couts, '
      'SUM(CASE WHEN m.cout_total IS NULL THEN 1 ELSE 0 END) AS sans_cout '
      'FROM mouvements_stock m JOIN operations o ON o.id = m.operation_id '
      "WHERE m.nature IN ('vente', 'annulation') AND o.heure_telephone >= ? AND o.heure_telephone <= ?",
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
    String auteurId,
  ) {
    if (montant <= 0) {
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
  );

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
  }) async {
    final bornes = [depuis ?? 0, jusqua ?? 9007199254740991];
    Future<int> somme(String sql, List<Object?> args) async =>
        ((await _db.rawQuery(sql, args)).first['s'] as int?) ?? 0;
    const filtre = 'o.heure_telephone >= ? AND o.heure_telephone <= ?';
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
      ventes: ventes - annulations,
      depenses: await caisse(TypeOperation.depense),
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
