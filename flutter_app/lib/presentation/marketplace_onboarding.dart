part of '../main.dart';

// Reuse the existing onboarding state and cards from the Trabajos section.
enum MarketplaceManagementSection { activation, wallet }

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

String _marketplaceMoneyLabel(double value, String currency) {
  final decimals = value == value.roundToDouble() ? 0 : 2;
  final pattern = decimals == 0 ? '#,##0' : '#,##0.00';
  final formatted = NumberFormat(pattern, 'es').format(value);
  return '$formatted $currency';
}

String _marketplacePercentLabel(double rate) {
  final percent = rate * 100;
  final decimals = percent == percent.roundToDouble() ? 0 : 2;
  return '${percent.toStringAsFixed(decimals)}%';
}

class MarketplaceOnboardingScreen extends StatefulWidget {
  const MarketplaceOnboardingScreen({
    required this.store,
    this.driverOnly = false,
    this.managementSection,
    this.initialVehicleId,
    this.onManagementChanged,
    super.key,
  });

  final RecordStore store;
  final bool driverOnly;
  final MarketplaceManagementSection? managementSection;
  final String? initialVehicleId;
  final VoidCallback? onManagementChanged;

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
  final _registration = TextEditingController();
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
  String? _googleAvatarAdoptionKey;

  Uint8List? _vehiclePhotoBytes;
  String? _vehiclePhotoUploadKey;
  String? _vehiclePhotoLabel;

  // Reuse authenticated downloads across rebuilds and vehicle selection.
  final Map<String, Future<Uint8List>> _savedPhotoFutures = {};

  MarketplaceWorkAccess? _access;
  bool _accessLoading = false;

  String? _accessError;

  String? _vehicleCreateKey;
  String? _vehicleCreateName;

  MarketplaceWallet? _wallet;
  bool _walletLoading = false;
  String? _walletError;

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
      !(_data?.driverSuspended ?? false);

  String? get _googleDriverPhotoUrl {
    final metadata = widget.store.user?.userMetadata;
    for (final key in const ['avatar_url', 'picture']) {
      final value = metadata?[key]?.toString().trim();
      if (value == null || value.isEmpty) continue;
      final uri = Uri.tryParse(value);
      if (uri == null || uri.scheme != 'https') continue;
      final host = uri.host.toLowerCase();
      if (host == 'googleusercontent.com' ||
          host.endsWith('.googleusercontent.com')) {
        return value;
      }
    }
    return null;
  }

