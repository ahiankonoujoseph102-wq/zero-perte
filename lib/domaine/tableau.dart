/// Tableau du patron : périodes et règle du « stock bas ».
library;

/// Période affichée dans le tableau du patron.
enum Periode {
  jour('Aujourd\'hui'),
  semaine('Cette semaine'),
  mois('Ce mois');

  const Periode(this.libelle);
  final String libelle;

  /// Début de la période (minuit), la semaine commençant le lundi.
  DateTime debut(DateTime maintenant) {
    final jour = DateTime(maintenant.year, maintenant.month, maintenant.day);
    return switch (this) {
      Periode.jour => jour,
      Periode.semaine => jour.subtract(Duration(days: jour.weekday - 1)),
      Periode.mois => DateTime(maintenant.year, maintenant.month),
    };
  }
}

/// Raison pour laquelle un produit apparaît dans « Stock bas ».
enum RaisonStockBas { epuise, sousLeSeuil, moinsDUneSemaine }

/// Un produit est en stock bas (seulement s'il a déjà été reçu ou compté :
/// un produit « pas encore compté » ne donne jamais d'alerte, 0.36) :
/// - épuisé (stock nul ou négatif) ;
/// - sous le seuil d'alerte fixé par le patron (s'il y en a un) ;
/// - sinon, s'il reste moins que ce qui a été vendu ces 7 derniers jours.
/// Toutes les quantités sont en millièmes de l'unité de base.
RaisonStockBas? stockBas({
  required int stock,
  required int seuil,
  required int venduSur7Jours,
  required bool dejaRecu,
}) {
  if (!dejaRecu) return null;
  if (stock <= 0) return RaisonStockBas.epuise;
  if (seuil > 0) return stock <= seuil ? RaisonStockBas.sousLeSeuil : null;
  if (venduSur7Jours > 0 && stock < venduSur7Jours) {
    return RaisonStockBas.moinsDUneSemaine;
  }
  return null;
}
