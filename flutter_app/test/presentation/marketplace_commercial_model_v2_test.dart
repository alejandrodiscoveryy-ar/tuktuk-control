import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String onboarding;
  late String service;
  late String jobs;
  late String screens;
  late String shell;

  setUpAll(() {
    onboarding = File(
      'lib/presentation/marketplace_onboarding.dart',
    ).readAsStringSync();
    service = File('lib/data/marketplace_service.dart').readAsStringSync();
    jobs = File('lib/presentation/marketplace_jobs.dart').readAsStringSync();
    screens = File('lib/presentation/screens.dart').readAsStringSync();
    shell = File('lib/presentation/marketplace_shell.dart').readAsStringSync();
  });

  test('crédito a prueba de deuda y sin retiro desde la Billetera de trabajo', () {
    final walletCard = onboarding.split(
      'Widget _buildWalletCard(BuildContext context) {',
    ).last.split('Widget _walletValue(').first;
    expect(service, contains('get_my_marketplace_wallet_transition_v1'));
    expect(service, contains("summary['debt_cup']"));
    expect(walletCard, contains('marketplace-wallet-debt-warning'));
    expect(walletCard, contains('_walletDebtUserId == widget.store.user?.id'));
    expect(walletCard, contains('(_walletDebtCup ?? 0) > 0'));
    expect(walletCard, contains('Recarga la billetera de trabajo'));
    expect(walletCard, isNot(contains('Solicitar retiro')));
    expect(jobs, contains('job.usesInitialCredit'));
    expect(jobs, contains('job.canAccept == false'));
    expect(jobs, contains('Aceptar a crédito'));
    expect(jobs, contains('MARKETPLACE_DEBT_PENDING'));
  });

  group('TUKTUK 2.0 · contrato comercial Prestador', () {
    test('la promoción ya no depende de un botón manual', () {
      expect(onboarding, isNot(contains('Comenzar 30 días gratis')));
      expect(onboarding, isNot(contains('_startTrial')));
      expect(service, isNot(contains("'start_my_marketplace_work_trial'")));
      expect(onboarding, contains('Promoción inicial activa'));
      expect(onboarding, contains('se activa automáticamente'));
    });

    test('la billetera no exige depósito inicial obligatorio', () {
      expect(
        onboarding,
        isNot(contains('debe confirmarse un depósito inicial mínimo')),
      );
      expect(onboarding, isNot(contains('Depósito inicial confirmado')));
      final walletCard = onboarding.split(
        'Widget _buildWalletCard(BuildContext context) {',
      ).last.split('Widget _walletValue(').first;
      expect(walletCard, contains("'Tu dinero para trabajar'"));
      expect(walletCard, contains("'Saldo disponible para carreras'"));
      expect(walletCard, contains("'¿De dónde sale ese saldo?'"));
      expect(walletCard, contains("'Recargas y otros abonos'"));
      expect(walletCard, contains("'Bonificaciones'"));
      expect(walletCard, contains('wallet.availableBalance'));
      expect(walletCard, contains('wallet.realAvailableBalance!'));
      expect(walletCard, contains('wallet.promotionalAvailableBalance!'));
      expect(walletCard, contains('wallet.reservedBalance > 0'));
      expect(walletCard, contains("'Recargar saldo'"));
      expect(walletCard, contains('desde Impulsa.'));
      expect(walletCard, isNot(contains('ExpansionTile(')));
      expect(walletCard, isNot(contains("'Saldo total'")));
      expect(walletCard, isNot(contains("'Real disponible'")));
      expect(walletCard, isNot(contains("'Promo disponible'")));
      expect(walletCard, isNot(contains('Comisión estándar:')));
    });

    test('referidos usa primer trabajo válido y monto del servidor', () {
      expect(screens, isNot(contains("'100 CUP acreditados'")));
      expect(screens, isNot(contains("'+100 CUP'")));
      expect(screens, contains('primer trabajo válido'));
      expect(screens, contains('program.rewardAmount'));
      expect(shell, isNot(contains('subtitle:')));
      expect(shell, contains("title: Text(tr('Referidos'))"));
    });

    test('trial_free se presenta como promoción inicial', () {
      expect(jobs, contains('Promoción inicial · sin comisión'));
      expect(jobs, isNot(contains('Periodo gratuito · sin comisión')));
    });
  });
}
