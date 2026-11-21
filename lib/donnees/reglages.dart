/// Réglages locaux du téléphone (progression de l'assistant, préférences…).
/// Remplaçable dans les tests par [ReglagesEnMemoire].
abstract class ReglagesLocaux {
  Future<String?> lireParametre(String cle);
  Future<void> ecrireParametre(String cle, String valeur);
}

class ReglagesEnMemoire implements ReglagesLocaux {
  ReglagesEnMemoire([Map<String, String>? depart]) : valeurs = {...?depart};
  final Map<String, String> valeurs;

  @override
  Future<String?> lireParametre(String cle) async => valeurs[cle];

  @override
  Future<void> ecrireParametre(String cle, String valeur) async =>
      valeurs[cle] = valeur;
}
