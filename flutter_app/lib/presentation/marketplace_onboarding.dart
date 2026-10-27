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

String marketplaceTopupStatusLabel(String status) => switch (status) {
      'requested' => 'Pendiente',
      'confirmed' || 'reconciled' => 'Confirmada',
      'rejected' => 'Rechazada',
      _ => 'Estado no disponible',
    };

String marketplaceTopupErrorMessage(Object error) {
  final code = error is PostgrestException ? error.message : '';
  return switch (code) {
    'TOPUP_AMOUNT_MUST_BE_POSITIVE' => 'Introduce un importe mayor que cero.',
    'INVALID_TOPUP_METHOD' =>
      'Ese método de pago ya no está disponible. Actualiza e inténtalo nuevamente.',
    'TOPUP_REFERENCE_REQUIRED' =>
      'Debes indicar la referencia de esta operación.',
    'AUTHENTICATION_REQUIRED' =>
      'Tu sesión venció. Inicia sesión nuevamente para solicitar una recarga.',
    'PROFILE_NOT_FOUND' =>
      'Tu perfil no está disponible. Revisa tu perfil e inténtalo nuevamente.',
    _ => 'No pudimos enviar la solicitud de recarga. Inténtalo nuevamente.',
  };
}

class MarketplaceTopupHistory extends StatelessWidget {
  const MarketplaceTopupHistory({required this.topups, super.key});
  final List<MarketplaceTopup> topups;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (topups.isEmpty) const Text('Aún no tienes recargas.'),
          for (final topup in topups)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _marketplaceMoneyLabel(topup.amount, topup.currency),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(topup.methodName ?? 'Método no disponible'),
                  Text(_marketplaceDateTimeLabel(topup.requestedAt)),
                  if (topup.reference != null)
                    Text('Referencia: ${topup.reference}'),
                  Text(marketplaceTopupStatusLabel(topup.status)),
                  if (topup.status == 'rejected' &&
                      topup.rejectionReason != null)
                    Text('Motivo: ${topup.rejectionReason}'),
                ],
              ),
            ),
        ],
      );
}

class MarketplaceTopupForm extends StatefulWidget {
  const MarketplaceTopupForm({
    required this.service,
    this.requestKeys,
    super.key,
  });

  final MarketplaceService service;
  // The wallet keeps uncertain submissions in memory across modal reopenings.
  // Nothing is queued offline or persisted to Hive.
  final Map<String, String>? requestKeys;

  @override
  State<MarketplaceTopupForm> createState() => _MarketplaceTopupFormState();
}

