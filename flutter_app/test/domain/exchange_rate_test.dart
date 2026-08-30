import 'package:control_tuk_tuk/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('primera tasa usa dirección same', () {
    expect(
      exchangeRateDirectionFor(null, 410),
      ExchangeRateDirection.same,
    );
  });

  test('tasa mayor usa dirección up', () {
    expect(
      exchangeRateDirectionFor(400, 410),
      ExchangeRateDirection.up,
    );
  });

  test('tasa menor usa dirección down', () {
    expect(
      exchangeRateDirectionFor(410, 400),
      ExchangeRateDirection.down,
    );
  });

  test('tasa sin cambio usa dirección same', () {
    expect(
      exchangeRateDirectionFor(410, 410),
      ExchangeRateDirection.same,
    );
  });
}
