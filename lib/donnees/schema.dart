/// Schéma de la base locale (SQLite) de Zéro Perte, version 1.
///
/// - `operations` est le JOURNAL : la seule source de vérité, synchronisée plus
///   tard avec le Drive de la boutique (étape D2).
/// - Les autres tables (`produits_versions`, `mouvements_stock`, `ventes`…) sont
///   remplies à partir du journal, dans la même transaction, pour faciliter les
///   calculs. Elles sont elles aussi en « ajout seulement ».
/// - Des déclencheurs (triggers) INTERDISENT toute modification et tout effacement :
///   même une erreur de programmation ne peut pas réécrire l'historique.
/// - Seule `parametres` (réglages locaux du téléphone) est modifiable.
///
/// Compatibilité : Android 8 embarque un SQLite ancien (environ 3.18). On
/// n'utilise donc ni UPSERT, ni RETURNING, ni fonctions JSON, ni fonctions de fenêtre.
library;

const int versionSchema = 4;

/// Migrations : pour passer de la version N-1 à la version N.
/// Uniquement des AJOUTS (ALTER TABLE … ADD COLUMN), compatibles SQLite 3.18.
final Map<int, List<String>> migrations = {
  2: [
    'ALTER TABLE produits_versions ADD COLUMN emoji TEXT',
    'ALTER TABLE produits_versions ADD COLUMN catalogue_id TEXT',
    'ALTER TABLE produits_versions ADD COLUMN au_montant INTEGER NOT NULL DEFAULT 0',
    'ALTER TABLE produits_versions ADD COLUMN photo TEXT',
    'ALTER TABLE conditionnements_versions ADD COLUMN a_verifier INTEGER NOT NULL DEFAULT 0',
  ],
  // Crédit client (étape C1).
  3: [
    'ALTER TABLE ventes ADD COLUMN client_id TEXT',
    '''
CREATE TABLE clients_versions (
  operation_id TEXT PRIMARY KEY NOT NULL,
  client_id TEXT NOT NULL,
  nom TEXT NOT NULL,
  telephone TEXT NOT NULL DEFAULT '',
  photo TEXT,
  plafond INTEGER NOT NULL CHECK (plafond >= 0),
  actif INTEGER NOT NULL DEFAULT 1
)''',
    'CREATE INDEX clients_versions_client ON clients_versions (client_id)',
    // montant > 0 : le client doit plus (vente à crédit) ;
    // montant < 0 : il doit moins (remboursement, vente à crédit annulée).
    '''
CREATE TABLE mouvements_credit (
  operation_id TEXT PRIMARY KEY NOT NULL,
  client_id TEXT NOT NULL,
  montant INTEGER NOT NULL,
  nature TEXT NOT NULL,
  mode_paiement TEXT
)''',
    'CREATE INDEX mouvements_credit_client ON mouvements_credit (client_id)',
    ...declencheursPour('clients_versions'),
    ...declencheursPour('mouvements_credit'),
  ],
  // Carnet de clients (quartier, e-mail).
  4: [
    'ALTER TABLE clients_versions ADD COLUMN quartier TEXT',
    'ALTER TABLE clients_versions ADD COLUMN email TEXT',
  ],
};

/// Tables en « ajout seulement » ajoutées par les migrations (déclencheurs
/// créés dans la migration elle-même).
const List<String> tablesAjoutSeulementMigrees = [
  'clients_versions',
  'mouvements_credit',
];

/// Tables en « ajout seulement » (protégées par des déclencheurs).
const List<String> tablesAjoutSeulement = [
  'operations',
  'produits_versions',
  'conditionnements_versions',
  'mouvements_stock',
  'ventes',
  'ventes_annulees',
  'mouvements_emballages',
  'mouvements_caisse',
];

