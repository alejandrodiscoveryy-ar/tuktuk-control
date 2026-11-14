import 'package:flutter_test/flutter_test.dart';
import 'package:control_tuk_tuk/main.dart';

void main() {
  test('commercial wallet figures are server values and not calculated from promo card', () {
    final data = <String, dynamic>{
      'generated_jobs': 3, 'own_paid_jobs': 1, 'own_savings_cup': '50.00',
      'fleet_credited_jobs': 1, 'credited_cup': 50, 'pending_cup': '0',
      'funding_required_cup': 50, 'reversal_pending_cup': 0, 'recent': [
        {'job_id': 'sample', 'amount': 50, 'state': 'credited', 'commercial_rate': .05},
      ],
    };
    final summary = MarketplaceImpulsaEarnings.fromMap(data);
    expect(summary.generated, 3);
    expect(summary.ownSavings, 50);
    expect(summary.credited, 50);
    expect(summary.fundingRequired, 50);
    expect(summary.recent.single['state'], 'credited');
    expect(() => MarketplaceImpulsaEarnings.fromMap({...data, 'credited_cup': -50}), throwsFormatException);
    expect(() => MarketplaceImpulsaEarnings.fromMap({...data, 'recent': null}), throwsFormatException);
  });
}
