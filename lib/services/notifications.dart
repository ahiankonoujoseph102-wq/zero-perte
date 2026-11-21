/// Notifications des alertes graves sur le téléphone du patron, même
/// application fermée (Firebase Cloud Messaging, gratuit).
///
/// Les identifiants Firebase (publics) sont donnés à la fabrication :
/// `--dart-define=ZP_FIREBASE_CLE=… ZP_FIREBASE_APPLI=… ZP_FIREBASE_PROJET=…
/// ZP_FIREBASE_EXPEDITEUR=…` (variables GitHub, voir docs/etapes-proprietaire.md).
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

const String _cle = String.fromEnvironment('ZP_FIREBASE_CLE');
const String _appli = String.fromEnvironment('ZP_FIREBASE_APPLI');
const String _projet = String.fromEnvironment('ZP_FIREBASE_PROJET');
const String _expediteur = String.fromEnvironment('ZP_FIREBASE_EXPEDITEUR');

bool get firebaseConfigure =>
    _cle.isNotEmpty &&
    _appli.isNotEmpty &&
    _projet.isNotEmpty &&
    _expediteur.isNotEmpty;

/// Canal (« sujet ») des alertes d'une boutique : calculé à partir de son jeton
/// secret, exactement comme le relais (relais/worker.js) — le jeton lui-même
/// n'est jamais envoyé à Firebase.
String sujetAlertes(String jetonRelais) =>
    'zp-${sha256.convert(utf8.encode(jetonRelais)).toString().substring(0, 32)}';

/// Abonne ce téléphone aux alertes de la boutique. Faux si impossible ici.
Future<bool> activerNotificationsAndroid(String sujet) async {
  if (!Platform.isAndroid || !firebaseConfigure) return false;
  try {
    return await const MethodChannel('tg.zeroperte/telephone')
            .invokeMethod<bool>('notifications', {
              'cle': _cle,
              'appli': _appli,
              'projet': _projet,
              'expediteur': _expediteur,
              'sujet': sujet,
            }) ??
        false;
  } catch (_) {
    return false;
  }
}