const List<String> creationTables = [
  // Réglages locaux du téléphone (identifiant, préfixe de reçu…). Modifiable.
  '''
CREATE TABLE parametres (
  cle TEXT PRIMARY KEY NOT NULL,
  valeur TEXT NOT NULL
)''',
  // Le journal.
  '''
CREATE TABLE operations (
  id TEXT PRIMARY KEY NOT NULL,
  telephone_id TEXT NOT NULL,
  numero INTEGER NOT NULL,
  type TEXT NOT NULL,
  auteur_id TEXT NOT NULL,
  heure_telephone INTEGER NOT NULL,
  donnees TEXT NOT NULL,
  empreinte_precedente TEXT NOT NULL,
  empreinte TEXT NOT NULL,
  signature TEXT,
  UNIQUE (telephone_id, numero)
)''',
  'CREATE INDEX operations_heure ON operations (heure_telephone)',
  // Chaque définition ou modification d'un produit = une nouvelle version.
  '''
CREATE TABLE produits_versions (
  operation_id TEXT PRIMARY KEY NOT NULL,
  produit_id TEXT NOT NULL,
  nom TEXT NOT NULL,
  unite_base TEXT NOT NULL,
  prix_unitaire INTEGER NOT NULL,
  seuil_alerte_milliemes INTEGER NOT NULL DEFAULT 0,
  emballage TEXT,
  consigne INTEGER NOT NULL DEFAULT 0,
  actif INTEGER NOT NULL DEFAULT 1
)''',
  'CREATE INDEX produits_versions_produit ON produits_versions (produit_id)',
  // Conditionnements (sac = 40 bols, casier = 24 bouteilles…), chacun avec son prix.
  '''
CREATE TABLE conditionnements_versions (
  operation_id TEXT PRIMARY KEY NOT NULL,
  conditionnement_id TEXT NOT NULL,
  produit_id TEXT NOT NULL,
  nom TEXT NOT NULL,
  facteur_milliemes INTEGER NOT NULL CHECK (facteur_milliemes > 0),
  prix_vente INTEGER NOT NULL CHECK (prix_vente >= 0),
  actif INTEGER NOT NULL DEFAULT 1
)''',
  'CREATE INDEX conditionnements_produit ON conditionnements_versions (produit_id)',
  // Mouvements de stock, en millièmes d'unité de base (+ entrée, − sortie).
  // prix_total : argent de la vente (négatif pour une annulation).
  // cout_total : coût d'achat (arrivage) ou coût estimé de la quantité vendue ;
  //              NULL si le coût est inconnu (vente avant tout arrivage).
  '''
CREATE TABLE mouvements_stock (
  operation_id TEXT NOT NULL,
  ligne INTEGER NOT NULL,
  produit_id TEXT NOT NULL,
  quantite_milliemes INTEGER NOT NULL,
  nature TEXT NOT NULL,
  prix_total INTEGER NOT NULL DEFAULT 0,
  cout_total INTEGER,
  PRIMARY KEY (operation_id, ligne)
)''',
  'CREATE INDEX mouvements_produit ON mouvements_stock (produit_id)',
  // Ventes : un reçu numéroté sans trou par téléphone.
  '''
CREATE TABLE ventes (
  operation_id TEXT PRIMARY KEY NOT NULL,
  telephone_id TEXT NOT NULL,
  numero_recu INTEGER NOT NULL,
  recu TEXT NOT NULL,
  total INTEGER NOT NULL,
  mode_paiement TEXT NOT NULL,
  montant_recu INTEGER,
  monnaie_rendue INTEGER,
  reference_paiement TEXT,
  UNIQUE (telephone_id, numero_recu)
)''',
  // Une vente ne peut être annulée qu'une fois, avec un motif.
  '''
CREATE TABLE ventes_annulees (
  operation_id TEXT PRIMARY KEY NOT NULL,
  vente_operation_id TEXT NOT NULL UNIQUE,
  motif TEXT NOT NULL,
  total INTEGER NOT NULL,
  mode_paiement TEXT NOT NULL
)''',
  // Emballages consignés (casiers, bouteilles, bouteilles de gaz).
  '''
CREATE TABLE mouvements_emballages (
  operation_id TEXT NOT NULL,
  ligne INTEGER NOT NULL,
  emballage TEXT NOT NULL,
  quantite INTEGER NOT NULL,
  consigne INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (operation_id, ligne)
)''',
  // Mouvements d'argent hors ventes : fonds de caisse, dépenses, retraits du patron.
  '''
CREATE TABLE mouvements_caisse (
  operation_id TEXT PRIMARY KEY NOT NULL,
  nature TEXT NOT NULL,
  mode_paiement TEXT NOT NULL,
  montant INTEGER NOT NULL CHECK (montant >= 0),
  motif TEXT
)''',
];

/// Déclencheurs qui interdisent modification et effacement.
List<String> get creationDeclencheurs => [
  for (final table in tablesAjoutSeulement) ...declencheursPour(table),
];

/// Les deux déclencheurs qui protègent une table « ajout seulement ».
List<String> declencheursPour(String table) => [
  '''
CREATE TRIGGER ${table}_jamais_modifie BEFORE UPDATE ON $table
BEGIN
  SELECT RAISE(ABORT, 'Zero Perte : on ne modifie jamais l''historique ($table)');
END''',
  '''
CREATE TRIGGER ${table}_jamais_efface BEFORE DELETE ON $table
BEGIN
  SELECT RAISE(ABORT, 'Zero Perte : on n''efface jamais l''historique ($table)');
END''',
];
