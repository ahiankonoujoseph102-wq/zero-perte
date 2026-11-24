import 'package:flutter/material.dart';

import '../../domaine/argent.dart';
import '../../domaine/boutique.dart';
import '../../theme/couleurs.dart';
import '../logo_boutique.dart';

/// Une ligne de reçu.
class LigneRecu {
  const LigneRecu(this.libelle, this.montant);
  final String libelle;
  final int montant;
}

/// Reçu d'une vente, aux couleurs de la boutique. Sert d'aperçu pendant
/// l'installation (exemple) et pour les vrais reçus envoyés sur WhatsApp (B11).
class ApercuRecu extends StatelessWidget {
  const ApercuRecu({
    super.key,
    required this.config,
    this.exemple = false,
    this.numero = 'A-000001',
    this.date = '21/11/2026 10:42',
    this.lignes = const [
      LigneRecu('5 bols de riz', 3250),
      LigneRecu('1 huile 1 L', 1200),
    ],
    this.paiement = 'Espèces',
    this.credit,
    this.titre = 'Reçu n°',
    this.libelleTotal = 'TOTAL',
    this.mention,
  });

  /// « Reçu n° », « DEVIS n° », « Retour n° ».
  final String titre;
  final String libelleTotal;

  /// Phrase en gras sous le total (« Devis valable 7 jours… »).
  final String? mention;

  final ConfigBoutique config;
  final bool exemple;
  final String numero;
  final String date;
  final List<LigneRecu> lignes;
  final String paiement;

  /// Vente à crédit : « Client : Kofi — reste à payer : 1 800 F ».
  final String? credit;

  @override
  Widget build(BuildContext context) {
    final total = lignes.fold<int>(0, (s, l) => s + l.montant);
    final couleur = Color(config.couleur);
    const petit = TextStyle(fontSize: 15, color: CouleursRecu.texteDoux);
    return DefaultTextStyle.merge(
      style: const TextStyle(color: CouleursRecu.texte),
      child: Container(
        key: const Key('apercu-recu'),
        decoration: BoxDecoration(
          color: CouleursRecu.fond,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: couleur,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
              ),
              child: Row(
                children: [
                  LogoBoutique(config: config, taille: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          config.nom,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (config.telephone.isNotEmpty)
                          Text(
                            config.telephone,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                            ),
                          ),
                        if (config.adresse.isNotEmpty)
                          Text(
                            config.adresse,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 12,
                    children: [
                      Text('$titre $numero', style: petit),
                      Text(date, style: petit),
                    ],
                  ),
                  const Divider(height: 20),
                  for (final l in lignes)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              l.libelle,
                              style: const TextStyle(fontSize: 17),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formatFrancs(l.montant),
                            style: const TextStyle(fontSize: 17),
                          ),
                        ],
                      ),
                    ),
                  const Divider(height: 20),
                  Row(
                    children: [
                      Text(
                        libelleTotal,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            formatFrancs(total),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: CouleursRecu.vert,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (paiement.isNotEmpty)
                    Text(
                      paiement == 'Crédit' ? 'À crédit' : 'Payé : $paiement',
                      style: petit,
                    ),
                  if (mention != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        mention!,
                        key: const Key('recu-mention'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  if (credit != null)
                    Text(
                      credit!,
                      key: const Key('recu-credit'),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: CouleursRecu.ambre,
                      ),
                    ),
                  const SizedBox(height: 10),
                  Text(
                    config.messageRecu,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  if (exemple)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        '(exemple)',
                        textAlign: TextAlign.center,
                        style: petit,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
