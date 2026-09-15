import 'dart:io';

import 'package:control_tuk_tuk/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MarketplaceWallet', () {
    test('lee total, reservado y disponible directamente del servidor', () {
      final wallet = MarketplaceWallet.fromMap({
        'currency': 'CUP',
        'total_balance': 500,
        'reserved_balance': '125.50',
        'available_balance': 374.5,
        'initial_deposit_confirmed': true,
        'initial_deposit_confirmed_at': '2026-09-15T12:00:00Z',
        'initial_deposit_amount': '500',
        'initial_minimum_snapshot': 500,
        'current_initial_minimum_deposit': '500.00',
        'commission_rate': 0.10,
      });

      expect(wallet.currency, 'CUP');
      expect(wallet.totalBalance, 500);
      expect(wallet.reservedBalance, 125.5);
      expect(wallet.availableBalance, 374.5);
      expect(wallet.initialDepositConfirmed, isTrue);
      expect(wallet.initialDepositAmount, 500);
      expect(wallet.initialMinimumSnapshot, 500);
      expect(wallet.currentInitialMinimumDeposit, 500);
      expect(wallet.commissionRate, 0.10);
    });
  });

  group('MarketplaceBillingMode', () {
    test('reconoce trial_free', () {
      expect(
        marketplaceBillingMode('trial_free'),
        MarketplaceBillingMode.trialFree,
      );
    });

    test('reconoce wallet_commission', () {
      expect(
        marketplaceBillingMode('wallet_commission'),
        MarketplaceBillingMode.walletCommission,
      );
    });

    test('tolera valores futuros desconocidos', () {
      expect(
        marketplaceBillingMode('future_mode'),
        MarketplaceBillingMode.unknown,
      );
    });
  });

  group('MarketplaceOnboarding', () {
    test('parsea conductor, vehículo, catálogos y assets', () {
      final onboarding = MarketplaceOnboarding.fromMap({
        'server_time': '2026-09-15T12:00:00Z',
        'display_name': 'Pedro',
        'phone': '+5355555555',
        'driver_profile_exists': true,
        'driver_status': 'incomplete',
        'driver_photo_asset_id': 'asset-driver',
        'driver_suspended': false,
        'vehicles': [
          {
            'vehicle_id': 'vehicle-1',
            'name': 'Tuk Tuk Cruz',
            'category_code': 'triciclo',
            'propulsion_code': 'electric',
            'brand': 'Marca',
            'model': 'Modelo',
            'passenger_capacity': 6,
            'services': ['passenger', 'courier'],
            'onboarding_complete': true,
            'is_active': true,
            'is_available': true,
          }
        ],
        'vehicle_categories': [
          {'code': 'triciclo', 'name': 'Triciclo', 'sort_order': 1}
        ],
        'propulsion_types': [
          {'code': 'electric', 'name': 'Eléctrico', 'sort_order': 1}
        ],
        'service_types': [
          {'code': 'passenger', 'name': 'Pasajeros', 'sort_order': 1}
        ],
        'assets': [
          {
            'asset_id': 'asset-driver',
            'asset_kind': 'driver_photo',
            'storage_bucket': 'marketplace-media',
            'storage_path': 'user/photo.jpg',
            'status': 'available',
          }
        ],
      });

      expect(onboarding.displayName, 'Pedro');
      expect(onboarding.driverProfileExists, isTrue);
      expect(onboarding.driverSuspended, isFalse);
      expect(onboarding.vehicles, hasLength(1));
      expect(onboarding.vehicles.first.id, 'vehicle-1');
      expect(onboarding.vehicles.first.services, ['passenger', 'courier']);
      expect(onboarding.vehicles.first.onboardingComplete, isTrue);
      expect(onboarding.vehicleCategories.first.code, 'triciclo');
      expect(onboarding.propulsionTypes.first.code, 'electric');
      expect(onboarding.serviceTypes.first.code, 'passenger');
      expect(onboarding.assets.first.isAvailable, isTrue);
    });

    test('tolera listas y campos nulos', () {
      final onboarding = MarketplaceOnboarding.fromMap({
        'vehicles': null,
        'vehicle_categories': null,
        'propulsion_types': null,
        'service_types': null,
        'assets': null,
      });

      expect(onboarding.vehicles, isEmpty);
      expect(onboarding.vehicleCategories, isEmpty);
      expect(onboarding.propulsionTypes, isEmpty);
      expect(onboarding.serviceTypes, isEmpty);
      expect(onboarding.assets, isEmpty);
    });
  });

  group('MarketplaceWorkAccess', () {
    test('parsea trial y acceso económico', () {
      final access = MarketplaceWorkAccess.fromMap({
        'server_time': '2026-09-15T12:00:00Z',
        'onboarding_complete': true,
        'driver_active': true,
        'vehicle_available': true,
        'trial_active': true,
        'trial_started_at': '2026-09-01T00:00:00Z',
        'trial_ends_at': '2026-10-01T00:00:00Z',
        'initial_deposit_confirmed': false,
        'suite_active': true,
        'can_start_trial': false,
        'can_accept_new_job': true,
        'next_billing_mode': 'trial_free',
      });

      expect(access.trialActive, isTrue);
      expect(access.canAcceptNewJob, isTrue);
      expect(access.nextBillingMode, MarketplaceBillingMode.trialFree);
      expect(access.initialDepositConfirmed, isFalse);
    });
  });

  group('Marketplace jobs', () {
    test('parsea trabajo disponible sin PII', () {
      final job = MarketplaceAvailableJob.fromMap({
        'job_id': 'job-1',
        'status': 'published',
        'service_code': 'passenger',
        'origin_text': 'Vedado',
        'destination_text': 'Habana Vieja',
        'passenger_count': 3,
        'final_price': '1200.50',
        'currency': 'CUP',
        'published_at': '2026-09-15T10:00:00Z',
      });

      expect(job.id, 'job-1');
      expect(job.serviceCode, 'passenger');
      expect(job.passengerCount, 3);
      expect(job.finalPrice, 1200.5);
    });

    test('parsea trabajo asignado trial_free', () {
      final job = MarketplaceJob.fromMap({
        'job_id': 'job-2',
        'status': 'accepted',
        'service_code': 'courier',
        'vehicle_id': 'vehicle-1',
        'billing_mode': 'trial_free',
        'commission_amount_snapshot': 0,
        'final_price': 900,
        'currency': 'CUP',
        'next_driver_action': 'start_en_route',
      });

      expect(job.billingMode, MarketplaceBillingMode.trialFree);
      expect(job.nextAction, 'start_en_route');
      expect(job.vehicleId, 'vehicle-1');
    });

    test('parsea trabajo asignado wallet_commission', () {
      final job = MarketplaceJob.fromMap({
        'job_id': 'job-3',
        'status': 'in_progress',
        'billing_mode': 'wallet_commission',
        'commission_amount_snapshot': '100',
        'final_price': 1000,
        'currency': 'CUP',
      });

      expect(job.billingMode, MarketplaceBillingMode.walletCommission);
      expect(job.commissionAmountSnapshot, 100);
    });

    test('tolera incidente y resolución', () {
      final job = MarketplaceJob.fromMap({
        'job_id': 'job-4',
        'status': 'incident',
        'billing_mode': 'wallet_commission',
        'final_price': 1000,
        'currency': 'CUP',
        'incident_reason': 'Prueba',
        'incident_resolution': 'completed',
        'incident_resolved_at': '2026-09-15T14:00:00Z',
      });

      expect(job.status, 'incident');
      expect(job.incidentResolution, 'completed');
      expect(job.incidentResolvedAt, isNotNull);
    });
  });

  group('Marketplace referrals', () {
    test('wallet mode usa CUP y no días como recompensa vigente', () {
      final program = MarketplaceReferralProgram.fromMap({
        'enabled': true,
        'reward_mode': 'marketplace_wallet_credit',
        'reward_enabled': true,
        'reward_amount': '100',
        'reward_currency': 'CUP',
        'reward_rule_version': 1,
        'qualification_mode': 'first_valid_job',
        'reward_days': 0,
        'referred_count': 4,
        'qualified_count': 2,
        'rewarded_count': 1,
      });

      expect(program.isWalletMode, isTrue);
      expect(program.rewardAmount, 100);
      expect(program.rewardCurrency, 'CUP');
      expect(program.rewardedCount, 1);
      expect(program.rewardDays, 0);
    });

    test('mantiene compatibilidad con referido legacy', () {
      final entry = MarketplaceReferralEntry.fromMap({
        'relationship_id': 'rel-1',
        'name': 'Usuario',
        'status': 'rewarded',
        'reward_days': 15,
        'created_at': '2026-08-01T00:00:00Z',
      });

      expect(entry.relationshipId, 'rel-1');
      expect(entry.rewardDays, 15);
      expect(entry.rewardAmount, 0);
    });
  });

  group('Marketplace misc', () {
    test('trial tolera fechas inválidas', () {
      final trial = MarketplaceTrial.fromMap({
        'started_at': 'invalid',
        'ends_at': null,
      });

      expect(trial.startedAt, isNull);
      expect(trial.endsAt, isNull);
    });

    test('contacto solo modela nombre y WhatsApp', () {
      final contact = MarketplaceCustomerContact.fromMap({
        'customer_display_name': 'Cliente',
        'customer_whatsapp_phone': '+5350000000',
      });

      expect(contact.name, 'Cliente');
      expect(contact.phone, '+5350000000');
    });
  });

  group('MarketplaceService source contract', () {
    late String source;

    setUpAll(() {
      source = File('lib/data/marketplace_service.dart').readAsStringSync();
    });

    test('no consulta tablas Marketplace directamente', () {
      expect(source.contains(".from('jobs')"), isFalse);
      expect(source.contains(".from('wallets')"), isFalse);
      expect(source.contains(".from('job_assignments')"), isFalse);
      expect(source.contains(".from('driver_profiles')"), isFalse);
    });

    test('transmite idempotency key desde la capa superior', () {
      expect(
          source.contains("'target_idempotency_key': idempotencyKey"), isTrue);
      expect(
          RegExp("target_idempotency_key': idempotencyKey")
              .allMatches(source)
              .length,
          greaterThanOrEqualTo(4));
    });

    test('incluye claim_referral_code', () {
      expect(source.contains("'claim_referral_code'"), isTrue);
    });

    test('wallet no recalcula saldo reservado o disponible', () {
      expect(source.contains("map['reserved_balance']"), isTrue);
      expect(source.contains("map['available_balance']"), isTrue);
    });
  });
}
