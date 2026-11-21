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

/// Un produit est en stock bas :
/// - épuisé (stock nul ou négatif) alors qu'il se vend ou a déjà été reçu ;
/// - sous le seuil d'alerte fixé par le patron (s'il y en a un) ;
/// - sinon, s'il reste moins que ce qui a été vendu ces 7 derniers jours.
/// Toutes les quantités sont en millièmes de l'unité de base.
RaisonStockBas? stockBas({
  required int stock,
  required int seuil,
  required int venduSur7Jours,
  required bool dejaRecu,
}) {
  if (stock <= 0) {
    return (venduSur7Jours > 0 || dejaRecu) ? RaisonStockBas.epuise : null;
  }
  if (seuil > 0) return stock <= seuil ? RaisonStockBas.sousLeSeuil : null;
  if (venduSur7Jours > 0 && stock < venduSur7Jours) {
    return RaisonStockBas.moinsDUneSemaine;
  }
  return null;
}