  String _photoSaveError(Object error, {required bool vehicle}) {
    if (error is MarketplacePhotoException) return error.message;
    if (error is StorageException) {
      return vehicle
          ? 'No pudimos subir la foto del vehículo. La selección sigue lista para reintentar.'
          : 'No pudimos subir la foto del conductor. La selección sigue lista para reintentar.';
    }
    return vehicle
        ? 'No pudimos guardar el vehículo. Revisa los datos e inténtalo nuevamente.'
        : 'No pudimos guardar el perfil de conductor. Revisa los datos e inténtalo nuevamente.';
  }

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
    _registration.dispose();
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
          'registration': '',
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
          'services': ['passenger', 'cargo', 'courier', 'tourism'],
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
      'trial_active': true,
      'trial_started_at': now.toIso8601String(),
      'trial_ends_at': now.add(const Duration(days: 30)).toIso8601String(),
      'initial_deposit_confirmed': false,
      'suite_active': true,
      'can_start_trial': false,
      'can_accept_new_job': true,
      'next_billing_mode': 'trial_free',
    });
  }

  MarketplaceWallet _previewWallet() {
    final state = _marketplacePreviewState;

    return MarketplaceWallet.fromMap({
      'currency': 'CUP',
      'total_balance': state == 'trial' ? 150 : 0,
      'reserved_balance': 0,
      'available_balance': state == 'trial' ? 150 : 0,
      'initial_deposit_confirmed': false,
      'initial_deposit_confirmed_at': null,
      'initial_deposit_amount': null,
      'initial_minimum_snapshot': null,
      'current_initial_minimum_deposit': 500,
      'commission_rate': 0.10,
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

      if (!widget.driverOnly) await _loadAccess();
      if (widget.managementSection == MarketplaceManagementSection.wallet) {
        await _loadWallet();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No se pudo cargar tu configuración de Trabajos.';
      });
    }
  }

  void _applyData(MarketplaceOnboarding data, {String? preferredVehicleId}) {
    _name.text = data.displayName ?? widget.store.profileDisplayName;
    _phone.text = data.phone ?? '';

    final preferred = preferredVehicleId ??
        _selectedVehicleId ??
        widget.initialVehicleId ??
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

    _registration.text = vehicle?.registration ?? '';
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

  Future<void> _loadWallet({bool showSpinner = true}) async {
    if (_localPreview) {
      if (!mounted) return;

      setState(() {
        _wallet = _previewWallet();
        _walletLoading = false;
        _walletError = null;
      });

      return;
    }

    if (showSpinner) {
      setState(() {
        _walletLoading = true;
        _walletError = null;
      });
    }

    try {
      final wallet = await _service.wallet();

      if (!mounted) return;

      setState(() {
        _wallet = wallet;
        _walletLoading = false;
        _walletError = null;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _wallet = null;
        _walletLoading = false;
        _walletError = 'No se pudo consultar tu billetera Marketplace.';
      });
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

    XFile? picked;
    try {
      picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 92,
      );
    } catch (_) {
      if (mounted) {
        final origin =
            source == ImageSource.camera ? 'la cámara' : 'la galería';
        toast(context, 'No pudimos abrir $origin. Inténtalo nuevamente.');
      }
      if (mounted) setState(() => _processingPhoto = false);
      return;
    }

    if (picked == null) {
      if (mounted) setState(() => _processingPhoto = false);
      return;
    }

    try {
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
          _googleAvatarAdoptionKey = null;
        } else if (assetKind == 'vehicle_photo') {
          _vehiclePhotoBytes = normalized.bytes;
          _vehiclePhotoUploadKey = _marketplaceUuidV4();
          _vehiclePhotoLabel = label;
        }
      });

      toast(
        context,
        assetKind == 'vehicle_photo'
            ? 'Foto seleccionada. Se subirá al pulsar Guardar vehículo.'
            : 'Foto seleccionada. Se subirá al pulsar Guardar conductor.',
      );
    } on FormatException catch (error) {
      if (mounted) {
        toast(context, error.message.toString());
      }
    } catch (_) {
      if (mounted) {
        toast(context, 'No pudimos procesar esa imagen. Prueba con otra foto.');
      }
    } finally {
      if (mounted) setState(() => _processingPhoto = false);
    }
  }

  Future<Uint8List>? _savedMarketplacePhoto(String? assetId) {
    final data = _data;
    if (assetId == null || data == null) return null;

    for (final asset in data.assets) {
      if (asset.id != assetId) continue;
      if (!asset.isAvailable ||
          asset.storageBucket == null ||
          asset.storagePath == null) {
        return null;
      }
      return _savedPhotoFutures.putIfAbsent(
        asset.id,
        () => Supabase.instance.client.storage
            .from(asset.storageBucket!)
            .download(asset.storagePath!),
      );
    }
    return null;
  }

  Widget _buildMarketplacePhotoPreview({
    required Uint8List? pendingBytes,
    required String? savedAssetId,
    required bool vehicle,
    String? fallbackNetworkUrl,
  }) {
    Widget image(Uint8List bytes) => ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: vehicle
              ? SizedBox(
                  height: 255,
                  width: double.infinity,
                  child: Image.memory(bytes, fit: BoxFit.contain),
                )
              : Image.memory(bytes, width: 120, height: 120, fit: BoxFit.cover),
        );

    // Manual selection has first priority.
    if (pendingBytes != null) return image(pendingBytes);

    // A private Marketplace asset has priority over the Google fallback.
    final savedPhoto = _savedMarketplacePhoto(savedAssetId);
    if (savedPhoto != null) {
      return FutureBuilder<Uint8List>(
        future: savedPhoto,
        builder: (context, snapshot) {
          if (snapshot.hasData) return image(snapshot.data!);
          if (snapshot.hasError) {
            return const Text(
              'No se pudo mostrar la foto guardada. Puedes cambiarla.',
            );
          }
          return const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          );
        },
      );
    }

    // Google is a driver-only fallback. Vehicle photos never use it.
    if (!vehicle && fallbackNetworkUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox.square(
          dimension: 120,
          child: Image.network(
            fallbackNetworkUrl,
            fit: BoxFit.cover,
            webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
            errorBuilder: (context, error, stackTrace) => const Center(
              child: Icon(Icons.person_outline_rounded, size: 42),
            ),
          ),
        ),
      );
    }

    return Text(
      vehicle
          ? 'Añade una foto principal del vehículo.'
          : 'Añade una foto clara del conductor.',
    );
  }

  Future<void> _saveDriver() async {
    final data = _data;
    if (data == null || !_canEdit) return;

    final name = _name.text.trim();
    final phone = _phone.text.trim();

    if (name.isEmpty) {
      toast(context, 'Escribe tu nombre. La foto seleccionada no se perderá.');
      return;
    }

    if (!RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(phone)) {
      toast(
        context,
        'Usa el teléfono con código de país. Ejemplo: +5355555555. La foto seleccionada no se perderá.',
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
      } else if (photoAssetId == null && _googleDriverPhotoUrl != null) {
        final adoptionKey =
            _googleAvatarAdoptionKey ?? _marketplaceUuidV4();
        _googleAvatarAdoptionKey = adoptionKey;

        final adopted = await _service.adoptGoogleAvatar(
          idempotencyKey: adoptionKey,
        );
        photoAssetId = adopted.id;
      }

      if (photoAssetId == null) {
        throw const MarketplacePhotoException(
          'Añade una foto del conductor para completar el perfil.',
        );
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
        _googleAvatarAdoptionKey = null;
        _data = updated;
        _applyData(updated, preferredVehicleId: _selectedVehicleId);
      });

      _updateMarketplaceDriverProfileNeedsSetup(updated);
      widget.onManagementChanged?.call();
      if (!widget.driverOnly) await _loadAccess(showSpinner: false);

      if (!mounted) return;
      toast(context, 'Perfil de conductor y foto guardados.');
    } catch (error) {
      if (mounted) {
        toast(context, _photoSaveError(error, vehicle: false));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _createVehicle() async {
    if (!_canEdit || _data == null) return;

    // El usuario no necesita inventar un nombre para el vehículo.
    // El borrador usa un nombre técnico temporal y al guardar se reemplaza
    // automáticamente por Marca + Modelo.
    const draftName = 'Vehículo nuevo';
    final name = _vehicleCreateName ?? draftName;
    final key = _vehicleCreateKey ?? _marketplaceUuidV4();
    _vehicleCreateKey = key;
    _vehicleCreateName = name;

    setState(() => _saving = true);
    try {
      final result = await _service.createVehicle(
        name: name,
        idempotencyKey: key,
      );
      final newVehicleId = _marketText(result['created_vehicle_id']);
      if (newVehicleId == null) {
        throw const FormatException(
          'El servidor no devolvió el vehículo creado.',
        );
      }
      final updated = MarketplaceOnboarding.fromMap(result);
      if (!updated.vehicles.any((v) => v.id == newVehicleId)) {
        throw const FormatException(
          'No se encontró el vehículo en el onboarding.',
        );
      }
      if (!mounted) return;
      setState(() {
        _vehicleCreateKey = null;
        _vehicleCreateName = null;
        _vehiclePhotoBytes = null;
        _vehiclePhotoUploadKey = null;
        _vehiclePhotoLabel = null;
        _data = updated;
        _applyData(updated, preferredVehicleId: newVehicleId);
      });
      await _loadAccess(showSpinner: false);
      if (mounted) {
        toast(context, 'Vehículo añadido. Completa sus datos y añade la foto.');
      }
    } catch (_) {
      if (mounted) {
        toast(
          context,
          'No se pudo confirmar el alta. Pulsa Añadir vehículo para reintentar sin duplicarlo.',
        );
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

    final brand = _brand.text.trim();
    final model = _model.text.trim();
    final registration = _registration.text.trim();

    if (brand.isEmpty) {
      toast(context, 'Escribe la marca del vehículo.');
      return;
    }
    if (model.isEmpty) {
      toast(context, 'Escribe el modelo del vehículo.');
      return;
    }

    final vehicleName = '$brand $model'.trim();
    if (vehicleName.length > 80) {
      toast(context, 'Marca y modelo juntos no pueden superar 80 caracteres.');
      return;
    }
    if (registration.length > 32) {
      toast(context, 'La chapa no puede superar 32 caracteres.');
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

      // One server-side transaction saves onboarding plus name/chapa and
      // updates legacy synchronization when the selected vehicle has a sync row.
      // The new RPC must be installed and audited BEFORE publishing this UI.
      final response = await Supabase.instance.client.rpc(
        'save_my_marketplace_vehicle_profile',
        params: {
          'target_vehicle_id': vehicle.id,
          'target_category_code': category,
          'target_propulsion_code': propulsion,
          'target_category_other_description':
              category == 'other' ? _otherCategory.text.trim() : null,
          'target_brand': brand,
          'target_model': model,
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
          'target_vehicle_name': vehicleName,
          'target_registration': registration.isEmpty ? null : registration,
        },
      );
      if (response is! Map) {
        throw const FormatException('Respuesta de vehículo no válida.');
      }
      final updated = MarketplaceOnboarding.fromMap(response);

      if (!mounted) return;

      setState(() {
        _vehiclePhotoBytes = null;
        _vehiclePhotoUploadKey = null;
        _vehiclePhotoLabel = null;
        _data = updated;
        _applyData(updated, preferredVehicleId: vehicle.id);
      });

      _updateMarketplaceDriverProfileNeedsSetup(updated);
      await _loadAccess(showSpinner: false);

      if (!mounted) return;
      toast(context, 'Vehículo guardado.');
      widget.onManagementChanged?.call();
    } catch (error) {
      if (mounted) {
        toast(context, _photoSaveError(error, vehicle: true));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildAccessCard(BuildContext context, MarketplaceVehicle? vehicle) {
    final access = _access;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Activación de Trabajos',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          if (vehicle == null)
            const Text('Selecciona y configura un vehículo para continuar.')
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
                'Promoción inicial activa',
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
              const SizedBox(height: 6),
              Text(
                'Durante esta promoción no se cobra comisión por los trabajos aceptados.',
                style: TextStyle(color: appMutedColor(context), height: 1.35),
              ),
            ] else if (access.trialStartedAt != null ||
                access.trialEndsAt != null) ...[
              const Text(
                'Promoción inicial finalizada',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                'Finalizó: ${_marketplaceDateTimeLabel(access.trialEndsAt)}',
              ),
              const SizedBox(height: 6),
              Text(
                'Las nuevas aceptaciones usan la billetera y requieren saldo disponible suficiente para cubrir la comisión.',
                style: TextStyle(color: appMutedColor(context), height: 1.35),
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
                'Alta operativa completa. La promoción inicial se activa automáticamente al completar los requisitos. Actualiza el estado si acabas de guardar tus datos.',
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
                  Expanded(
                    child: Text(
                      access.nextBillingMode == MarketplaceBillingMode.trialFree
                          ? 'Ya puedes aceptar trabajos sin comisión durante la promoción inicial.'
                          : 'Trabajos habilitados. Para aceptar uno necesitas saldo disponible suficiente para la comisión.',
                      style: const TextStyle(fontWeight: FontWeight.w800),
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

  Widget _buildWalletCard(BuildContext context) {
    final wallet = _wallet;
    final access = _access;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Billetera Marketplace',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'La billetera se usa para cubrir las comisiones de Trabajos cuando '
            'la promoción inicial ya terminó. Control y Estadísticas siguen '
            'disponibles independientemente de este saldo.',
            style: TextStyle(color: appMutedColor(context), height: 1.35),
          ),
          const SizedBox(height: 14),
          if (_walletLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_walletError != null) ...[
            Text(_walletError!),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _loadWallet,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ] else if (wallet == null)
            const Text('No hay información de billetera disponible.')
          else ...[
            Row(
              children: [
                Expanded(
                  child: _walletValue(
                    context,
                    'Saldo total',
                    _marketplaceMoneyLabel(
                      wallet.totalBalance,
                      wallet.currency,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _walletValue(
                    context,
                    'Disponible',
                    _marketplaceMoneyLabel(
                      wallet.availableBalance,
                      wallet.currency,
                    ),
                    emphasize: true,
                  ),
                ),
              ],
            ),
            if (wallet.realBalance != null &&
                wallet.promotionalBalance != null &&
                wallet.realAvailableBalance != null &&
                wallet.promotionalAvailableBalance != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _walletValue(
                      context,
                      'Saldo real',
                      _marketplaceMoneyLabel(
                        wallet.realBalance!,
                        wallet.currency,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _walletValue(
                      context,
                      'Promocional',
                      _marketplaceMoneyLabel(
                        wallet.promotionalBalance!,
                        wallet.currency,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _walletValue(
                      context,
                      'Real disponible',
                      _marketplaceMoneyLabel(
                        wallet.realAvailableBalance!,
                        wallet.currency,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _walletValue(
                      context,
                      'Promo disponible',
                      _marketplaceMoneyLabel(
                        wallet.promotionalAvailableBalance!,
                        wallet.currency,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'El saldo real y el saldo promocional pueden cubrir comisiones. '
                'El saldo promocional no es retirable como efectivo.',
              ),
            ],
            const SizedBox(height: 10),
            _walletValue(
              context,
              'Reservado para trabajos',
              _marketplaceMoneyLabel(wallet.reservedBalance, wallet.currency),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.percent_rounded),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Comisión estándar: '
                    '${_marketplacePercentLabel(wallet.commissionRate)}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (access?.trialActive == true) ...[
              Text(
                'Durante la promoción inicial no se reserva ni se descuenta '
                'comisión. Puedes tener saldo en la billetera sin perder '
                'la promoción.',
                style: TextStyle(color: appMutedColor(context), height: 1.35),
              ),
            ] else ...[
              Text(
                'Fuera de la promoción inicial no existe un depósito mínimo. '
                'Las nuevas aceptaciones solo requieren saldo disponible '
                'suficiente para cubrir la comisión correspondiente.',
                style: TextStyle(color: appMutedColor(context), height: 1.35),
              ),
            ],
            const SizedBox(height: 14),
            Text(
              'El saldo real y el saldo promocional pueden utilizarse para '
              'cubrir comisiones. Una recarga no inicia, reinicia ni amplía '
              'la promoción.',
              style: TextStyle(
                color: appMutedColor(context),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _walletValue(
    BuildContext context,
    String label,
    String value, {
    bool emphasize = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: appMutedColor(context).withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: appMutedColor(context), fontSize: 12),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              fontSize: emphasize ? 18 : 16,
              fontWeight: FontWeight.w900,
            ),
          ),
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

    // Management views reuse the exact access/wallet cards and callbacks.
    // The normal onboarding route contains registration fields only.
    if (!widget.driverOnly && widget.managementSection != null) {
      final vehicleLabel = vehicle?.name?.trim().isNotEmpty == true
          ? vehicle!.name!
          : vehicle?.id;
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.managementSection ==
              MarketplaceManagementSection.activation) ...[
            if (vehicle != null) ...[
              Text(
                'Vehículo: $vehicleLabel',
                style: TextStyle(color: appMutedColor(context)),
              ),
              const SizedBox(height: 12),
            ],
            _buildAccessCard(context, vehicle),
          ] else
            _buildWalletCard(context),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 120),
      children: [
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
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              // Keep the portrait beside the two fields on wider screens.
              // On narrow phones, stack it to prevent clipped inputs.
              LayoutBuilder(
                builder: (context, constraints) {
                  final compactDriverFields = Column(
                    children: [
                      TextField(
                        controller: _name,
                        enabled: _canEdit,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Nombre y apellidos',
                          isDense: true,
                          prefixIcon: Icon(
                            Icons.person_outline_rounded,
                            size: 22,
                          ),
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
                          isDense: true,
                          prefixIcon: Icon(Icons.phone_outlined, size: 22),
                        ),
                      ),
                    ],
                  );
                  final hasDriverPhoto = _driverPhotoBytes != null ||
                      data.driverPhotoAssetId != null ||
                      _googleDriverPhotoUrl != null;
                  if (!hasDriverPhoto) return compactDriverFields;

                  final photo = _buildMarketplacePhotoPreview(
                    pendingBytes: _driverPhotoBytes,
                    savedAssetId: data.driverPhotoAssetId,
                    vehicle: false,
                    fallbackNetworkUrl: _googleDriverPhotoUrl,
                  );
                  if (constraints.maxWidth < 290) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        compactDriverFields,
                        const SizedBox(height: 12),
                        photo,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: compactDriverFields),
                      const SizedBox(width: 8),
                      SizedBox(width: 94, height: 104, child: photo),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    _driverPhotoBytes == null &&
                            data.driverPhotoAssetId == null &&
                            _googleDriverPhotoUrl == null
                        ? Icons.photo_camera_outlined
                        : Icons.check_circle_outline,
                    color: _driverPhotoBytes == null &&
                            data.driverPhotoAssetId == null &&
                            _googleDriverPhotoUrl == null
                        ? kTertiary
                        : appPrimaryColor(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _driverPhotoBytes != null
                          ? 'Foto seleccionada. Se subirá al pulsar Guardar conductor. ${_driverPhotoLabel ?? ''}'
                          : data.driverPhotoAssetId != null
                              ? 'Foto del conductor guardada'
                              : _googleDriverPhotoUrl != null
                                  ? 'Usaremos tu foto de Google como foto inicial. Puedes cambiarla.'
                                  : 'Foto del conductor pendiente',
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
                    data.driverPhotoAssetId == null &&
                            _driverPhotoBytes == null &&
                            _googleDriverPhotoUrl == null
                        ? 'Añadir foto'
                        : 'Cambiar foto',
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _googleDriverPhotoUrl != null &&
                        data.driverPhotoAssetId == null &&
                        _driverPhotoBytes == null
                    ? 'Al guardar, TUKTUK copiará tu foto de Google a tu perfil privado de conductor.'
                    : 'Elige una foto clara donde se vea bien tu rostro. TUKTUK la ajusta automáticamente.',
                style: TextStyle(color: appMutedColor(context), fontSize: 12),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _canEdit ? _saveDriver : null,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'Guardando...' : 'Guardar conductor'),
                ),
              ),
            ],
          ),
        ),
        if (!widget.driverOnly) const SizedBox(height: 16),
        if (!widget.driverOnly)
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Vehículo para Trabajos',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _canEdit ? _createVehicle : null,
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Añadir vehículo'),
                  ),
                ),
                const SizedBox(height: 12),
                if (data.vehicles.isEmpty)
                  const Text(
                    'Todavía no tienes vehículos. Pulsa Añadir vehículo y luego completa sus datos y fotografías.',
                  )
                else ...[
                  // TUKTUK_BALANCED_VEHICLE_LAYOUT_V4
                  LayoutBuilder(
                    builder: (context, constraints) {
                      const gap = 4.0;
                      const horizontalGap = 6.0;
                      const fieldHeight = 48.0;
                      final showColumns = constraints.maxWidth >= 290;

                      InputDecoration fieldDecoration(
                        String label,
                        IconData icon,
                      ) {
                        return InputDecoration(
                          labelText: label,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          constraints: const BoxConstraints(
                            minHeight: fieldHeight,
                          ),
                          prefixIcon: Icon(icon, size: 19),
                          prefixIconConstraints: const BoxConstraints(
                            minWidth: 38,
                            minHeight: 38,
                          ),
                        );
                      }

                      Widget field(Widget child) =>
                          SizedBox(height: fieldHeight, child: child);

                      Widget pair(Widget left, Widget right) {
                        if (!showColumns) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              left,
                              const SizedBox(height: gap),
                              right,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: left),
                            const SizedBox(width: horizontalGap),
                            Expanded(child: right),
                          ],
                        );
                      }

                      Widget selector({
                        required String label,
                        required IconData icon,
                        required String? value,
                        required List<DropdownMenuItem<String>> items,
                        required ValueChanged<String?>? onChanged,
                      }) {
                        return field(
                          InputDecorator(
                            decoration: fieldDecoration(label, icon),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                isDense: true,
                                value: value,
                                hint: const Text('Selecciona'),
                                items: items,
                                onChanged: onChanged,
                              ),
                            ),
                          ),
                        );
                      }

                      Widget edit({
                        required String label,
                        required IconData icon,
                        required TextEditingController controller,
                        TextInputType? keyboardType,
                        int? maxLength,
                      }) {
                        return field(
                          TextField(
                            controller: controller,
                            enabled: _canEdit,
                            keyboardType: keyboardType,
                            maxLength: maxLength,
                            decoration: fieldDecoration(label, icon).copyWith(
                              counterText: maxLength == null ? null : '',
                            ),
                          ),
                        );
                      }

                      final serviceChips = Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: data.serviceTypes.map((service) {
                          return FilterChip(
                            label: Text(service.name),
                            visualDensity: VisualDensity.compact,
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
                          );
                        }).toList(),
                      );

                      final services = Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.work_outline, size: 18),
                                SizedBox(width: 7),
                                Expanded(
                                  child: Text(
                                    'Servicios que puedes realizar',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            serviceChips,
                          ],
                        ),
                      );

                      final showPassengerCapacity =
                          _selectedServices.contains('passenger') ||
                          _selectedServices.contains('tourism');
                      final showCargoCapacity =
                          _selectedServices.contains('cargo');

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          pair(
                            selector(
                              label: 'Vehículo',
                              icon: Icons.directions_car_outlined,
                              value: _selectedVehicleId,
                              items: data.vehicles.map((item) {
                                return DropdownMenuItem<String>(
                                  value: item.id,
                                  child: Text(
                                    [
                                      if (item.brand?.trim().isNotEmpty == true)
                                        item.brand!.trim(),
                                      if (item.model?.trim().isNotEmpty == true)
                                        item.model!.trim(),
                                    ].join(' ').trim().isNotEmpty
                                        ? [
                                            if (item.brand?.trim().isNotEmpty ==
                                                true)
                                              item.brand!.trim(),
                                            if (item.model?.trim().isNotEmpty ==
                                                true)
                                              item.model!.trim(),
                                          ].join(' ')
                                        : 'Vehículo sin completar',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
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
                            selector(
                              label: 'Categoría',
                              icon: Icons.category_outlined,
                              value: _validCatalogValue(
                                _selectedCategory,
                                data.vehicleCategories,
                              ),
                              items: data.vehicleCategories.map((item) {
                                return DropdownMenuItem<String>(
                                  value: item.code,
                                  child: Text(item.name),
                                );
                              }).toList(),
                              onChanged: _canEdit
                                  ? (value) => setState(
                                        () => _selectedCategory = value,
                                      )
                                  : null,
                            ),
                          ),
                          if (_selectedCategory == 'other') ...[
                            const SizedBox(height: gap),
                            edit(
                              label: 'Describe el tipo de vehículo',
                              icon: Icons.edit_outlined,
                              controller: _otherCategory,
                            ),
                          ],
                          const SizedBox(height: gap),
                          pair(
                            edit(
                              label: 'Marca',
                              icon: Icons.sell_outlined,
                              controller: _brand,
                            ),
                            edit(
                              label: 'Modelo',
                              icon: Icons.info_outline,
                              controller: _model,
                            ),
                          ),
                          const SizedBox(height: gap),
                          selector(
                            label: 'Propulsión',
                            icon: Icons.bolt_outlined,
                            value: _validCatalogValue(
                              _selectedPropulsion,
                              data.propulsionTypes,
                            ),
                            items: data.propulsionTypes.map((item) {
                              return DropdownMenuItem<String>(
                                value: item.code,
                                child: Text(item.name),
                              );
                            }).toList(),
                            onChanged: _canEdit
                                ? (value) => setState(
                                      () => _selectedPropulsion = value,
                                    )
                                : null,
                          ),
                          const SizedBox(height: gap),
                          services,
                          if (showPassengerCapacity ||
                              showCargoCapacity) ...[
                            const SizedBox(height: gap),
                            if (showPassengerCapacity && showCargoCapacity)
                              pair(
                                edit(
                                  label: 'Pasajeros',
                                  icon: Icons.people_outline,
                                  controller: _passengers,
                                  keyboardType: TextInputType.number,
                                ),
                                edit(
                                  label: 'Carga (kg)',
                                  icon: Icons.scale_outlined,
                                  controller: _cargoKg,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                ),
                              )
                            else if (showPassengerCapacity)
                              edit(
                                label: 'Pasajeros',
                                icon: Icons.people_outline,
                                controller: _passengers,
                                keyboardType: TextInputType.number,
                              )
                            else
                              edit(
                                label: 'Carga (kg)',
                                icon: Icons.scale_outlined,
                                controller: _cargoKg,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                              ),
                          ],
                          const SizedBox(height: 4),
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            childrenPadding: const EdgeInsets.only(bottom: 4),
                            title: const Text(
                              'Más datos del vehículo (opcional)',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: const Text('Chapa, año y carrocería'),
                            children: [
                              pair(
                                edit(
                                  label: 'Chapa (opcional)',
                                  icon: Icons.credit_card_outlined,
                                  controller: _registration,
                                  maxLength: 32,
                                ),
                                edit(
                                  label: 'Año',
                                  icon: Icons.calendar_today_outlined,
                                  controller: _year,
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(height: gap),
                              edit(
                                label: 'Tipo de carrocería',
                                icon: Icons.widgets_outlined,
                                controller: _bodyType,
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                  if (_vehiclePhotoBytes != null ||
                      vehicle?.mainPhotoAssetId != null) ...[
                    _buildMarketplacePhotoPreview(
                      pendingBytes: _vehiclePhotoBytes,
                      savedAssetId: vehicle?.mainPhotoAssetId,
                      vehicle: true,
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
                              ? 'Foto seleccionada. Se subirá al pulsar Guardar vehículo. ${_vehiclePhotoLabel ?? ''}'
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
                    'Elige una foto donde se vea claramente tu vehículo. TUKTUK la ajusta automáticamente.',
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
      ],
    );
  }
}
