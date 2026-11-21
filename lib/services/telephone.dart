import 'package:flutter/services.dart';

/// Informations sur le téléphone, lues par le canal natif (MainActivity.kt).
class InfosTelephone {
  const InfosTelephone({
    required this.androidSdk,
    required this.androidVersion,
    required this.fabricant,
    required this.modele,
    required this.servicesGoogle,
    required this.espaceLibreMo,
  });

  final int androidSdk;
  final String androidVersion;
  final String fabricant;
  final String modele;

  /// Services Google présents (nécessaires pour la synchronisation Drive).
  final bool servicesGoogle;
  final int espaceLibreMo;

  factory InfosTelephone.depuisCarte(Map<Object?, Object?> c) => InfosTelephone(
    androidSdk: (c['androidSdk'] as num?)?.toInt() ?? 0,
    androidVersion: (c['androidVersion'] as String?) ?? '',
    fabricant: (c['fabricant'] as String?) ?? '',
    modele: (c['modele'] as String?) ?? '',
    servicesGoogle: (c['servicesGoogle'] as bool?) ?? false,
    espaceLibreMo: (c['espaceLibreMo'] as num?)?.toInt() ?? 0,
  );

  /// Texte court pour le diagnostic envoyé à l'assistance (aucune donnée de la boutique).
  String get diagnostic =>
      '$fabricant $modele, Android $androidVersion (API $androidSdk), '
      'Google ${servicesGoogle ? 'oui' : 'non'}, $espaceLibreMo Mo libres';
}

/// Accès aux informations du téléphone (remplaçable dans les tests).
abstract class ServiceTelephone {
  Future<InfosTelephone> infos();
}

class ServiceTelephoneAndroid implements ServiceTelephone {
  static const _canal = MethodChannel('tg.zeroperte/telephone');

  @override
  Future<InfosTelephone> infos() async {
    final r = await _canal.invokeMapMethod<Object?, Object?>('infos');
    return InfosTelephone.depuisCarte(r ?? const {});
  }
}
