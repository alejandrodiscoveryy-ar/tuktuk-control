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

  bool _loading = true;
  bool _saving = false;
  bool _processingPhoto = false;
  String? _error;

  bool get _canEdit =>
      !_saving && !_processingPhoto && !(_data?.driverSuspended ?? false);

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

  Future<void> _load() async {
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

      toast(context, 'Vehículo guardado.');
    } catch (_) {
      if (mounted) {
        toast(context, 'No se pudo guardar la configuración del vehículo.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
      ],
    );
  }
}
