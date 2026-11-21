import 'package:flutter_test/flutter_test.dart';
import 'package:zero_perte/services/notifications.dart';

void main() {
  test('canal des alertes = celui du relais (zp- + 32 premiers caractères du SHA-256)', () {
    expect(
      sujetAlertes('jeton-boutique-deux-0123456789'),
      'zp-7a4f191582478244b3f2912c1744a7f9',
    );
  });

  test('sans identifiants Firebase dans la fabrication : désactivé', () {
    expect(firebaseConfigure, isFalse);
  });
}
