part of '../main.dart';

double? _marketplaceOptionalNumber(String value) {
  final clean = value.trim().replaceAll(',', '.');
  if (clean.isEmpty) return null;
  return double.tryParse(clean);
}

int? _marketplaceOptionalInt(String value) {
  final clean = value.trim();
  if (clean.isEmpty) return null;
  return int.tryParse(clean);
}

String _marketplaceDateTimeLabel(DateTime? value) {
  if (value == null) return '—';
  return DateFormat('dd/MM/yyyy · HH:mm').format(value.toLocal());
}

class MarketplaceOnboardingScreen extends StatefulWidget {
  const MarketplaceOnboardingScreen({
    required this.store,
    super.key,
  });

  final RecordStore store;

  @override
  State<MarketplaceOnboardingScreen> createState() =>
      _MarketplaceOnboardingScreenState();
}

class _MarketplaceOnboardingScreenState
    extends State<MarketplaceOnboardingScreen> {
  late final MarketplaceService _service;
  late final ImagePicker _imagePicker;

  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _brand = TextEditingController();
  final _model = TextEditingController();
  final _year = TextEditingController();
  final _passengers = TextEditingController();
  final _cargoKg = TextEditingController();
  final _bodyType = TextEditingController();
  final _otherCategory = TextEditingController();

  MarketplaceOnboarding? _data;
  String? _selectedVehicleId;
  String? _selectedCategory;
  String? _selectedPropulsion;
  final Set<String> _selectedServices = {};

  Uint8List? _driverPhotoBytes;
  String? _driverPhotoUploadKey;
  String? _driverPhotoLabel;

  Uint8List? _vehiclePhotoBytes;
  String? _vehiclePhotoUploadKey;
  String? _vehiclePhotoLabel;

  MarketplaceWorkAccess? _access;
  bool _accessLoading = false;
  bool _startingTrial = false;
  String? _accessError;
  String? _trialStartKey;

  String? get _marketplacePreviewState {
    if (!kIsWeb) return null;

    final host = Uri.base.host;
    if (host != '127.0.0.1' && host != 'localhost') return null;

    final state = Uri.base.queryParameters['marketplacePreview'];

    if (state == 'ready' ||
        state == 'trial' ||
        state == 'expired' ||
        state == 'incomplete') {
      return state;
    }

    return null;
  }

  bool get _localPreview => _marketplacePreviewState != null;

  bool _loading = true;
  bool _saving = false;
  bool _processingPhoto = false;
  String? _error;

  bool get _canEdit =>
      !_localPreview &&
      !_saving &&
      !_processingPhoto &&
      !_startingTrial &&
      !(_data?.driverSuspended ?? false);

  @override
  void initState() {
    super.initState();
    _service = MarketplaceService(Supabase.instance.client);
    _imagePicker = ImagePicker();
    unawaited(_load());
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _brand.dispose();
    _model.dispose();
    _year.dispose();
    _passengers.dispose();
    _cargoKg.dispose();
    _bodyType.dispose();
    _otherCategory.dispose();
    super.dispose();
  }

  MarketplaceVehicle? _findVehicle(String? id) {
    if (id == null) return null;
    final data = _data;
    if (data == null) return null;
    for (final vehicle in data.vehicles) {
      if (vehicle.id == id) return vehicle;
    }
    return null;
  }

  String? _validCatalogValue(
    String? value,
    List<MarketplaceCatalogItem> catalog,
  ) {
    if (value == null) return null;
    return catalog.any((item) => item.code == value) ? value : null;
  }

  MarketplaceOnboarding _previewOnboarding() {
    final complete = _marketplacePreviewState != 'incomplete';

    return MarketplaceOnboarding.fromMap({
      'server_time': DateTime.now().toUtc().toIso8601String(),
      'display_name': 'Conductor de muestra',
      'phone': '+5355555555',
      'driver_profile_exists': true,
      'driver_status': complete ? 'active' : 'pending',
      'driver_photo_asset_id': complete ? 'preview-driver-photo' : null,
      'driver_suspended': false,
      'vehicles': [
        {
          'vehicle_id': 'preview-vehicle',
          'name': 'TUKTUK de muestra',
          'category_code': 'tricycle',
          'propulsion_code': 'electric',
          'brand': 'TUKTUK',
          'model': 'Eléctrico',
          'year': 2026,
          'passenger_capacity': 8,
          'cargo_capacity_kg': 250,
          'body_type': 'Pasajeros y carga',
          'main_photo_asset_id': complete ? 'preview-vehicle-photo' : null,
          'marketplace_status': complete ? 'active' : 'onboarding',
          'services': [
            'passenger',
            'cargo',
            'courier',
            'tourism',
          ],
          'onboarding_complete': complete,
          'is_active': complete,
          'is_available': complete,
        },
      ],
      'vehicle_categories': [
        {'code': 'car', 'name': 'Auto ligero', 'sort_order': 1},
        {'code': 'tricycle', 'name': 'Triciclo', 'sort_order': 2},
        {'code': 'motorcycle', 'name': 'Motocicleta', 'sort_order': 3},
        {'code': 'van', 'name': 'Furgoneta', 'sort_order': 4},
        {'code': 'truck', 'name': 'Camión', 'sort_order': 5},
        {'code': 'other', 'name': 'Otro', 'sort_order': 6},
      ],
      'propulsion_types': [
        {'code': 'electric', 'name': 'Eléctrico', 'sort_order': 1},
        {'code': 'combustion', 'name': 'Combustión', 'sort_order': 2},
        {'code': 'hybrid', 'name': 'Híbrido', 'sort_order': 3},
      ],
      'service_types': [
        {'code': 'passenger', 'name': 'Pasajeros', 'sort_order': 1},
        {'code': 'cargo', 'name': 'Carga', 'sort_order': 2},
        {'code': 'courier', 'name': 'Mensajería', 'sort_order': 3},
        {'code': 'tourism', 'name': 'Turismo', 'sort_order': 4},
      ],
      'assets': [],
    });
  }

  MarketplaceWorkAccess _previewAccess() {
    final state = _marketplacePreviewState ?? 'ready';
    final now = DateTime.now().toUtc();

    if (state == 'incomplete') {
      return MarketplaceWorkAccess.fromMap({
        'server_time': now.toIso8601String(),
        'onboarding_complete': false,
        'driver_active': false,
        'vehicle_available': false,
        'trial_active': false,
        'initial_deposit_confirmed': false,
        'suite_active': true,
        'can_start_trial': false,
        'can_accept_new_job': false,
        'next_billing_mode': 'trial_free',
      });
    }

    if (state == 'trial') {
      return MarketplaceWorkAccess.fromMap({
        'server_time': now.toIso8601String(),
        'onboarding_complete': true,
        'driver_active': true,
        'vehicle_available': true,
        'trial_active': true,
        'trial_started_at':
            now.subtract(const Duration(days: 5)).toIso8601String(),
        'trial_ends_at': now.add(const Duration(days: 25)).toIso8601String(),
        'initial_deposit_confirmed': false,
        'suite_active': true,
        'can_start_trial': false,
        'can_accept_new_job': true,
        'next_billing_mode': 'trial_free',
      });
    }

    if (state == 'expired') {
      return MarketplaceWorkAccess.fromMap({
        'server_time': now.toIso8601String(),
        'onboarding_complete': true,
        'driver_active': true,
        'vehicle_available': true,
        'trial_active': false,
        'trial_started_at':
            now.subtract(const Duration(days: 40)).toIso8601String(),
        'trial_ends_at':
            now.subtract(const Duration(days: 10)).toIso8601String(),
        'initial_deposit_confirmed': false,
        'suite_active': true,
        'can_start_trial': false,
        'can_accept_new_job': false,
        'next_billing_mode': 'wallet_commission',
      });
    }

    return MarketplaceWorkAccess.fromMap({
      'server_time': now.toIso8601String(),
      'onboarding_complete': true,
      'driver_active': true,
      'vehicle_available': true,
      'trial_active': false,
      'initial_deposit_confirmed': false,
      'suite_active': true,
      'can_start_trial': true,
      'can_accept_new_job': false,
      'next_billing_mode': 'trial_free',
    });
  }

  Future<void> _load() async {
    if (_localPreview) {
      final data = _previewOnboarding();

      if (!mounted) return;

      setState(() {
        _data = data;
        _loading = false;
        _error = null;
        _applyData(data);
        _access = _previewAccess();
        _accessLoading = false;
        _accessError = null;
      });

      return;
    }
    if (widget.store.user == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Inicia sesión con Google para configurar Trabajos.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await _service.onboarding();
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
        _applyData(data);
      });

      await _loadAccess();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No se pudo cargar tu configuración de Trabajos.';
      });
    }
  }

  void _applyData(
    MarketplaceOnboarding data, {
    String? preferredVehicleId,
  }) {
    _name.text = data.displayName ?? widget.store.profileDisplayName;
    _phone.text = data.phone ?? '';

    final preferred = preferredVehicleId ??
        _selectedVehicleId ??
        widget.store.activeVehicle?.id;

    MarketplaceVehicle? vehicle;

    if (preferred != null) {
      for (final candidate in data.vehicles) {
        if (candidate.id == preferred) {
          vehicle = candidate;
          break;
        }
      }
    }

    if (vehicle == null && data.vehicles.isNotEmpty) {
      vehicle = data.vehicles.first;
    }

    _selectedVehicleId = vehicle?.id;
    _loadVehicleFields(vehicle);
  }

  void _loadVehicleFields(MarketplaceVehicle? vehicle) {
    _selectedCategory = vehicle?.categoryCode;
    _selectedPropulsion = vehicle?.propulsionCode;

    _brand.text = vehicle?.brand ?? '';
    _model.text = vehicle?.model ?? '';
    _year.text = vehicle?.year?.toString() ?? '';
    _passengers.text = vehicle?.passengerCapacity?.toString() ?? '';
    _cargoKg.text = vehicle?.cargoCapacityKg?.toString() ?? '';
    _bodyType.text = vehicle?.bodyType ?? '';
    _otherCategory.text = vehicle?.categoryOtherDescription ?? '';

    _selectedServices
      ..clear()
      ..addAll(vehicle?.services ?? const []);
  }

  Future<void> _loadAccess({bool showSpinner = true}) async {
    if (_localPreview) {
      if (!mounted) return;

      setState(() {
        _access = _previewAccess();
        _accessLoading = false;
        _accessError = null;
      });

      return;
    }

    final vehicleId = _selectedVehicleId;

    if (vehicleId == null) {
      if (!mounted) return;
      setState(() {
        _access = null;
        _accessLoading = false;
        _accessError = null;
      });
      return;
    }

    if (showSpinner) {
      setState(() {
        _accessLoading = true;
        _accessError = null;
      });
    }

    try {
      final access = await _service.access(vehicleId);

      if (!mounted || _selectedVehicleId != vehicleId) return;

      setState(() {
        _access = access;
        _accessLoading = false;
        _accessError = null;
      });
    } catch (_) {
      if (!mounted || _selectedVehicleId != vehicleId) return;

      setState(() {
        _access = null;
        _accessLoading = false;
        _accessError = 'No se pudo consultar el estado de Trabajos.';
      });
    }
  }

  Future<void> _startTrial() async {
    if (_localPreview) {
      toast(
        context,
        'Vista previa local: no se inició ningún periodo gratuito.',
      );
      return;
    }

    final vehicleId = _selectedVehicleId;
    final access = _access;

    if (vehicleId == null ||
        access == null ||
        !access.canStartTrial ||
        _startingTrial) {
      return;
    }

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Comenzar 30 días gratis'),
            content: const Text(
              'Los 30 días comienzan cuando confirmes. '
              'La prueba no se inicia automáticamente y solo puede utilizarse una vez.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Ahora no'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Comenzar'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || !mounted) return;

    setState(() => _startingTrial = true);

    final key = _trialStartKey ?? _marketplaceUuidV4();
    _trialStartKey = key;

    try {
      final trial = await _service.startTrial(
        vehicleId,
        key,
      );

      if (!mounted) return;

      await _loadAccess(showSpinner: false);

      if (!mounted) return;

      setState(() => _trialStartKey = null);

      final endsAt = trial.endsAt ?? _access?.trialEndsAt;

      toast(
        context,
        endsAt == null
            ? 'Tus 30 días gratis comenzaron.'
            : 'Tus 30 días gratis comenzaron. Finalizan el ${_marketplaceDateTimeLabel(endsAt)}.',
      );
    } catch (_) {
      if (mounted) {
        toast(
          context,
          'No se pudo confirmar el inicio de la prueba. Puedes intentarlo nuevamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _startingTrial = false);
    }
  }

  Future<ImageSource?> _choosePhotoSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPhoto(String assetKind) async {
    if (!_canEdit) return;

    final source = await _choosePhotoSource();
    if (source == null || !mounted) return;

    setState(() => _processingPhoto = true);

    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 92,
      );

      if (picked == null) return;

      final sourceBytes = await picked.readAsBytes();

      final normalized = normalizeMarketplaceImage(
        sourceBytes: sourceBytes,
        assetKind: assetKind,
      );

      if (!mounted) return;

      final sizeKb = (normalized.bytes.length / 1024).ceil();
      final label = '${normalized.width} × ${normalized.height} · $sizeKb KB';

      setState(() {
        if (assetKind == 'driver_photo') {
          _driverPhotoBytes = normalized.bytes;
          _driverPhotoUploadKey = _marketplaceUuidV4();
          _driverPhotoLabel = label;
        } else if (assetKind == 'vehicle_photo') {
          _vehiclePhotoBytes = normalized.bytes;
          _vehiclePhotoUploadKey = _marketplaceUuidV4();
          _vehiclePhotoLabel = label;
        }
      });

      toast(context, 'Foto optimizada: $label');
    } catch (_) {
      if (mounted) {
        toast(
          context,
          'No se pudo procesar la foto. Prueba con otra imagen.',
        );
      }
    } finally {
      if (mounted) setState(() => _processingPhoto = false);
    }
  }

  Future<void> _saveDriver() async {
    final data = _data;
    if (data == null || !_canEdit) return;

    final name = _name.text.trim();
    final phone = _phone.text.trim();

    if (name.isEmpty) {
      toast(context, 'Escribe tu nombre.');
      return;
    }

    if (!RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(phone)) {
      toast(
        context,
        'Usa el teléfono con código de país. Ejemplo: +5355555555.',
      );
      return;
    }

    setState(() => _saving = true);

    try {
      var photoAssetId = data.driverPhotoAssetId;
      final pendingPhoto = _driverPhotoBytes;

      if (pendingPhoto != null) {
        final uploadKey = _driverPhotoUploadKey ?? _marketplaceUuidV4();
        _driverPhotoUploadKey = uploadKey;

        final uploaded = await _service.uploadMedia(
          assetKind: 'driver_photo',
          bytes: pendingPhoto,
          mimeType: 'image/jpeg',
          extension: 'jpg',
          idempotencyKey: uploadKey,
        );

        photoAssetId = uploaded.id;
      }

      final updated = await _service.saveDriver({
        'target_display_name': name,
        'target_phone': phone,
        'target_photo_asset_id': photoAssetId,
      });

      if (!mounted) return;

      setState(() {
        _driverPhotoBytes = null;
        _driverPhotoUploadKey = null;
        _driverPhotoLabel = null;
        _data = updated;
        _applyData(
          updated,
          preferredVehicleId: _selectedVehicleId,
        );
      });

      await _loadAccess(showSpinner: false);

      if (!mounted) return;
      toast(context, 'Perfil de conductor guardado.');
    } catch (_) {
      if (mounted) {
        toast(context, 'No se pudo guardar el perfil de conductor.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveVehicle() async {
    final data = _data;
    final vehicle = _findVehicle(_selectedVehicleId);

    if (data == null || vehicle == null || !_canEdit) return;

    final category = _selectedCategory;
    final propulsion = _selectedPropulsion;

    if (category == null || propulsion == null) {
      toast(context, 'Selecciona categoría y tipo de propulsión.');
      return;
    }

    if (category == 'other' && _otherCategory.text.trim().isEmpty) {
      toast(context, 'Describe el tipo de vehículo.');
      return;
    }

    if (_selectedServices.isEmpty) {
      toast(context, 'Selecciona al menos un servicio.');
      return;
    }

    final year = _marketplaceOptionalInt(_year.text);
    final passengers = _marketplaceOptionalInt(_passengers.text);
    final cargoKg = _marketplaceOptionalNumber(_cargoKg.text);

    if (_year.text.trim().isNotEmpty && year == null) {
      toast(context, 'El año del vehículo no es válido.');
      return;
    }

    if (_passengers.text.trim().isNotEmpty &&
        (passengers == null || passengers < 0)) {
      toast(context, 'La capacidad de pasajeros no es válida.');
      return;
    }

    if (_cargoKg.text.trim().isNotEmpty && (cargoKg == null || cargoKg < 0)) {
      toast(context, 'La capacidad de carga no es válida.');
      return;
    }

    setState(() => _saving = true);

    try {
      final services = _selectedServices.toList()..sort();

      var photoAssetId = vehicle.mainPhotoAssetId;
      final pendingPhoto = _vehiclePhotoBytes;

      if (pendingPhoto != null) {
        final uploadKey = _vehiclePhotoUploadKey ?? _marketplaceUuidV4();
        _vehiclePhotoUploadKey = uploadKey;

        final uploaded = await _service.uploadMedia(
          assetKind: 'vehicle_photo',
          bytes: pendingPhoto,
          mimeType: 'image/jpeg',
          extension: 'jpg',
          idempotencyKey: uploadKey,
        );

        photoAssetId = uploaded.id;
      }

      final updated = await _service.saveVehicle({
        'target_vehicle_id': vehicle.id,
        'target_category_code': category,
        'target_propulsion_code': propulsion,
        'target_category_other_description':
            category == 'other' ? _otherCategory.text.trim() : null,
        'target_brand': _brand.text.trim().isEmpty ? null : _brand.text.trim(),
        'target_model': _model.text.trim().isEmpty ? null : _model.text.trim(),
        'target_year': year,
        'target_passenger_capacity': passengers,
        'target_cargo_capacity_kg': cargoKg,
        'target_cargo_volume_m3': vehicle.cargoVolumeM3,
        'target_cargo_length_cm': vehicle.cargoLengthCm,
        'target_cargo_width_cm': vehicle.cargoWidthCm,
        'target_cargo_height_cm': vehicle.cargoHeightCm,
        'target_body_type':
            _bodyType.text.trim().isEmpty ? null : _bodyType.text.trim(),
        'target_main_photo_asset_id': photoAssetId,
        'target_service_codes': services,
      });

      if (!mounted) return;

      setState(() {
        _vehiclePhotoBytes = null;
        _vehiclePhotoUploadKey = null;
        _vehiclePhotoLabel = null;
        _data = updated;
        _applyData(
          updated,
          preferredVehicleId: vehicle.id,
        );
      });

      await _loadAccess(showSpinner: false);

      if (!mounted) return;
      toast(context, 'Vehículo guardado.');
    } catch (_) {
      if (mounted) {
        toast(context, 'No se pudo guardar la configuración del vehículo.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildAccessCard(
    BuildContext context,
    MarketplaceVehicle? vehicle,
  ) {
    final access = _access;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Activación de Trabajos',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          if (vehicle == null)
            const Text(
              'Selecciona y configura un vehículo para continuar.',
            )
          else if (_accessLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_accessError != null) ...[
            Text(_accessError!),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _loadAccess,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ] else if (access == null)
            const Text('No hay información de acceso disponible.')
          else ...[
            Row(
              children: [
                Icon(
                  access.onboardingComplete
                      ? Icons.check_circle_rounded
                      : Icons.pending_outlined,
                  color: access.onboardingComplete
                      ? appPrimaryColor(context)
                      : kTertiary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    access.onboardingComplete
                        ? 'Perfil y vehículo listos'
                        : 'Configuración incompleta',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (access.trialActive) ...[
              Text(
                '30 días gratis activos',
                style: TextStyle(
                  color: appPrimaryColor(context),
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Inicio: ${_marketplaceDateTimeLabel(access.trialStartedAt)}',
              ),
              const SizedBox(height: 4),
              Text(
                'Finaliza: ${_marketplaceDateTimeLabel(access.trialEndsAt)}',
              ),
            ] else if (access.canStartTrial) ...[
              const Text(
                'Tu configuración ya permite comenzar el periodo gratuito.',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'La prueba empezará únicamente cuando pulses el botón. '
                'Hasta entonces no corre ningún día.',
                style: TextStyle(
                  color: appMutedColor(context),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _startingTrial ? null : _startTrial,
                  icon: const Icon(Icons.rocket_launch_outlined),
                  label: Text(
                    _startingTrial ? 'Activando...' : 'Comenzar 30 días gratis',
                  ),
                ),
              ),
            ] else if (access.trialStartedAt != null ||
                access.trialEndsAt != null) ...[
              const Text(
                'Periodo gratuito utilizado',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                'Finalizó: ${_marketplaceDateTimeLabel(access.trialEndsAt)}',
              ),
              const SizedBox(height: 6),
              Text(
                'El siguiente paso será verificar la billetera para continuar aceptando nuevos trabajos.',
                style: TextStyle(
                  color: appMutedColor(context),
                  height: 1.35,
                ),
              ),
            ] else if (!access.onboardingComplete)
              const Text(
                'Completa y guarda los datos obligatorios del conductor y del vehículo, incluida la foto principal.',
              )
            else if (!access.driverActive)
              const Text(
                'El perfil de conductor todavía no está activo para Trabajos.',
              )
            else if (!access.vehicleAvailable)
              const Text(
                'Este vehículo todavía no está disponible para Trabajos.',
              )
            else
              const Text(
                'La activación todavía no está disponible. Vuelve a consultar el estado.',
              ),
            if (access.canAcceptNewJob) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.work_history_outlined,
                    color: appPrimaryColor(context),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Ya puedes aceptar nuevos trabajos.',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final data = _data;

    if (data == null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GlassCard(
            child: Column(
              children: [
                const Icon(Icons.cloud_off_outlined, size: 42),
                const SizedBox(height: 12),
                Text(
                  _error ?? 'No se pudo cargar Trabajos.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final vehicle = _findVehicle(_selectedVehicleId);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Trabaja con TUKTUK',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Completa tus datos y los del vehículo que utilizarás para recibir solicitudes.',
          style: TextStyle(
            color: appMutedColor(context),
            height: 1.35,
          ),
        ),
        if (data.driverSuspended) ...[
          const SizedBox(height: 14),
          const GlassCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.block_rounded, color: kDanger),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tu perfil de conductor está suspendido. Puedes consultar la información, pero no modificarla.',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Datos del conductor',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _name,
                enabled: _canEdit,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nombre y apellidos',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phone,
                enabled: _canEdit,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'WhatsApp / teléfono',
                  hintText: '+5355555555',
                ),
              ),
              const SizedBox(height: 12),
              if (_driverPhotoBytes != null) ...[
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.memory(
                      _driverPhotoBytes!,
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  Icon(
                    _driverPhotoBytes == null && data.driverPhotoAssetId == null
                        ? Icons.photo_camera_outlined
                        : Icons.check_circle_outline,
                    color: _driverPhotoBytes == null &&
                            data.driverPhotoAssetId == null
                        ? kTertiary
                        : appPrimaryColor(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _driverPhotoBytes != null
                          ? 'Foto lista para guardar · ${_driverPhotoLabel ?? ''}'
                          : data.driverPhotoAssetId == null
                              ? 'Foto del conductor pendiente'
                              : 'Foto del conductor guardada',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _canEdit ? () => _pickPhoto('driver_photo') : null,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: Text(
                    data.driverPhotoAssetId == null && _driverPhotoBytes == null
                        ? 'Añadir foto'
                        : 'Cambiar foto',
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'La imagen se optimiza automáticamente a 720 × 720 antes de subirla.',
                style: TextStyle(
                  color: appMutedColor(context),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _canEdit ? _saveDriver : null,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(
                    _saving ? 'Guardando...' : 'Guardar conductor',
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Vehículo para Trabajos',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              if (data.vehicles.isEmpty)
                const Text(
                  'No encontramos vehículos sincronizados en tu cuenta. Primero debes tener un vehículo en TUKTUK Control.',
                )
              else ...[
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Vehículo',
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedVehicleId,
                      items: data.vehicles
                          .map(
                            (item) => DropdownMenuItem(
                              value: item.id,
                              child: Text(
                                item.name?.trim().isNotEmpty == true
                                    ? item.name!
                                    : item.id,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _canEdit
                          ? (value) {
                              setState(() {
                                _vehiclePhotoBytes = null;
                                _vehiclePhotoUploadKey = null;
                                _vehiclePhotoLabel = null;
                                _selectedVehicleId = value;
                                _loadVehicleFields(_findVehicle(value));
                              });

                              unawaited(_loadAccess());
                            }
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Categoría',
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _validCatalogValue(
                        _selectedCategory,
                        data.vehicleCategories,
                      ),
                      hint: const Text('Selecciona'),
                      items: data.vehicleCategories
                          .map(
                            (item) => DropdownMenuItem(
                              value: item.code,
                              child: Text(item.name),
                            ),
                          )
                          .toList(),
                      onChanged: _canEdit
                          ? (value) => setState(() => _selectedCategory = value)
                          : null,
                    ),
                  ),
                ),
                if (_selectedCategory == 'other') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _otherCategory,
                    enabled: _canEdit,
                    decoration: const InputDecoration(
                      labelText: 'Describe el tipo de vehículo',
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Propulsión',
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _validCatalogValue(
                        _selectedPropulsion,
                        data.propulsionTypes,
                      ),
                      hint: const Text('Selecciona'),
                      items: data.propulsionTypes
                          .map(
                            (item) => DropdownMenuItem(
                              value: item.code,
                              child: Text(item.name),
                            ),
                          )
                          .toList(),
                      onChanged: _canEdit
                          ? (value) =>
                              setState(() => _selectedPropulsion = value)
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _brand,
                  enabled: _canEdit,
                  decoration: const InputDecoration(labelText: 'Marca'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _model,
                  enabled: _canEdit,
                  decoration: const InputDecoration(labelText: 'Modelo'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _year,
                        enabled: _canEdit,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Año',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _passengers,
                        enabled: _canEdit,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Pasajeros',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _cargoKg,
                  enabled: _canEdit,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Carga máxima (kg)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _bodyType,
                  enabled: _canEdit,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de carrocería',
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Servicios que puedes realizar',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: data.serviceTypes
                      .map(
                        (service) => FilterChip(
                          label: Text(service.name),
                          selected: _selectedServices.contains(service.code),
                          onSelected: _canEdit
                              ? (selected) {
                                  setState(() {
                                    if (selected) {
                                      _selectedServices.add(service.code);
                                    } else {
                                      _selectedServices.remove(service.code);
                                    }
                                  });
                                }
                              : null,
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
                if (_vehiclePhotoBytes != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child: Image.memory(
                        _vehiclePhotoBytes!,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                Row(
                  children: [
                    Icon(
                      _vehiclePhotoBytes == null &&
                              vehicle?.mainPhotoAssetId == null
                          ? Icons.directions_car_outlined
                          : Icons.check_circle_outline,
                      color: _vehiclePhotoBytes == null &&
                              vehicle?.mainPhotoAssetId == null
                          ? kTertiary
                          : appPrimaryColor(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _vehiclePhotoBytes != null
                            ? 'Foto lista para guardar · ${_vehiclePhotoLabel ?? ''}'
                            : vehicle?.mainPhotoAssetId == null
                                ? 'Foto principal del vehículo pendiente'
                                : 'Foto principal del vehículo guardada',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _canEdit && vehicle != null
                        ? () => _pickPhoto('vehicle_photo')
                        : null,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(
                      vehicle?.mainPhotoAssetId == null &&
                              _vehiclePhotoBytes == null
                          ? 'Añadir foto del vehículo'
                          : 'Cambiar foto del vehículo',
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Se conserva la proporción y se reduce hasta un máximo de 1280 × 960 antes de subirla.',
                  style: TextStyle(
                    color: appMutedColor(context),
                    fontSize: 12,
                  ),
                ),
                if (vehicle?.mainPhotoAssetId == null &&
                    _vehiclePhotoBytes == null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'La foto principal será obligatoria para activar Trabajos.',
                    style: TextStyle(
                      color: appMutedColor(context),
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _canEdit ? _saveVehicle : null,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(
                      _saving ? 'Guardando...' : 'Guardar vehículo',
                    ),
                  ),
                ),
                if (vehicle?.onboardingComplete == true) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.verified_rounded,
                        color: appPrimaryColor(context),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Este vehículo ya cumple los requisitos de onboarding.',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildAccessCard(context, vehicle),
      ],
    );
  }
}
