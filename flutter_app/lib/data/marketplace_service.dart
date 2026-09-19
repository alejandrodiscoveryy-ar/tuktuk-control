part of '../main.dart';

double _marketNumber(Object? value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

int _marketInt(Object? value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;

bool _marketBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = '$value'.trim().toLowerCase();
  return text == 'true' || text == '1';
}

DateTime? _marketDate(Object? value) =>
    value == null ? null : DateTime.tryParse('$value')?.toUtc();

String? _marketText(Object? value) {
  if (value == null) return null;
  final text = '$value'.trim();
  return text.isEmpty || text == 'null' ? null : text;
}

List<Map<String, dynamic>> _marketMaps(Object? value) => value is List
    ? value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList()
    : const [];

List<String> _marketStrings(Object? value) => value is List
    ? value
        .map(_marketText)
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toList()
    : const [];

enum MarketplaceBillingMode {
  trialFree,
  walletCommission,
  unknown,
}

MarketplaceBillingMode marketplaceBillingMode(Object? value) =>
    switch ('$value') {
      'trial_free' => MarketplaceBillingMode.trialFree,
      'wallet_commission' => MarketplaceBillingMode.walletCommission,
      _ => MarketplaceBillingMode.unknown,
    };

class MarketplaceCatalogItem {
  const MarketplaceCatalogItem({
    required this.code,
    required this.name,
    required this.sortOrder,
  });

  final String code;
  final String name;
  final int sortOrder;

  factory MarketplaceCatalogItem.fromMap(Map map) => MarketplaceCatalogItem(
        code: _marketText(map['code']) ?? '',
        name: _marketText(map['name']) ?? '',
        sortOrder: _marketInt(map['sort_order']),
      );
}

class MarketplaceMediaAsset {
  const MarketplaceMediaAsset({
    required this.id,
    required this.status,
    this.assetKind,
    this.storageBucket,
    this.storagePath,
  });

  final String id;
  final String status;
  final String? assetKind;
  final String? storageBucket;
  final String? storagePath;

  bool get isAvailable => status == 'available';

  factory MarketplaceMediaAsset.fromMap(Map map) => MarketplaceMediaAsset(
        id: _marketText(map['asset_id'] ?? map['id']) ?? '',
        status: _marketText(map['status']) ?? 'unknown',
        assetKind: _marketText(map['asset_kind']),
        storageBucket: _marketText(map['storage_bucket']),
        storagePath: _marketText(map['storage_path']),
      );
}

class MarketplaceVehicle {
  const MarketplaceVehicle({
    required this.id,
    required this.services,
    required this.onboardingComplete,
    required this.isActive,
    required this.isAvailable,
    this.name,
    this.registration,
    this.categoryCode,
    this.propulsionCode,
    this.categoryOtherDescription,
    this.brand,
    this.model,
    this.year,
    this.passengerCapacity,
    this.cargoCapacityKg,
    this.cargoVolumeM3,
    this.cargoLengthCm,
    this.cargoWidthCm,
    this.cargoHeightCm,
    this.bodyType,
    this.mainPhotoAssetId,
    this.marketplaceStatus,
  });

  final String id;
  final String? name;
  final String? registration;
  final String? categoryCode;
  final String? propulsionCode;
  final String? categoryOtherDescription;
  final String? brand;
  final String? model;
  final int? year;
  final int? passengerCapacity;
  final double? cargoCapacityKg;
  final double? cargoVolumeM3;
  final double? cargoLengthCm;
  final double? cargoWidthCm;
  final double? cargoHeightCm;
  final String? bodyType;
  final String? mainPhotoAssetId;
  final String? marketplaceStatus;
  final List<String> services;
  final bool onboardingComplete;
  final bool isActive;
  final bool isAvailable;

  factory MarketplaceVehicle.fromMap(Map map) => MarketplaceVehicle(
        id: _marketText(map['vehicle_id'] ?? map['id']) ?? '',
        name: _marketText(map['name']),
        registration: _marketText(map['registration']),
        categoryCode: _marketText(map['category_code']),
        propulsionCode: _marketText(map['propulsion_code']),
        categoryOtherDescription:
            _marketText(map['category_other_description']),
        brand: _marketText(map['brand']),
        model: _marketText(map['model']),
        year: map['year'] == null ? null : _marketInt(map['year']),
        passengerCapacity: map['passenger_capacity'] == null
            ? null
            : _marketInt(map['passenger_capacity']),
        cargoCapacityKg: map['cargo_capacity_kg'] == null
            ? null
            : _marketNumber(map['cargo_capacity_kg']),
        cargoVolumeM3: map['cargo_volume_m3'] == null
            ? null
            : _marketNumber(map['cargo_volume_m3']),
        cargoLengthCm: map['cargo_length_cm'] == null
            ? null
            : _marketNumber(map['cargo_length_cm']),
        cargoWidthCm: map['cargo_width_cm'] == null
            ? null
            : _marketNumber(map['cargo_width_cm']),
        cargoHeightCm: map['cargo_height_cm'] == null
            ? null
            : _marketNumber(map['cargo_height_cm']),
        bodyType: _marketText(map['body_type']),
        mainPhotoAssetId: _marketText(map['main_photo_asset_id']),
        marketplaceStatus: _marketText(map['marketplace_status']),
        services: _marketStrings(map['services']),
        onboardingComplete: _marketBool(map['onboarding_complete']),
        isActive: _marketBool(map['is_active']),
        isAvailable: _marketBool(map['is_available']),
      );
}

class MarketplaceOnboarding {
  const MarketplaceOnboarding({
    required this.driverProfileExists,
    required this.driverSuspended,
    required this.vehicles,
    required this.vehicleCategories,
    required this.propulsionTypes,
    required this.serviceTypes,
    required this.assets,
    this.serverTime,
    this.displayName,
    this.phone,
    this.driverStatus,
    this.driverPhotoAssetId,
  });

  final DateTime? serverTime;
  final String? displayName;
  final String? phone;
  final bool driverProfileExists;
  final String? driverStatus;
  final String? driverPhotoAssetId;
  final bool driverSuspended;
  final List<MarketplaceVehicle> vehicles;
  final List<MarketplaceCatalogItem> vehicleCategories;
  final List<MarketplaceCatalogItem> propulsionTypes;
  final List<MarketplaceCatalogItem> serviceTypes;
  final List<MarketplaceMediaAsset> assets;

  factory MarketplaceOnboarding.fromMap(Map map) => MarketplaceOnboarding(
        serverTime: _marketDate(map['server_time']),
        displayName: _marketText(map['display_name']),
        phone: _marketText(map['phone']),
        driverProfileExists: _marketBool(map['driver_profile_exists']),
        driverStatus: _marketText(map['driver_status']),
        driverPhotoAssetId: _marketText(map['driver_photo_asset_id']),
        driverSuspended: _marketBool(map['driver_suspended']),
        vehicles: _marketMaps(map['vehicles'])
            .map(MarketplaceVehicle.fromMap)
            .toList(),
        vehicleCategories: _marketMaps(map['vehicle_categories'])
            .map(MarketplaceCatalogItem.fromMap)
            .toList(),
        propulsionTypes: _marketMaps(map['propulsion_types'])
            .map(MarketplaceCatalogItem.fromMap)
            .toList(),
        serviceTypes: _marketMaps(map['service_types'])
            .map(MarketplaceCatalogItem.fromMap)
            .toList(),
        assets: _marketMaps(map['assets'])
            .map(MarketplaceMediaAsset.fromMap)
            .toList(),
      );
}

class MarketplaceWorkAccess {
  const MarketplaceWorkAccess({
    required this.onboardingComplete,
    required this.driverActive,
    required this.vehicleAvailable,
    required this.trialActive,
    required this.initialDepositConfirmed,
    required this.suiteActive,
    required this.canStartTrial,
    required this.canAcceptNewJob,
    required this.nextBillingMode,
    this.serverTime,
    this.trialStartedAt,
    this.trialEndsAt,
  });

  final DateTime? serverTime;
  final bool onboardingComplete;
  final bool driverActive;
  final bool vehicleAvailable;
  final bool trialActive;
  final DateTime? trialStartedAt;
  final DateTime? trialEndsAt;
  final bool initialDepositConfirmed;
  final bool suiteActive;
  final bool canStartTrial;
  final bool canAcceptNewJob;
  final MarketplaceBillingMode nextBillingMode;

  factory MarketplaceWorkAccess.fromMap(Map map) => MarketplaceWorkAccess(
        serverTime: _marketDate(map['server_time']),
        onboardingComplete: _marketBool(map['onboarding_complete']),
        driverActive: _marketBool(map['driver_active']),
        vehicleAvailable: _marketBool(map['vehicle_available']),
        trialActive: _marketBool(map['trial_active']),
        trialStartedAt: _marketDate(map['trial_started_at']),
        trialEndsAt: _marketDate(map['trial_ends_at']),
        initialDepositConfirmed: _marketBool(map['initial_deposit_confirmed']),
        suiteActive: _marketBool(map['suite_active']),
        canStartTrial: _marketBool(map['can_start_trial']),
        canAcceptNewJob: _marketBool(map['can_accept_new_job']),
        nextBillingMode: marketplaceBillingMode(map['next_billing_mode']),
      );
}

class MarketplaceTrial {
  const MarketplaceTrial({
    this.startedVehicleId,
    this.startedAt,
    this.endsAt,
    this.createdAt,
  });

  final String? startedVehicleId;
  final DateTime? startedAt;
  final DateTime? endsAt;
  final DateTime? createdAt;

  factory MarketplaceTrial.fromMap(Map map) => MarketplaceTrial(
        startedVehicleId: _marketText(map['started_vehicle_id']),
        startedAt: _marketDate(map['started_at']),
        endsAt: _marketDate(map['ends_at']),
        createdAt: _marketDate(map['created_at']),
      );
}

class MarketplaceWallet {
  const MarketplaceWallet({
    required this.currency,
    required this.totalBalance,
    required this.reservedBalance,
    required this.availableBalance,
    required this.initialDepositConfirmed,
    required this.currentInitialMinimumDeposit,
    required this.commissionRate,
    this.initialDepositConfirmedAt,
    this.initialDepositAmount,
    this.initialMinimumSnapshot,
    this.realBalance,
    this.promotionalBalance,
    this.realAvailableBalance,
    this.promotionalAvailableBalance,
  });

  final String currency;
  final double totalBalance;
  final double reservedBalance;
  final double availableBalance;
  final double? realBalance;
  final double? promotionalBalance;
  final double? realAvailableBalance;
  final double? promotionalAvailableBalance;
  final bool initialDepositConfirmed;
  final DateTime? initialDepositConfirmedAt;
  final double? initialDepositAmount;
  final double? initialMinimumSnapshot;
  final double currentInitialMinimumDeposit;
  final double commissionRate;

  factory MarketplaceWallet.fromMap(Map map) => MarketplaceWallet(
        currency: _marketText(map['currency']) ?? 'CUP',
        totalBalance: _marketNumber(map['total_balance']),
        reservedBalance: _marketNumber(map['reserved_balance']),
        availableBalance: _marketNumber(map['available_balance']),
        realBalance: map['real_balance'] == null
            ? null
            : _marketNumber(map['real_balance']),
        promotionalBalance: map['promotional_balance'] == null
            ? null
            : _marketNumber(map['promotional_balance']),
        realAvailableBalance: map['real_available_balance'] == null
            ? null
            : _marketNumber(map['real_available_balance']),
        promotionalAvailableBalance: map['promotional_available_balance'] == null
            ? null
            : _marketNumber(map['promotional_available_balance']),
        initialDepositConfirmed: _marketBool(map['initial_deposit_confirmed']),
        initialDepositConfirmedAt:
            _marketDate(map['initial_deposit_confirmed_at']),
        initialDepositAmount: map['initial_deposit_amount'] == null
            ? null
            : _marketNumber(map['initial_deposit_amount']),
        initialMinimumSnapshot: map['initial_minimum_snapshot'] == null
            ? null
            : _marketNumber(map['initial_minimum_snapshot']),
        currentInitialMinimumDeposit:
            _marketNumber(map['current_initial_minimum_deposit']),
        commissionRate: _marketNumber(map['commission_rate']),
      );
}

class MarketplaceAvailableJob {
  const MarketplaceAvailableJob({
    required this.id,
    required this.serviceCode,
    required this.finalPrice,
    required this.currency,
    this.status,
    this.originText,
    this.destinationText,
    this.scheduledFor,
    this.passengerCount,
    this.cargoWeightKg,
    this.cargoVolumeM3,
    this.cargoLengthCm,
    this.cargoWidthCm,
    this.cargoHeightCm,
    this.requiredBodyType,
    this.publishedAt,
    this.expiresAt,
    this.createdAt,
  });

  final String id;
  final String? status;
  final String serviceCode;
  final String? originText;
  final String? destinationText;
  final DateTime? scheduledFor;
  final int? passengerCount;
  final double? cargoWeightKg;
  final double? cargoVolumeM3;
  final double? cargoLengthCm;
  final double? cargoWidthCm;
  final double? cargoHeightCm;
  final String? requiredBodyType;
  final double finalPrice;
  final String currency;
  final DateTime? publishedAt;
  final DateTime? expiresAt;
  final DateTime? createdAt;

  factory MarketplaceAvailableJob.fromMap(Map map) => MarketplaceAvailableJob(
        id: _marketText(map['job_id'] ?? map['id']) ?? '',
        status: _marketText(map['status']),
        serviceCode: _marketText(map['service_code']) ?? '',
        originText: _marketText(map['origin_text']),
        destinationText: _marketText(map['destination_text']),
        scheduledFor: _marketDate(map['scheduled_for']),
        passengerCount: map['passenger_count'] == null
            ? null
            : _marketInt(map['passenger_count']),
        cargoWeightKg: map['cargo_weight_kg'] == null
            ? null
            : _marketNumber(map['cargo_weight_kg']),
        cargoVolumeM3: map['cargo_volume_m3'] == null
            ? null
            : _marketNumber(map['cargo_volume_m3']),
        cargoLengthCm: map['cargo_length_cm'] == null
            ? null
            : _marketNumber(map['cargo_length_cm']),
        cargoWidthCm: map['cargo_width_cm'] == null
            ? null
            : _marketNumber(map['cargo_width_cm']),
        cargoHeightCm: map['cargo_height_cm'] == null
            ? null
            : _marketNumber(map['cargo_height_cm']),
        requiredBodyType: _marketText(map['required_body_type']),
        finalPrice: _marketNumber(map['final_price']),
        currency: _marketText(map['currency']) ?? 'CUP',
        publishedAt: _marketDate(map['published_at']),
        expiresAt: _marketDate(map['expires_at']),
        createdAt: _marketDate(map['created_at']),
      );
}

class MarketplaceJob {
  const MarketplaceJob({
    required this.id,
    required this.status,
    required this.billingMode,
    required this.finalPrice,
    required this.currency,
    this.serviceCode,
    this.originText,
    this.destinationText,
    this.scheduledFor,
    this.passengerCount,
    this.cargoWeightKg,
    this.cargoVolumeM3,
    this.cargoLengthCm,
    this.cargoWidthCm,
    this.cargoHeightCm,
    this.requiredBodyType,
    this.vehicleId,
    this.commissionAmountSnapshot,
    this.trialStartedAtSnapshot,
    this.trialEndsAtSnapshot,
    this.acceptedAt,
    this.completedAt,
    this.cancelledAt,
    this.publishedAt,
    this.expiresAt,
    this.createdAt,
    this.updatedAt,
    this.incidentFromStatus,
    this.incidentOpenedAt,
    this.incidentReason,
    this.incidentResolution,
    this.incidentResolvedAt,
    this.nextAction,
  });

  final String id;
  final String status;
  final String? serviceCode;
  final String? originText;
  final String? destinationText;
  final DateTime? scheduledFor;
  final int? passengerCount;
  final double? cargoWeightKg;
  final double? cargoVolumeM3;
  final double? cargoLengthCm;
  final double? cargoWidthCm;
  final double? cargoHeightCm;
  final String? requiredBodyType;
  final double finalPrice;
  final String currency;
  final String? vehicleId;
  final MarketplaceBillingMode billingMode;
  final double? commissionAmountSnapshot;
  final DateTime? trialStartedAtSnapshot;
  final DateTime? trialEndsAtSnapshot;
  final DateTime? acceptedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final DateTime? publishedAt;
  final DateTime? expiresAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? incidentFromStatus;
  final DateTime? incidentOpenedAt;
  final String? incidentReason;
  final String? incidentResolution;
  final DateTime? incidentResolvedAt;
  final String? nextAction;

  factory MarketplaceJob.fromMap(Map map) => MarketplaceJob(
        id: _marketText(map['job_id'] ?? map['id']) ?? '',
        status: _marketText(map['status']) ?? 'unknown',
        serviceCode: _marketText(map['service_code']),
        originText: _marketText(map['origin_text']),
        destinationText: _marketText(map['destination_text']),
        scheduledFor: _marketDate(map['scheduled_for']),
        passengerCount: map['passenger_count'] == null
            ? null
            : _marketInt(map['passenger_count']),
        cargoWeightKg: map['cargo_weight_kg'] == null
            ? null
            : _marketNumber(map['cargo_weight_kg']),
        cargoVolumeM3: map['cargo_volume_m3'] == null
            ? null
            : _marketNumber(map['cargo_volume_m3']),
        cargoLengthCm: map['cargo_length_cm'] == null
            ? null
            : _marketNumber(map['cargo_length_cm']),
        cargoWidthCm: map['cargo_width_cm'] == null
            ? null
            : _marketNumber(map['cargo_width_cm']),
        cargoHeightCm: map['cargo_height_cm'] == null
            ? null
            : _marketNumber(map['cargo_height_cm']),
        requiredBodyType: _marketText(map['required_body_type']),
        finalPrice: _marketNumber(map['final_price']),
        currency: _marketText(map['currency']) ?? 'CUP',
        vehicleId: _marketText(map['vehicle_id'] ?? map['assigned_vehicle_id']),
        billingMode: marketplaceBillingMode(map['billing_mode']),
        commissionAmountSnapshot: map['commission_amount_snapshot'] == null
            ? null
            : _marketNumber(map['commission_amount_snapshot']),
        trialStartedAtSnapshot: _marketDate(map['trial_started_at_snapshot']),
        trialEndsAtSnapshot: _marketDate(map['trial_ends_at_snapshot']),
        acceptedAt: _marketDate(map['accepted_at']),
        completedAt: _marketDate(map['completed_at']),
        cancelledAt: _marketDate(map['cancelled_at']),
        publishedAt: _marketDate(map['published_at']),
        expiresAt: _marketDate(map['expires_at']),
        createdAt: _marketDate(map['created_at']),
        updatedAt: _marketDate(map['updated_at']),
        incidentFromStatus: _marketText(map['incident_from_status']),
        incidentOpenedAt: _marketDate(map['incident_opened_at']),
        incidentReason: _marketText(map['incident_reason']),
        incidentResolution: _marketText(map['incident_resolution']),
        incidentResolvedAt: _marketDate(map['incident_resolved_at']),
        nextAction: _marketText(map['next_driver_action']),
      );
}

class MarketplaceCustomerContact {
  const MarketplaceCustomerContact({
    this.name,
    this.phone,
  });

  final String? name;
  final String? phone;

  factory MarketplaceCustomerContact.fromMap(Map map) =>
      MarketplaceCustomerContact(
        name: _marketText(map['customer_display_name']),
        phone: _marketText(map['customer_whatsapp_phone']),
      );
}

class MarketplaceReferralProgram {
  const MarketplaceReferralProgram({
    required this.enabled,
    required this.rewardMode,
    required this.rewardEnabled,
    required this.rewardAmount,
    required this.rewardRuleVersion,
    required this.qualificationMode,
    required this.referredCount,
    required this.qualifiedCount,
    required this.rewardedCount,
    this.rewardCurrency,
    this.code,
    this.link,
    this.rewardDays,
  });

  final bool enabled;
  final String rewardMode;
  final bool rewardEnabled;
  final double rewardAmount;
  final String? rewardCurrency;
  final int rewardRuleVersion;
  final String qualificationMode;
  final String? code;
  final String? link;
  final int referredCount;
  final int qualifiedCount;
  final int rewardedCount;
  final int? rewardDays;

  bool get isWalletMode => rewardMode == 'marketplace_wallet_credit';

  factory MarketplaceReferralProgram.fromMap(Map map) =>
      MarketplaceReferralProgram(
        enabled: _marketBool(map['enabled']),
        rewardMode: _marketText(map['reward_mode']) ?? 'legacy_days',
        rewardEnabled: map.containsKey('reward_enabled')
            ? _marketBool(map['reward_enabled'])
            : _marketBool(map['enabled']),
        rewardAmount: _marketNumber(map['reward_amount']),
        rewardCurrency: _marketText(map['reward_currency']),
        rewardRuleVersion: _marketInt(map['reward_rule_version']),
        qualificationMode: _marketText(map['qualification_mode']) ?? 'unknown',
        code: _marketText(map['code']),
        link: _marketText(map['link']),
        referredCount: _marketInt(map['referred_count']),
        qualifiedCount: _marketInt(map['qualified_count']),
        rewardedCount: _marketInt(
          map['rewarded_count'] ??
              map['earned_rewards'] ??
              map['applied_rewards'],
        ),
        rewardDays:
            map['reward_days'] == null ? null : _marketInt(map['reward_days']),
      );
}

class MarketplaceReferralEntry {
  const MarketplaceReferralEntry({
    required this.status,
    required this.rewardAmount,
    this.relationshipId,
    this.name,
    this.rewardCurrency,
    this.rewardSource,
    this.qualificationJobId,
    this.rewardedAt,
    this.createdAt,
    this.qualifiedAt,
    this.rewardDays,
  });

  final String? relationshipId;
  final String? name;
  final String status;
  final double rewardAmount;
  final String? rewardCurrency;
  final String? rewardSource;
  final String? qualificationJobId;
  final DateTime? rewardedAt;
  final DateTime? createdAt;
  final DateTime? qualifiedAt;
  final int? rewardDays;

  factory MarketplaceReferralEntry.fromMap(Map map) => MarketplaceReferralEntry(
        relationshipId: _marketText(map['relationship_id']),
        name: _marketText(map['name']),
        status: _marketText(map['status']) ?? 'unknown',
        rewardAmount: _marketNumber(map['reward_amount']),
        rewardCurrency: _marketText(map['reward_currency']),
        rewardSource: _marketText(map['reward_source']),
        qualificationJobId: _marketText(map['qualification_job_id']),
        rewardedAt: _marketDate(map['rewarded_at']),
        createdAt: _marketDate(map['created_at']),
        qualifiedAt: _marketDate(map['qualified_at']),
        rewardDays:
            map['reward_days'] == null ? null : _marketInt(map['reward_days']),
      );
}

/// Server-first Marketplace gateway. Jobs, wallet and trials never enter Hive/sync.
class MarketplaceService {
  MarketplaceService(this._client);

  final SupabaseClient _client;

  Future<Map<String, dynamic>> _one(
    String rpc, [
    Map<String, dynamic>? params,
  ]) async {
    final value = await _client.rpc(rpc, params: params);
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    if (value is List && value.isNotEmpty && value.first is Map) {
      return Map<String, dynamic>.from(value.first as Map);
    }
    return <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> _list(
    String rpc, [
    Map<String, dynamic>? params,
  ]) async {
    final value = await _client.rpc(rpc, params: params);
    return value is List
        ? value
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : const [];
  }

  Future<MarketplaceOnboarding> onboarding() =>
      _one('get_my_marketplace_onboarding').then(MarketplaceOnboarding.fromMap);

  Future<MarketplaceOnboarding> saveDriver(
    Map<String, dynamic> params,
  ) =>
      _one('save_my_marketplace_driver_onboarding', params)
          .then(MarketplaceOnboarding.fromMap);

  Future<MarketplaceOnboarding> saveVehicle(
    Map<String, dynamic> params,
  ) =>
      _one('save_my_marketplace_vehicle_onboarding', params)
          .then(MarketplaceOnboarding.fromMap);

  /// Creates an isolated Marketplace draft. Does not write to Control/Hive.
  Future<Map<String, dynamic>> createVehicle({
    required String name,
    required String idempotencyKey,
  }) =>
      _one('create_my_marketplace_vehicle', {
        'target_vehicle_name': name,
        'target_idempotency_key': idempotencyKey,
      });

  Future<MarketplaceMediaAsset> prepareMedia(
    Map<String, dynamic> params,
  ) =>
      _one('prepare_my_marketplace_media_upload', params)
          .then(MarketplaceMediaAsset.fromMap);

  Future<MarketplaceMediaAsset> uploadMedia({
    required String assetKind,
    required Uint8List bytes,
    required String mimeType,
    required String extension,
    required String idempotencyKey,
  }) async {
    final prepared = await prepareMedia({
      'target_asset_kind': assetKind,
      'target_mime_type': mimeType,
      'target_byte_size': bytes.length,
      'target_extension': extension,
      'target_sha256': sha256.convert(bytes).toString(),
      'target_idempotency_key': idempotencyKey,
    });

    if (prepared.isAvailable) return prepared;

    final bucket = prepared.storageBucket;
    final path = prepared.storagePath;

    if (prepared.id.isEmpty || bucket == null || path == null) {
      throw const FormatException(
        'El servidor no devolvió una ruta válida para la imagen.',
      );
    }

    try {
      await _client.storage.from(bucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: mimeType,
              upsert: false,
            ),
          );
    } on StorageException {
      // Si la subida anterior llegó a Storage pero el cliente perdió
      // la respuesta, intentamos finalizar el mismo asset idempotente.
      try {
        final existing = await finalizeMedia(prepared.id);
        if (existing.isAvailable) return existing;
      } catch (_) {
        // Conservamos el error original de Storage.
      }
      rethrow;
    }

    return finalizeMedia(prepared.id);
  }

  Future<MarketplaceMediaAsset> finalizeMedia(String assetId) => _one(
        'finalize_my_marketplace_media_upload',
        {'target_asset_id': assetId},
      ).then(MarketplaceMediaAsset.fromMap);

  Future<MarketplaceWorkAccess> access(String vehicleId) => _one(
        'get_my_marketplace_work_access',
        {'target_vehicle_id': vehicleId},
      ).then(MarketplaceWorkAccess.fromMap);

  Future<MarketplaceTrial> startTrial(
    String vehicleId,
    String idempotencyKey,
  ) =>
      _one(
        'start_my_marketplace_work_trial',
        {
          'target_vehicle_id': vehicleId,
          'target_idempotency_key': idempotencyKey,
        },
      ).then(MarketplaceTrial.fromMap);

  Future<MarketplaceWallet> wallet() =>
      _one('get_my_marketplace_wallet').then(MarketplaceWallet.fromMap);

  Future<List<MarketplaceAvailableJob>> available(
    String vehicleId,
  ) =>
      _list(
        'list_my_marketplace_available_jobs',
        {'target_vehicle_id': vehicleId},
      ).then(
        (items) => items.map(MarketplaceAvailableJob.fromMap).toList(),
      );

  Future<List<MarketplaceJob>> jobs(String scope) => _list(
        'list_my_marketplace_jobs',
        {'target_scope': scope},
      ).then((items) => items.map(MarketplaceJob.fromMap).toList());

  Future<MarketplaceJob> accept(
    String jobId,
    String vehicleId,
    String idempotencyKey,
  ) =>
      _one(
        'accept_job',
        {
          'target_job_id': jobId,
          'target_vehicle_id': vehicleId,
          'target_idempotency_key': idempotencyKey,
        },
      ).then(MarketplaceJob.fromMap);

  Future<MarketplaceJob> advance(
    String jobId,
    String action,
    String idempotencyKey,
  ) =>
      _one(
        'advance_my_marketplace_job',
        {
          'target_job_id': jobId,
          'target_action': action,
          'target_idempotency_key': idempotencyKey,
        },
      ).then(MarketplaceJob.fromMap);

  Future<MarketplaceJob> cancel(
    String jobId,
    String reason,
    String idempotencyKey,
  ) =>
      _one(
        'cancel_my_marketplace_job',
        {
          'target_job_id': jobId,
          'target_reason': reason,
          'target_idempotency_key': idempotencyKey,
        },
      ).then(MarketplaceJob.fromMap);

  Future<MarketplaceCustomerContact> contact(String jobId) => _one(
        'get_my_marketplace_customer_contact',
        {'target_job_id': jobId},
      ).then(MarketplaceCustomerContact.fromMap);

  Future<MarketplaceReferralProgram> referralProgram(
    String projectId,
  ) =>
      _one(
        'get_my_referral_program',
        {'target_project_id': projectId},
      ).then(MarketplaceReferralProgram.fromMap);

  Future<List<MarketplaceReferralEntry>> referrals(
    String projectId,
  ) =>
      _list(
        'get_my_referrals',
        {'target_project_id': projectId},
      ).then(
        (items) => items.map(MarketplaceReferralEntry.fromMap).toList(),
      );

  Future<String> claimReferralCode(String projectId, String code) async {
    final value = await _client.rpc(
      'claim_referral_code',
      params: {
        'target_project_id': projectId,
        'target_code': code,
      },
    );
    final relationshipId = _marketText(value);
    if (relationshipId != null) return relationshipId;
    throw const FormatException('Claim sin identificador de relación');
  }
}