class _MarketplaceTopupFormState extends State<MarketplaceTopupForm> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  late final Map<String, String> _requestKeys = widget.requestKeys ?? {};
  List<MarketplacePaymentMethod> _methods = const [];
  MarketplacePaymentMethod? _method;
  bool _loading = true;
  bool _sending = false;
  String? _loadError;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadMethods());
  }

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  Future<void> _loadMethods() async {
    setState(() {
      _loading = true;
      _loadError = null;
      _method = null;
    });
    try {
      final methods = await widget.service.paymentMethods();
      if (!mounted) return;
      setState(() => _methods = methods);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _loadError =
            'No pudimos cargar los métodos de pago. Revisa tu conexión y actualiza.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (_sending || _loading || !_form.currentState!.validate()) return;
    final amount = _marketplaceOptionalNumber(_amount.text)!;
    final method = _method!;
    final reference = method.requiresReference ? _reference.text.trim() : null;
    final fingerprint = jsonEncode([amount, method.code, reference]);
    final key = _requestKeys.putIfAbsent(fingerprint, _marketplaceUuidV4);
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.service.requestTopup(
        amount: amount,
        method: method.code,
        reference: reference,
        idempotencyKey: key,
      );
      _requestKeys.remove(fingerprint);
      if (!mounted) return;
      setState(() => _sending = false);
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = marketplaceTopupErrorMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_sending,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Recargar saldo',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amount,
                  enabled: !_sending,
                  decoration:
                      const InputDecoration(labelText: 'Importe en CUP'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    final amount = _marketplaceOptionalNumber(value ?? '');
                    return amount == null || !amount.isFinite || amount <= 0
                        ? 'Introduce un importe mayor que cero.'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                if (_loading)
                  const LinearProgressIndicator()
                else if (_loadError != null)
                  Text(_loadError!)
                else if (_methods.isEmpty)
                  const Text('No hay métodos de pago disponibles.')
                else
                  DropdownButtonFormField<MarketplacePaymentMethod>(
                    key: ValueKey(_methods),
                    initialValue: _method,
                    isExpanded: true,
                    decoration:
                        const InputDecoration(labelText: 'Método de pago'),
                    items: _methods
                        .map(
                          (method) => DropdownMenuItem(
                            value: method,
                            child: Text(method.name),
                          ),
                        )
                        .toList(),
                    onChanged: _sending
                        ? null
                        : (value) => setState(() => _method = value),
                    validator: (value) =>
                        value == null ? 'Selecciona un método de pago.' : null,
                  ),
                TextButton.icon(
                  onPressed: _loading || _sending ? null : _loadMethods,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Actualizar métodos'),
                ),
                if (_method?.requiresReference == true)
                  TextFormField(
                    controller: _reference,
                    enabled: !_sending,
                    decoration: const InputDecoration(labelText: 'Referencia'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Debes indicar la referencia de esta operación.'
                        : null,
                  ),
                const SizedBox(height: 16),
                const Text(
                  'La solicitud quedará pendiente hasta que sea confirmada. El saldo de tu billetera no cambia hasta esa confirmación.',
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _sending ||
                          _loading ||
                          _loadError != null ||
                          _methods.isEmpty
                      ? null
                      : _submit,
                  child: Text(_sending ? 'Enviando…' : 'Solicitar recarga'),
                ),
                TextButton(
                  onPressed:
                      _sending ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
              ],
            ),
          ),
        ),
      );
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

  final Map<String, Uint8List> _identityPending = {};
  final Map<String, String> _identityUploadKeys = {};
  Map<String, dynamic> _identityDocs = {};
  bool _identityLoaded = false;
  bool _identityRequired = false;
  String? _identityDocumentType;
  final Map<String, String?> _identitySavedPhotoIds = {};
  String? _identityError;

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
  List<MarketplaceTopup> _topups = const [];
  bool _topupsLoading = false;
  String? _topupsError;
  bool _topupFormOpen = false;
  final Map<String, String> _topupRequestKeys = {};

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

  int _registrationStep = 0;
  final ScrollController _registrationScroll = ScrollController();
  bool _showFieldErrors = false;
  bool _registrationSubmitting = false;
  bool _registrationSaved = false;
  bool _driverSaveSucceeded = false;
  bool _vehicleSaveSucceeded = false;

  // Borradores: cada campo válido se confirma en servidor por separado.
  // Nunca se guardan bytes del carnet ni fotografías en almacenamiento local.
  Map<String, dynamic> _registrationDrafts = {};
  final Map<String, ({String field, String? vehicleId, Object value})>
      _draftPending = {};
  Timer? _draftTimer;
  bool _draftHydrating = true;
  bool _draftBusy = false;
  String? _draftError;

  Map<String, dynamic> get _driverDraft {
    final raw = _registrationDrafts['driver'];
    return raw is Map ? Map<String, dynamic>.from(raw) : {};
  }

  Map<String, dynamic> _vehicleDraft(String? vehicleId) {
    final raw = _registrationDrafts['vehicle:$vehicleId'];
    return raw is Map ? Map<String, dynamic>.from(raw) : {};
  }

  String? get _draftDriverPhotoId => _driverDraft['driver_photo_id']?.toString();
  String? get _draftVehiclePhotoId =>
      _vehicleDraft(_selectedVehicleId)['vehicle_photo_id']?.toString();

  bool _validDraftField(String field, Object value) {
    if (value is List<String>) return field == 'services';
    if (value is! String) return false;
    final text = value.trim();
    if (field == 'identity_document_type') {
      return text == 'national_id' || text == 'driver_license';
    }
    if (field == 'name') return text.length >= 2 && text.length <= 100;
    if (field == 'phone') return RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(text);
    if (field == 'brand' || field == 'model') return text.isNotEmpty && text.length <= 80;
    if (field == 'category' || field == 'propulsion') return text.isNotEmpty;
    if (field == 'year') {
      if (text.isEmpty) return true;
      final year = int.tryParse(text);
      return year != null && year >= 1900 && year <= 2200;
    }
    if (field == 'passengers') {
      if (text.isEmpty) return true;
      final count = int.tryParse(text);
      return count != null && count >= 1 && count <= 100;
    }
    if (field == 'cargo_kg') {
      if (text.isEmpty) return true;
      final count = double.tryParse(text.replaceAll(',', '.'));
      return count != null && count >= 0 && count <= 100000;
    }
    return text.length <= (field == 'registration' ? 32 : 160);
  }

  void _queueDraftField(String field, Object value, {String? vehicleId}) {
    if (_draftHydrating || !_canEdit || _data == null ||
        (field != 'name' && field != 'phone' && vehicleId == null &&
         !field.contains('photo') && !field.startsWith('identity_')) ||
        !_validDraftField(field, value)) {
      return;
    }
    final key = '${vehicleId ?? 'driver'}:$field';
    final normalized = field == 'cargo_kg' && value is String
        ? value.replaceAll(',', '.') : value;
    _draftPending[key] = (field: field, vehicleId: vehicleId, value: normalized);
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 700), () {
      unawaited(_flushDraftFields());
    });
    if (mounted) setState(() => _draftError = null);
  }

  Future<void> _flushDraftFields() async {
    _draftTimer?.cancel();
    if (_draftBusy || _draftPending.isEmpty) return;
    final batch = Map.of(_draftPending);
    _draftPending.clear();
    if (mounted) setState(() { _draftBusy = true; _draftError = null; });
    var failed = false;
    try {
      for (final entry in batch.entries) {
        await _service.saveRegistrationDraftField(
          field: entry.value.field,
          value: entry.value.value,
          vehicleId: entry.value.vehicleId,
        );
        final scope = entry.value.vehicleId == null
            ? 'driver' : 'vehicle:${entry.value.vehicleId}';
        final current = _registrationDrafts[scope];
        final fields = current is Map ? Map<String, dynamic>.from(current) : <String, dynamic>{};
        fields[entry.value.field] = entry.value.value;
        _registrationDrafts[scope] = fields;
      }
    } catch (_) {
      failed = true;
      // Los cambios hechos mientras se enviaba el lote tienen prioridad.
      for (final entry in batch.entries) {
        _draftPending.putIfAbsent(entry.key, () => entry.value);
      }
      if (mounted) _draftError = 'Hay datos pendientes de guardar. Comprueba tu conexión y reintenta.';
    } finally {
      if (mounted) setState(() => _draftBusy = false);
      if (!failed && _draftPending.isNotEmpty) {
        if (mounted) {
          _draftTimer = Timer(const Duration(milliseconds: 700), () {
            unawaited(_flushDraftFields());
          });
        } else {
          unawaited(_flushDraftFields());
        }
      }
    }
  }

  void _applyDraftFields() {
    final driver = _driverDraft;
    final original = _draftHydrating;
    _draftHydrating = true;
    try {
      if (driver['name'] is String) _name.text = driver['name'] as String;
      if (driver['phone'] is String) _phone.text = driver['phone'] as String;
      _applyVehicleDraftFields(_selectedVehicleId);
    } finally { _draftHydrating = original; }
  }

  void _applyVehicleDraftFields(String? vehicleId) {
    final fields = _vehicleDraft(vehicleId);
    final original = _draftHydrating;
    _draftHydrating = true;
    try {
      final mapping = <String, TextEditingController>{
        'brand': _brand, 'model': _model, 'registration': _registration,
        'year': _year, 'passengers': _passengers, 'cargo_kg': _cargoKg,
        'body_type': _bodyType, 'other_category': _otherCategory,
      };
      for (final entry in mapping.entries) {
        final value = fields[entry.key];
        if (value is String) entry.value.text = value;
      }
      if (fields['category'] is String) _selectedCategory = fields['category'] as String;
      if (fields['propulsion'] is String) _selectedPropulsion = fields['propulsion'] as String;
      if (fields['services'] is List) {
        _selectedServices..clear()..addAll((fields['services'] as List).whereType<String>());
      }
    } finally { _draftHydrating = original; }
  }

  Map<String, String>? _draftIdentityAsset(String side) {
    final value = _driverDraft['identity_${side}_id']?.toString();
    if (value == null) return null;
    for (final item in _data?.assets ?? const <MarketplaceMediaAsset>[]) {
      if (item.id == value && item.storageBucket == 'marketplace-identity' &&
          item.storagePath != null && item.isAvailable) {
        return {
          'asset_id': item.id,
          'storage_path': item.storagePath!,
          'storage_bucket': 'marketplace-identity',
          'status': 'available',
        };
      }
    }
    return null;
  }

  bool _identityPhotoValid(String side) {
    final stored = _identityDocs[side];
    final hasPhoto = _identityPending.containsKey(side) ||
        (stored is Map && stored['status'] == 'available') ||
        _draftIdentityAsset(side) != null;
    if (!hasPhoto) return false;
    final savedType = _identityDocs['document_type']?.toString();
    if (savedType == null || savedType == _identityDocumentType) return true;
    // No reutilizar las fotos verificadas del tipo anterior.
    if (_identityPending.containsKey(side)) return true;
    final draftId = _driverDraft['identity_${side}_id']?.toString();
    return draftId != null && draftId != _identitySavedPhotoIds[side];
  }

  Map<String, String> _registrationErrors() {
    final issues = <String, String>{};
    if (_name.text.trim().isEmpty) {
      issues['name'] = 'Escribe tu nombre y apellidos.';
    }
    if (!RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(_phone.text.trim())) {
      issues['phone'] =
          'Escribe un teléfono válido con código de país, por ejemplo +5355555555.';
    }
    if (_driverPhotoBytes == null &&
        _data?.driverPhotoAssetId == null &&
        _draftDriverPhotoId == null &&
        _googleDriverPhotoUrl == null) {
      issues['driverPhoto'] = 'Añade una foto clara de tu rostro.';
    }
    final savedType = _identityDocs['document_type']?.toString();
    final changingType = savedType != null &&
        _identityDocumentType != null && savedType != _identityDocumentType;
    if (_identityRequired || changingType) {
      if (_identityRequired && _identityDocumentType == null) {
        issues['identityType'] = 'Selecciona carné de identidad o licencia de conducción.';
      }
      if (!_identityLoaded) {
        issues['identityLoad'] = 'No se pudo validar tu documentación. Actualiza.';
      }
      if (!_identityPhotoValid('front')) {
        issues['identityFront'] = changingType
            ? 'Al cambiar de documento, fotografía de nuevo su parte delantera.'
            : 'Agrega una foto delantera del documento elegido.';
      }
      if (!_identityPhotoValid('back')) {
        issues['identityBack'] = changingType
            ? 'Al cambiar de documento, fotografía de nuevo su parte trasera.'
            : 'Agrega una foto trasera del documento elegido.';
      }
    }
    if (widget.driverOnly) return issues;
    final vehicle = _findVehicle(_selectedVehicleId);
    if (vehicle == null) {
      issues['vehicleId'] =
          'Pulsa Añadir vehículo para registrar el que utilizarás.';
      return issues;
    }
    if (_validCatalogValue(
          _selectedCategory,
          _data?.vehicleCategories ?? const <MarketplaceCatalogItem>[],
        ) ==
        null) {
      issues['category'] = 'Selecciona la categoría de vehículo.';
    }
    if (_selectedCategory == 'other' && _otherCategory.text.trim().isEmpty) {
      issues['otherCategory'] = 'Describe el tipo de vehículo.';
    }
    if (_brand.text.trim().isEmpty) issues['brand'] = 'Indica la marca.';
    if (_model.text.trim().isEmpty) issues['model'] = 'Indica el modelo.';
    if ('${_brand.text.trim()} ${_model.text.trim()}'.trim().length > 80) {
      issues['model'] = 'Marca y modelo no pueden superar 80 caracteres.';
    }
    if (_validCatalogValue(
          _selectedPropulsion,
          _data?.propulsionTypes ?? const <MarketplaceCatalogItem>[],
        ) ==
        null) {
      issues['propulsion'] = 'Selecciona la propulsión.';
    }
    if (_selectedServices.isEmpty) {
      issues['services'] =
          'Selecciona al menos un servicio que puedas realizar.';
    }
    if (marketplaceNeedsPassengerCapacity(_selectedServices)) {
      final people = marketplaceResolvedPassengerCapacity(
        vehicleCategory: _selectedCategory,
        services: _selectedServices,
        enteredCapacity: _marketplaceOptionalInt(_passengers.text),
      );
      if ((_passengers.text.trim().isNotEmpty &&
              _marketplaceOptionalInt(_passengers.text) == null) ||
          !marketplaceValidPassengerCapacity(people, _selectedCategory)) {
        issues['passengers'] =
            'Indica una capacidad de pasajeros mayor que cero.';
      }
    }
    if (marketplaceNeedsCargoCapacity(_selectedServices)) {
      final kg = marketplaceResolvedCargoCapacity(
        services: _selectedServices,
        enteredCapacity: _marketplaceOptionalNumber(_cargoKg.text),
      );
      if (kg == null || !kg.isFinite || kg <= 0) {
        issues['cargoKg'] = 'Indica la capacidad de carga en kg.';
      }
    }
    if (_year.text.trim().isNotEmpty &&
        _marketplaceOptionalInt(_year.text) == null) {
      issues['year'] = 'Introduce un año válido o deja el campo vacío.';
    }
    if (_registration.text.trim().length > 32) {
      issues['registration'] = 'La chapa admite un máximo de 32 caracteres.';
    }
    if (_vehiclePhotoBytes == null && vehicle.mainPhotoAssetId == null &&
        _draftVehiclePhotoId == null) {
      issues['vehiclePhoto'] = 'Añade una foto principal del vehículo.';
    }
    return issues;
  }

  String? _registrationError(String field) =>
      _showFieldErrors ? _registrationErrors()[field] : null;

  String? _vehicleFieldError(String label) =>
      _registrationError(switch (label) {
        'Vehículo' => 'vehicleId',
        'Categoría' => 'category',
        'Describe el tipo de vehículo' => 'otherCategory',
        'Marca' => 'brand',
        'Modelo' => 'model',
        'Propulsión' => 'propulsion',
        'Pasajeros' => 'passengers',
        'Plazas de moto (opcional)' => 'passengers',
        'Carga (kg)' => 'cargoKg',
        'Año' => 'year',
        'Chapa (opcional)' => 'registration',
        _ => '',
      });

  void _refreshRegistrationErrors() {
    if (_showFieldErrors && mounted && !_saving) setState(() {});
  }

  void _scrollRegistrationToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_registrationScroll.hasClients) return;
      unawaited(
        _registrationScroll.animateTo(
          0,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
        ),
      );
    });
  }

  void _goToRegistrationStep(int nextStep) {
    if (_registrationSubmitting) return;
    if (widget.driverOnly && nextStep == 1) nextStep = 2;
    // Se permite continuar con una ficha parcial. Solo Finalizar exige todos
    // los obligatorios; los datos válidos se guardan en su borrador remoto.
    setState(() {
      _registrationStep = nextStep;
      _showFieldErrors = false;
      _registrationSaved = false;
    });
    _scrollRegistrationToTop();
  }

  Future<void> _saveRegistration() async {
    if (_registrationSubmitting || !_canEdit) return;
    // No borrar el borrador si queda un envío anterior en vuelo.
    for (var i = 0; i < 100 && _draftBusy; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 60));
    }
    if (!mounted) return;
    if (_draftBusy) {
      toast(context, 'Espera a que termine el guardado.');
      return;
    }
    await _flushDraftFields();
    if (!mounted) return;
    if (_draftBusy || _draftPending.isNotEmpty) {
      toast(context, 'Hay datos pendientes de guardar. Pulsa Reintentar.');
      return;
    }
    final issues = _registrationErrors();
    if (issues.isNotEmpty) {
      setState(() {
        _registrationStep = issues.keys.any(
          (key) => [
            'name',
            'phone',
            'driverPhoto',
            'identityType',
            'identityLoad',
            'identityFront',
            'identityBack'
          ].contains(key),
        )
            ? 0
            : 1;
        _showFieldErrors = true;
      });
      _scrollRegistrationToTop();
      toast(context, 'Completa los campos obligatorios marcados en rojo.');
      return;
    }
    // Guardamos los valores del vehiculo porque el RPC de conductor recarga
    // los datos del servidor y no debe borrar lo escrito pero aun no enviado.
    final vehicleFields = <TextEditingController, String>{
      _registration: _registration.text,
      _brand: _brand.text,
      _model: _model.text,
      _year: _year.text,
      _passengers: _passengers.text,
      _cargoKg: _cargoKg.text,
      _bodyType: _bodyType.text,
      _otherCategory: _otherCategory.text,
    };
    final category = _selectedCategory;
    final propulsion = _selectedPropulsion;
    final services = Set<String>.from(_selectedServices);
    final vehicleId = _selectedVehicleId;
    setState(() => _registrationSubmitting = true);
    try {
      await _saveDriver();
      if (!mounted) return;
      if (!widget.driverOnly) {
        setState(() {
          for (final entry in vehicleFields.entries) {
            entry.key.text = entry.value;
          }
          _selectedCategory = category;
          _selectedPropulsion = propulsion;
          _selectedVehicleId = vehicleId;
          _selectedServices
            ..clear()
            ..addAll(services);
        });
      }
      if (!_driverSaveSucceeded) return;
      if (!await _saveIdentityDocuments()) return;
      if (!widget.driverOnly) {
        await _saveVehicle();
        if (!mounted) return;
        if (!_vehicleSaveSucceeded) {
          toast(
            context,
            'Los datos personales se guardaron, pero falta guardar el vehículo. Puedes reintentar sin crear otro.',
          );
          return;
        }
      }
      if (!mounted) return;
      await _service.clearRegistrationDrafts(
        vehicleId: widget.driverOnly ? null : _selectedVehicleId,
      );
      if (!mounted) return;
      setState(() {
        _registrationDrafts.remove('driver');
        _registrationDrafts.remove('vehicle:$_selectedVehicleId');
        _registrationSaved = true;
        _showFieldErrors = false;
      });
      toast(context, 'Inscripción guardada correctamente.');
    } catch (_) {
      if (mounted) {
        toast(
          context,
          'No se pudo completar la inscripción. Conservamos tus datos para reintentar.',
        );
      }
    } finally {
      if (mounted) setState(() => _registrationSubmitting = false);
    }
  }

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
    final fields = <TextEditingController, String>{
      _name: 'name', _phone: 'phone', _registration: 'registration',
      _brand: 'brand', _model: 'model', _year: 'year',
      _passengers: 'passengers', _cargoKg: 'cargo_kg',
      _bodyType: 'body_type', _otherCategory: 'other_category',
    };
    for (final entry in fields.entries) {
      entry.key.addListener(() {
        _refreshRegistrationErrors();
        final isDriver = entry.value == 'name' || entry.value == 'phone';
        _queueDraftField(entry.value, entry.key.text.trim(),
          vehicleId: isDriver ? null : _selectedVehicleId);
      });
    }
    unawaited(_load());
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    if (_draftPending.isNotEmpty && !_draftBusy) {
      // Envío iniciado antes de desechar los controladores, sin bloquear UI.
      // Fallos de red siempre se muestran como pendientes, no como guardados.
      unawaited(_flushDraftFields());
    }
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
    _registrationScroll.dispose();
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

      if (widget.managementSection == MarketplaceManagementSection.wallet) {
        await _loadWallet();
      }
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
      final drafts = await _service.registrationDrafts();
      if (!mounted) return;
      setState(() {
        _registrationDrafts = drafts;
        _data = data;
        _loading = false;
        _applyData(data);
        _applyDraftFields();
        _draftHydrating = false;
      });

      _identityRequired = !data.driverProfileExists;
      await _loadIdentityDocuments();
      if (!widget.driverOnly) await _loadAccess();
      if (widget.managementSection == MarketplaceManagementSection.wallet) {
        await Future.wait([_loadWallet(), _loadTopups()]);
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

    final vehicle = marketplaceSingleOperationalVehicle(
      data.vehicles,
      preferredId: preferred,
    );

    _selectedVehicleId = vehicle?.id;
    _loadVehicleFields(vehicle);
  }

  void _loadVehicleFields(MarketplaceVehicle? vehicle) {
    final original = _draftHydrating;
    _draftHydrating = true;
    _selectedCategory = vehicle?.categoryCode;
    _selectedPropulsion = vehicle?.propulsionCode;

    _registration.text = vehicle?.registration ?? '';
    _brand.text = vehicle?.brand ?? '';
    _model.text = vehicle?.model ?? '';
    _year.text = vehicle?.year?.toString() ?? '';
    _passengers.text = vehicle?.passengerCapacity?.toString() ??
        (_selectedCategory == 'motorcycle' ? '1' : '');
    _cargoKg.text = vehicle?.cargoCapacityKg?.toString() ?? '';
    _bodyType.text = vehicle?.bodyType ?? '';
    _otherCategory.text = vehicle?.categoryOtherDescription ?? '';

    _selectedServices
      ..clear()
      ..addAll(vehicle?.services ?? const []);
    _applyVehicleDraftFields(vehicle?.id);
    _draftHydrating = original;
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

  Future<Uint8List?> _readMarketplacePhotoBytes({
    required ImageSource source,
    required String assetKind,
    String? identitySide,
  }) async {
    if (kIsWeb &&
        source == ImageSource.camera &&
        (assetKind == 'vehicle_photo' || assetKind == 'identity_document')) {
      return guided_capture.captureGuidedMarketplacePhoto(
        assetKind == 'vehicle_photo' ? 'vehicle' : 'identity-$identitySide',
      );
    }
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        source == ImageSource.camera &&
        assetKind == 'identity_document') {
      return identity_capture.captureGuidedMarketplaceIdentityPhoto(
        context,
        identitySide ?? 'front',
      );
    }
    final picked = await _imagePicker.pickImage(
      source: source,
      maxWidth: assetKind == 'identity_document' ? 2400 : 2048,
      maxHeight: assetKind == 'identity_document' ? 2400 : 2048,
      imageQuality: assetKind == 'identity_document' ? 95 : 92,
    );
    return picked?.readAsBytes();
  }

  Future<void> _pickPhoto(String assetKind) async {
    if (!_canEdit) return;

    final source = await _choosePhotoSource();
    if (source == null || !mounted) return;

    setState(() => _processingPhoto = true);

    Uint8List? sourceBytes;
    try {
      sourceBytes = await _readMarketplacePhotoBytes(
        source: source,
        assetKind: assetKind,
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

    if (sourceBytes == null) {
      if (mounted) setState(() => _processingPhoto = false);
      return;
    }

    try {
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

      // Al elegir una foto, subir inmediatamente (servidor privado). Si falla,
      // conservar la selección como pendiente en esta sesión, sin falso éxito.
      try {
        final isVehicle = assetKind == 'vehicle_photo';
        final key = isVehicle ? _vehiclePhotoUploadKey! : _driverPhotoUploadKey!;
        final vehicleId = isVehicle ? _selectedVehicleId : null;
        if (isVehicle && vehicleId == null) throw StateError('VEHICLE_REQUIRED');
        final asset = await _service.uploadMedia(
          assetKind: assetKind, bytes: normalized.bytes,
          mimeType: 'image/jpeg', extension: 'jpg', idempotencyKey: key);
        await _service.saveRegistrationDraftField(
          field: isVehicle ? 'vehicle_photo_id' : 'driver_photo_id',
          value: asset.id, vehicleId: vehicleId);
        if (!mounted || (isVehicle && vehicleId != _selectedVehicleId)) return;
        setState(() {
          final scope = isVehicle ? 'vehicle:$vehicleId' : 'driver';
          final fields = isVehicle ? _vehicleDraft(vehicleId) : _driverDraft;
          fields[isVehicle ? 'vehicle_photo_id' : 'driver_photo_id'] = asset.id;
          _registrationDrafts[scope] = fields;
          if (isVehicle) {
            _vehiclePhotoBytes = null; _vehiclePhotoUploadKey = null;
          } else {
            _driverPhotoBytes = null; _driverPhotoUploadKey = null;
          }
        });
        // Refrescar solo catálogo de assets, nunca sobreescribir campos escritos.
        final refreshed = await _service.onboarding();
        if (mounted) setState(() => _data = refreshed);
        if (mounted) {
          toast(context, 'Fotografía guardada correctamente.');
        }
      } catch (_) {
        if (mounted) {
          toast(context,
              'Fotografía pendiente de guardar. Reintenta antes de salir.');
        }
      }
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

  Future<void> _loadIdentityDocuments() async {
    try {
      final documents = await _service.identityDocuments();
      if (!mounted) return;
      setState(() {
        _identityDocs = Map<String, dynamic>.from(documents);
        final savedType = documents['document_type']?.toString();
        final draftType = _driverDraft['identity_document_type']?.toString();
        _identityDocumentType = (draftType == 'national_id' ||
                draftType == 'driver_license')
            ? draftType
            : (savedType == 'national_id' || savedType == 'driver_license')
                ? savedType
                : null;
        for (final side in const ['front', 'back']) {
          final saved = documents[side];
          _identitySavedPhotoIds[side] =
              saved is Map ? saved['asset_id']?.toString() : null;
          _identityDocs[side] ??= _draftIdentityAsset(side);
        }
        _identityRequired = documents['required'] == true;
        _identityLoaded = true;
        _identityError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _identityLoaded = false;
        _identityError = 'No se pudieron consultar tus documentos.';
      });
    }
  }

  Future<void> _pickIdentityDocument(String side) async {
    if (!_canEdit || _registrationSubmitting) return;
    final source = await _choosePhotoSource();
    if (source == null || !mounted) return;
    setState(() => _processingPhoto = true);
    try {
      final bytes = await _readMarketplacePhotoBytes(
        source: source,
        assetKind: 'identity_document',
        identitySide: side,
      );
      if (bytes == null || !mounted) return;
      final normalized = normalizeMarketplaceImage(
        sourceBytes: bytes,
        assetKind: 'identity_document',
      );
      if (!mounted) return;
      setState(() {
        _identityPending[side] = normalized.bytes;
        _identityUploadKeys[side] = _marketplaceUuidV4();
      });
      try {
        final key = _identityUploadKeys[side]!;
        final asset = await _service.uploadIdentityMedia(
          side: side, bytes: normalized.bytes, idempotencyKey: key);
        await _service.saveRegistrationDraftField(
          field: 'identity_${side}_id', value: asset.id);
        if (!mounted) return;
        setState(() {
          _identityPending.remove(side);
          _identityUploadKeys.remove(side);
          final draft = _driverDraft..['identity_${side}_id'] = asset.id;
          _registrationDrafts['driver'] = draft;
          _identityDocs[side] = {
            'asset_id': asset.id, 'storage_path': asset.storagePath,
            'storage_bucket': 'marketplace-identity', 'status': 'available',
          };
        });
        toast(context, 'Documento privado guardado.');
      } catch (_) {
        if (mounted) {
          toast(context, 'Foto pendiente de guardar. Reintenta antes de salir.');
        }
      }
    } catch (_) {
      if (mounted) {
        toast(context, 'No se pudo procesar la fotografía del documento.');
      }
    } finally {
      if (mounted) setState(() => _processingPhoto = false);
    }
  }

  Future<bool> _saveIdentityDocuments() async {
    final front = _driverDraft['identity_front_id']?.toString();
    final back = _driverDraft['identity_back_id']?.toString();
    if (_identityPending.isEmpty && front == null && back == null &&
        _identityDocumentType == _identityDocs['document_type']) {
      return true;
    }
    final uploaded = <String, String>{};
    try {
      for (final side in const ['front', 'back']) {
        final bytes = _identityPending[side];
        if (bytes == null) continue;
        final key = _identityUploadKeys.putIfAbsent(side, _marketplaceUuidV4);
        final asset = await _service.uploadIdentityMedia(
          side: side,
          bytes: bytes,
          idempotencyKey: key,
        );
        uploaded[side] = asset.id;
      }
      final saved = await _service.saveIdentityDocuments(
        frontId: uploaded['front'] ?? front,
        backId: uploaded['back'] ?? back,
        documentType: _identityDocumentType,
      );
      if (!mounted) return false;
      setState(() {
        _identityDocs = saved;
        for (final side in const ['front', 'back']) {
          final asset = saved[side];
          _identitySavedPhotoIds[side] =
              asset is Map ? asset['asset_id']?.toString() : null;
        }
        _identityLoaded = true;
        _identityError = null;
        for (final side in uploaded.keys) {
          _identityPending.remove(side);
          _identityUploadKeys.remove(side);
        }
      });
      return true;
    } catch (_) {
      if (mounted) {
        toast(context,
            'No se pudieron guardar las fotos. Puedes reintentar sin repetirlas.');
      }
      return false;
    }
  }

  Widget _identityDocumentTile(String side, String title) {
    final pending = _identityPending[side];
    final saved = _identityDocs[side];
    final asset = saved is Map ? saved : null;
    final id = asset?['asset_id']?.toString();
    final path = asset?['storage_path']?.toString();
    final stored = asset?['status'] == 'available' &&
        asset?['storage_bucket'] == 'marketplace-identity' &&
        id != null &&
        path != null;
    Widget preview;
    if (pending != null) {
      preview = Image.memory(pending,
          height: 152, width: double.infinity, fit: BoxFit.contain);
    } else if (stored) {
      final future = _savedPhotoFutures.putIfAbsent(
        'identity-$id',
        () => Supabase.instance.client.storage
            .from('marketplace-identity')
            .download(path),
      );
      preview = FutureBuilder<Uint8List>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return Image.memory(snapshot.data!,
                height: 152, width: double.infinity, fit: BoxFit.contain);
          }
          if (snapshot.hasError) {
            return const Text('No se pudo mostrar la fotografia privada.');
          }
          return const SizedBox(
              height: 80, child: Center(child: CircularProgressIndicator()));
        },
      );
    } else {
      preview = const SizedBox(
          height: 90, child: Icon(Icons.badge_outlined, size: 44));
    }
    final hasPhoto = pending != null || stored;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('$title${_identityRequired ? ' *' : ''}',
            style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: appOutlineColor(context)),
          ),
          child: preview,
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _canEdit && !_registrationSubmitting
              ? () => _pickIdentityDocument(side)
              : null,
          icon: Icon(hasPhoto
              ? Icons.change_circle_outlined
              : Icons.add_a_photo_outlined),
          label: Text(hasPhoto ? 'Cambiar fotografia' : 'Agregar fotografia'),
        ),
        Text(
          pending != null
              ? 'Pendiente de guardar'
              : stored
                  ? 'Documento privado guardado'
                  : 'Fotografia pendiente',
          style: TextStyle(fontSize: 12, color: appMutedColor(context)),
        ),
      ],
    );
  }

  Future<void> _saveDriver() async {
    _driverSaveSucceeded = false;
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
      var photoAssetId = _draftDriverPhotoId ?? data.driverPhotoAssetId;
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
        final adoptionKey = _googleAvatarAdoptionKey ?? _marketplaceUuidV4();
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
      _driverSaveSucceeded = true;
      if (!_registrationSubmitting) {
        toast(context, 'Perfil de conductor y foto guardados.');
      }
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
    // En versiones que aun muestran el boton, no crear otro vehiculo.
    // Nunca descartar fotos o campos sin guardar del vehiculo existente.
    if (_data!.vehicles.isNotEmpty) {
      toast(context, 'Ya tienes un vehiculo para Trabajos. Completa su ficha.');
      return;
    }

    final unsavedName = _name.text;
    final unsavedPhone = _phone.text;
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
        _name.text = unsavedName;
        _phone.text = unsavedPhone;
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
    _vehicleSaveSucceeded = false;
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
    final passengers = marketplaceResolvedPassengerCapacity(
      vehicleCategory: _selectedCategory,
      services: _selectedServices,
      enteredCapacity: _marketplaceOptionalInt(_passengers.text),
    );
    final cargoKg = marketplaceResolvedCargoCapacity(
      services: _selectedServices,
      enteredCapacity: _marketplaceOptionalNumber(_cargoKg.text),
    );

    if (_year.text.trim().isNotEmpty && year == null) {
      toast(context, 'El año del vehículo no es válido.');
      return;
    }

    if (marketplaceNeedsPassengerCapacity(_selectedServices) &&
        ((_passengers.text.trim().isNotEmpty &&
                _marketplaceOptionalInt(_passengers.text) == null) ||
            !marketplaceValidPassengerCapacity(
                passengers, _selectedCategory))) {
      toast(context, 'Indica una capacidad de pasajeros mayor que cero.');
      return;
    }

    if (marketplaceNeedsCargoCapacity(_selectedServices) &&
        (cargoKg == null || !cargoKg.isFinite || cargoKg <= 0)) {
      toast(context, 'Indica la capacidad de carga en kilogramos.');
      return;
    }

    setState(() => _saving = true);

    try {
      final services = _selectedServices.toList()..sort();

      var photoAssetId = _draftVehiclePhotoId ?? vehicle.mainPhotoAssetId;
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
      _vehicleSaveSucceeded = true;
      if (!_registrationSubmitting) toast(context, 'Vehículo guardado.');
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
                          : access.nextBillingMode == MarketplaceBillingMode.platformFree
                              ? 'Trabajos habilitados sin comisiones. No necesitas saldo para aceptar carreras.'
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

  Future<void> _loadTopups() async {
    if (!mounted || _topupsLoading || _localPreview) return;
    setState(() {
      _topupsLoading = true;
      _topupsError = null;
    });
    try {
      final items = await _service.topups();
      if (!mounted) return;
      setState(() => _topups = items);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _topupsError =
            'No pudimos consultar las recargas. Revisa tu conexión e inténtalo nuevamente.';
      });
    } finally {
      if (mounted) setState(() => _topupsLoading = false);
    }
  }

  Future<void> _requestTopup() async {
    if (_topupFormOpen || _localPreview) return;
    setState(() => _topupFormOpen = true);
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      useSafeArea: true,
      builder: (_) => MarketplaceTopupForm(
        service: _service,
        requestKeys: _topupRequestKeys,
      ),
    );
    if (!mounted) return;
    setState(() => _topupFormOpen = false);
    if (sent != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Solicitud de recarga enviada. Queda pendiente de confirmación.',
        ),
      ),
    );
    await Future.wait([_loadWallet(), _loadTopups()]);
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
          FilledButton.icon(
            onPressed: _topupFormOpen || _topupsLoading || _localPreview
                ? null
                : _requestTopup,
            icon: const Icon(Icons.add_card),
            label: const Text('Recargar saldo'),
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
          ] else ...[
            _buildWalletCard(context),
            const SizedBox(height: 16),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Historial de recargas',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  TextButton.icon(
                    onPressed: _topupsLoading || _walletLoading || _localPreview
                        ? null
                        : () async {
                            await Future.wait([_loadWallet(), _loadTopups()]);
                          },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Actualizar'),
                  ),
                  if (_topupsLoading) const LinearProgressIndicator(),
                  if (_topupsError != null) Text(_topupsError!),
                  if (!_topupsLoading && _topupsError == null)
                    MarketplaceTopupHistory(topups: _topups),
                ],
              ),
            ),
          ],
        ],
      );
    }

    return ListView(
      controller: _registrationScroll,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 120),
      children: [
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Conviértete en conductor',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 7),
              Text(
                'Completa tus datos y los del vehículo. Los campos con * son obligatorios.',
                style: TextStyle(color: appMutedColor(context), height: 1.4),
              ),
              const SizedBox(height: 8),
              if (_draftBusy || _draftPending.isNotEmpty || _draftError != null)
                Row(children: [
                  Icon(_draftError == null ? Icons.cloud_upload_outlined : Icons.error_outline,
                    size: 17, color: _draftError == null ? kTertiary : kDanger),
                  const SizedBox(width: 6),
                  Expanded(child: Text(_draftError ??
                    (_draftBusy ? 'Guardando datos válidos…' : 'Datos pendientes de guardar'),
                    style: const TextStyle(fontSize: 12))),
                  if (_draftError != null)
                    TextButton(onPressed: _draftBusy ? null : () => unawaited(_flushDraftFields()),
                      child: const Text('Reintentar')),
                ])
              else
                Text(_registrationDrafts.isEmpty
                    ? 'Los datos válidos se guardan al escribirlos.'
                    : 'Cambios guardados en tu cuenta.',
                  style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: (_registrationStep + 1) / 3,
                minHeight: 6,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (final (index, title) in [
                    'Mis datos',
                    'Mi vehículo',
                    'Finalizar',
                  ].indexed)
                    Expanded(
                      child: Text(
                        '${index + 1}. $title',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: _registrationStep == index
                              ? FontWeight.w900
                              : FontWeight.w500,
                          color: _registrationStep == index
                              ? appPrimaryColor(context)
                              : appMutedColor(context),
                        ),
                      ),
                    ),
                ],
              ),
            ],
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
        if (_registrationStep == 0)
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Datos del conductor',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                if (_showFieldErrors) ...[
                  const SizedBox(height: 8),
                  for (final issue in _registrationErrors().entries)
                    if ([
                      'name',
                      'phone',
                      'driverPhoto',
                      'identityType',
                      'identityLoad',
                      'identityFront',
                      'identityBack'
                    ].contains(issue.key))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '• ${issue.value}',
                          style: const TextStyle(color: kDanger, fontSize: 12),
                        ),
                      ),
                ],
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
                          decoration: InputDecoration(
                            labelText: 'Nombre y apellidos *',
                            errorText: _registrationError('name'),
                            isDense: true,
                            prefixIcon: const Icon(
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
                          decoration: InputDecoration(
                            labelText: 'WhatsApp / teléfono *',
                            errorText: _registrationError('phone'),
                            hintText: '+5355555555',
                            isDense: true,
                            prefixIcon:
                                const Icon(Icons.phone_outlined, size: 22),
                          ),
                        ),
                      ],
                    );
                    final hasDriverPhoto = _driverPhotoBytes != null ||
                        data.driverPhotoAssetId != null ||
                        _draftDriverPhotoId != null ||
                        _googleDriverPhotoUrl != null;
                    if (!hasDriverPhoto) return compactDriverFields;

                    final photo = _buildMarketplacePhotoPreview(
                      pendingBytes: _driverPhotoBytes,
                      savedAssetId: _draftDriverPhotoId ?? data.driverPhotoAssetId,
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
                              _draftDriverPhotoId == null &&
                              _googleDriverPhotoUrl == null
                          ? Icons.photo_camera_outlined
                          : Icons.check_circle_outline,
                      color: _driverPhotoBytes == null &&
                              data.driverPhotoAssetId == null &&
                              _draftDriverPhotoId == null &&
                              _googleDriverPhotoUrl == null
                          ? kTertiary
                          : appPrimaryColor(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _driverPhotoBytes != null
                            ? 'Foto seleccionada, pendiente de guardar. ${_driverPhotoLabel ?? ''}'
                            : (_draftDriverPhotoId ?? data.driverPhotoAssetId) != null
                                ? 'Foto del conductor guardada'
                                : _googleDriverPhotoUrl != null
                                    ? 'Usaremos tu foto de Google como foto inicial. Puedes cambiarla.'
                                    : 'Foto del conductor pendiente',
                      ),
                    ),
                  ],
                ),
                if (_registrationError('driverPhoto') != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    _registrationError('driverPhoto')!,
                    style: const TextStyle(color: kDanger, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed:
                        _canEdit ? () => _pickPhoto('driver_photo') : null,
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: Text(
                      data.driverPhotoAssetId == null &&
                              _draftDriverPhotoId == null &&
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
              ],
            ),
          ),
        if (_registrationStep == 0) ...[
          const SizedBox(height: 12),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Carné de identidad o licencia de conducción',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text(
                  _identityRequired
                      ? 'Sube fotografías de ambas caras del carné o la licencia para completar tu inscripción.'
                      : 'Los conductores inscritos anteriormente pueden completar sus documentos aquí.',
                  style: TextStyle(fontSize: 12, color: appMutedColor(context)),
                ),
                const SizedBox(height: 12),
                Text('Tipo de documento${_identityRequired ? ' *' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final kind in const ['national_id', 'driver_license'])
                      ChoiceChip(
                        label: Text(kind == 'national_id'
                            ? 'Carné de identidad' : 'Licencia de conducción'),
                        selected: _identityDocumentType == kind,
                        onSelected: _canEdit && !_registrationSubmitting
                            ? (selected) {
                                if (!selected) return;
                                setState(() {
                                  _identityDocumentType = kind;
                                  _registrationSaved = false;
                                });
                                _queueDraftField('identity_document_type', kind);
                              }
                            : null,
                      ),
                  ],
                ),
                if (_identityError != null)
                  Text(_identityError!, style: const TextStyle(color: kDanger)),
                if (_showFieldErrors)
                  for (final issue in _registrationErrors().entries)
                    if (['identityType', 'identityLoad', 'identityFront', 'identityBack']
                        .contains(issue.key))
                      Text(issue.value, style: const TextStyle(color: kDanger)),
                if (_identityDocs['document_type'] != null &&
                    _identityDocumentType != _identityDocs['document_type'])
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Cambiaste el tipo de documento. Debes volver a fotografiar ambas caras.',
                      style: TextStyle(fontSize: 12, color: kDanger),
                    ),
                  ),
                const SizedBox(height: 16),
                _identityDocumentTile('front', 'Parte delantera'),
                const SizedBox(height: 14),
                const Divider(),
                const SizedBox(height: 12),
                _identityDocumentTile('back', 'Parte trasera'),
                const SizedBox(height: 10),
                Text(
                  'Estas fotografias son privadas y nunca aparecen ante clientes.',
                  style: TextStyle(fontSize: 12, color: appMutedColor(context)),
                ),
              ],
            ),
          ),
        ],
        if (_registrationStep == 1 && !widget.driverOnly)
          const SizedBox(height: 16),
        if (_registrationStep == 1 && !widget.driverOnly)
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Vehículo para Trabajos',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                if (_showFieldErrors) ...[
                  const SizedBox(height: 8),
                  for (final issue in _registrationErrors().entries)
                    if (![
                      'name',
                      'phone',
                      'driverPhoto',
                      'identityType',
                      'identityLoad',
                      'identityFront',
                      'identityBack'
                    ].contains(issue.key))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '• ${issue.value}',
                          style: const TextStyle(color: kDanger, fontSize: 12),
                        ),
                      ),
                ],
                if (data.vehicles.isEmpty) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _canEdit ? _createVehicle : null,
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Registrar mi vehículo'),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                if (data.vehicles.isEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Todavía no tienes un vehículo para Trabajos. Pulsa Registrar mi vehículo y completa sus datos y fotografías.',
                      ),
                      if (_registrationError('vehicleId') != null)
                        Text(
                          _registrationError('vehicleId')!,
                          style: const TextStyle(color: kDanger, fontSize: 12),
                        ),
                    ],
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
                          labelText: _vehicleFieldError(label) != null ||
                                  [
                                    'Vehículo',
                                    'Categoría',
                                    'Marca',
                                    'Modelo',
                                    'Propulsión',
                                  ].contains(label) ||
                                  (label == 'Pasajeros' &&
                                      (_selectedServices.contains(
                                            'passenger',
                                          ) ||
                                          _selectedServices.contains(
                                            'tourism',
                                          ))) ||
                                  (label == 'Carga (kg)' &&
                                      _selectedServices.contains('cargo')) ||
                                  (label == 'Describe el tipo de vehículo' &&
                                      _selectedCategory == 'other')
                              ? '$label *'
                              : label,
                          errorText: _vehicleFieldError(label),
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

                      Widget field(Widget child) => ConstrainedBox(
                            constraints: const BoxConstraints(
                              minHeight: fieldHeight,
                            ),
                            child: child,
                          );

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
                                      _queueDraftField('services',
                                        _selectedServices.toList()..sort(),
                                        vehicleId: _selectedVehicleId);
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
                            if (_registrationError('services') != null) ...[
                              const SizedBox(height: 5),
                              Text(
                                _registrationError('services')!,
                                style: const TextStyle(
                                  color: kDanger,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );

                      final showPassengerCapacity =
                          marketplaceNeedsPassengerCapacity(_selectedServices);
                      final showCargoCapacity =
                          marketplaceNeedsCargoCapacity(_selectedServices);
                      final automaticMotorcyclePassenger =
                          showPassengerCapacity &&
                              _selectedCategory == 'motorcycle';
                      final motorCount = automaticMotorcyclePassenger
                          ? marketplaceResolvedPassengerCapacity(
                              vehicleCategory: _selectedCategory,
                              services: _selectedServices,
                              enteredCapacity:
                                  _marketplaceOptionalInt(_passengers.text),
                            )
                          : null;

                      Widget passengerStepper({String label = 'Pasajeros'}) {
                        final raw = _marketplaceOptionalInt(_passengers.text);
                        final count = raw != null && raw > 0 ? raw : null;
                        final limit =
                            marketplacePassengerLimit(_selectedCategory);
                        return field(
                          InputDecorator(
                            decoration: fieldDecoration(
                              label,
                              Icons.people_outline,
                            ).copyWith(prefixIcon: null),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Reducir pasajeros',
                                  onPressed: !_canEdit ||
                                          count == null ||
                                          count <= 1
                                      ? null
                                      : () => setState(() {
                                            _passengers.text = '${count - 1}';
                                          }),
                                  icon: const Icon(Icons.remove_circle_outline),
                                  constraints: const BoxConstraints(
                                    minWidth: 40,
                                    minHeight: 40,
                                  ),
                                  padding: EdgeInsets.zero,
                                ),
                                SizedBox(
                                  width: 54,
                                  child: TextField(
                                    controller: _passengers,
                                    enabled: _canEdit,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    onChanged: (_) => setState(() {}),
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      hintText: '—',
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Aumentar pasajeros',
                                  onPressed: !_canEdit ||
                                          (count != null && count >= limit)
                                      ? null
                                      : () => setState(() {
                                            _passengers.text =
                                                '${(count ?? 0) + 1}';
                                          }),
                                  icon: const Icon(Icons.add_circle_outline),
                                  constraints: const BoxConstraints(
                                    minWidth: 40,
                                    minHeight: 40,
                                  ),
                                  padding: EdgeInsets.zero,
                                ),
                              ],
                            ),
                          ),
                        );
                      }

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
                                  ? (value) => setState(() {
                                        if (value == 'motorcycle' &&
                                            _selectedCategory != 'motorcycle') {
                                          _passengers.text = '1';
                                        } else if (value != 'motorcycle' &&
                                            _selectedCategory == 'motorcycle') {
                                          _passengers.clear();
                                        }
                                        _selectedCategory = value;
                                        if (value != null) {
                                          _queueDraftField('category', value,
                                              vehicleId: _selectedVehicleId);
                                        }
                                      })
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
                                      () {
                                        _selectedPropulsion = value;
                                        if (value != null) {
                                          _queueDraftField('propulsion', value,
                                              vehicleId: _selectedVehicleId);
                                        }
                                      },
                                    )
                                : null,
                          ),
                          const SizedBox(height: gap),
                          services,
                          if (showPassengerCapacity || showCargoCapacity) ...[
                            const SizedBox(height: gap),
                            if (automaticMotorcyclePassenger)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color:
                                        Theme.of(context).colorScheme.outline,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.people_outline, size: 19),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        motorCount == 1
                                            ? '1 pasajero · automático en motocicleta (sin contar al conductor)'
                                            : '$motorCount pasajeros · capacidad especial de motocicleta',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (showPassengerCapacity &&
                                !automaticMotorcyclePassenger) ...[
                              passengerStepper(),
                              if (showCargoCapacity)
                                const SizedBox(height: gap),
                            ],
                            if (showCargoCapacity)
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
                              if (automaticMotorcyclePassenger) ...[
                                const SizedBox(height: gap),
                                const Text(
                                  'Solo si tu motocicleta admite otra capacidad:',
                                ),
                                const SizedBox(height: gap),
                                passengerStepper(
                                    label: 'Plazas de moto (opcional)'),
                              ],
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                  if (_vehiclePhotoBytes != null ||
                      vehicle?.mainPhotoAssetId != null ||
                      _draftVehiclePhotoId != null) ...[
                    _buildMarketplacePhotoPreview(
                      pendingBytes: _vehiclePhotoBytes,
                      savedAssetId: _draftVehiclePhotoId ?? vehicle?.mainPhotoAssetId,
                      vehicle: true,
                    ),
                    const SizedBox(height: 10),
                  ],
                  Row(
                    children: [
                      Icon(
                        _vehiclePhotoBytes == null &&
                                vehicle?.mainPhotoAssetId == null &&
                              _draftVehiclePhotoId == null
                            ? Icons.directions_car_outlined
                            : Icons.check_circle_outline,
                        color: _vehiclePhotoBytes == null &&
                                vehicle?.mainPhotoAssetId == null &&
                              _draftVehiclePhotoId == null
                            ? kTertiary
                            : appPrimaryColor(context),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _vehiclePhotoBytes != null
                              ? 'Foto seleccionada, pendiente de guardar. ${_vehiclePhotoLabel ?? ''}'
                              : (_draftVehiclePhotoId ?? vehicle?.mainPhotoAssetId) == null
                                  ? 'Foto principal del vehículo pendiente'
                                  : 'Foto principal del vehículo guardada',
                        ),
                      ),
                    ],
                  ),
                  if (_registrationError('vehiclePhoto') != null) ...[
                    const SizedBox(height: 5),
                    Text(
                      _registrationError('vehiclePhoto')!,
                      style: const TextStyle(color: kDanger, fontSize: 12),
                    ),
                  ],
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
                                _draftVehiclePhotoId == null &&
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
        if (_registrationStep == 2) ...[
          const SizedBox(height: 14),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Revisa tu inscripción',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                Text('Conductor: ${_name.text.trim()}'),
                const SizedBox(height: 6),
                Text('WhatsApp: ${_phone.text.trim()}'),
                if (!widget.driverOnly) ...[
                  const SizedBox(height: 6),
                  Text('Vehículo: ${_brand.text.trim()} ${_model.text.trim()}'),
                  const SizedBox(height: 6),
                  Text('Servicios: ${_selectedServices.length} seleccionados'),
                ],
                const SizedBox(height: 12),
                Text(
                  'Al guardar se enviarán tus datos y fotografías. No se crearán vehículos adicionales.',
                  style: TextStyle(color: appMutedColor(context), height: 1.4),
                ),
                if (_registrationSaved) ...[
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
                          'Inscripción guardada correctamente.',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_registrationStep < 2)
                FilledButton.icon(
                  onPressed: _canEdit && !_registrationSubmitting
                      ? () => _goToRegistrationStep(_registrationStep + 1)
                      : null,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text(
                    _registrationStep == 0
                        ? (widget.driverOnly
                            ? 'Continuar'
                            : 'Continuar al vehículo')
                        : 'Revisar inscripción',
                  ),
                )
              else
                FilledButton.icon(
                  onPressed: _canEdit &&
                          !_registrationSubmitting &&
                          !_registrationSaved
                      ? _saveRegistration
                      : null,
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(
                    _registrationSubmitting
                        ? 'Guardando inscripción...'
                        : _registrationSaved
                            ? 'Inscripción guardada'
                            : 'Guardar mi inscripción',
                  ),
                ),
              if (_registrationStep > 0) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _canEdit && !_registrationSubmitting
                      ? () => _goToRegistrationStep(
                            widget.driverOnly ? 0 : _registrationStep - 1,
                          )
                      : null,
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Volver'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
