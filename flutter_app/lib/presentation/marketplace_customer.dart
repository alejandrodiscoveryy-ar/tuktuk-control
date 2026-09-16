part of '../main.dart';

class MarketplaceCustomerApp extends StatelessWidget {
  const MarketplaceCustomerApp({
    required this.client,
    super.key,
  });

  final SupabaseClient client;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TUKTUK',
      theme: buildAppTheme(Brightness.dark),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: ThemeMode.dark,
      home: MarketplaceCustomerShell(
        client: client,
      ),
    );
  }
}

class MarketplaceCustomerShell extends StatefulWidget {
  const MarketplaceCustomerShell({
    required this.client,
    super.key,
  });

  final SupabaseClient client;

  @override
  State<MarketplaceCustomerShell> createState() =>
      _MarketplaceCustomerShellState();
}

class _MarketplaceCustomerShellState extends State<MarketplaceCustomerShell> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _whatsappController = TextEditingController();

  late final MarketplaceCustomerService _service;
  late final MarketplaceCustomerSessionStore _sessionStore;
  late final String _sessionToken;
  late final String _startIdempotencyKey;

  MarketplaceCustomerSessionSnapshot? _existingSession;

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    _service = MarketplaceCustomerService(widget.client);
    _sessionStore = MarketplaceCustomerSessionStore(Hive.box(_metaBox));

    final saved = _sessionStore.read();
    final expiresAt = saved?.expiresAt;

    if (saved != null &&
        (expiresAt == null || expiresAt.isAfter(DateTime.now().toUtc()))) {
      _existingSession = saved;
    } else if (saved != null) {
      _sessionStore.clear();
    }

    _sessionToken = marketplaceCustomerSessionToken();
    _startIdempotencyKey = _marketplaceUuid();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _whatsappController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Escribe tu nombre.';
    }
    if (text.length > 120) {
      return 'El nombre es demasiado largo.';
    }
    return null;
  }

  String? _validateWhatsapp(String? value) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) {
      return 'Escribe tu número de WhatsApp.';
    }

    if (!RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(text)) {
      return 'Usa formato internacional, por ejemplo +5355555555.';
    }

    return null;
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final session = await _service.startSession(
        displayName: _nameController.text.trim(),
        whatsappPhone: _whatsappController.text.trim(),
        sessionToken: _sessionToken,
        idempotencyKey: _startIdempotencyKey,
      );

      final snapshot = MarketplaceCustomerSessionSnapshot(
        sessionId: session.sessionId,
        customerId: session.customerId,
        token: _sessionToken,
        expiresAt: session.expiresAt,
      );

      await _sessionStore.save(
        session: session,
        token: _sessionToken,
      );

      if (!mounted) return;

      setState(() {
        _existingSession = snapshot;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error =
            'No pudimos iniciar la solicitud. Revisa tu conexión e inténtalo otra vez.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final existingSession = _existingSession;

    if (existingSession != null) {
      return MarketplaceCustomerRequestScreen(
        service: _service,
        session: existingSession,
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.local_taxi_rounded,
                      size: 56,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Solicita tu transporte',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Conecta con un transportista disponible desde TUKTUK.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(color: kMuted),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [
                        AutofillHints.name,
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Nombre',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: _validateName,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _whatsappController,
                      keyboardType: TextInputType.phone,
                      autofillHints: const [
                        AutofillHints.telephoneNumber,
                      ],
                      decoration: const InputDecoration(
                        labelText: 'WhatsApp',
                        hintText: '+5355555555',
                        prefixIcon: Icon(Icons.chat_bubble_outline),
                      ),
                      validator: _validateWhatsapp,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Usaremos este número únicamente como contacto operativo del servicio.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: kMuted),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: kDanger,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _loading ? null : _continue,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Continuar'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MarketplaceCustomerRequestScreen extends StatefulWidget {
  const MarketplaceCustomerRequestScreen({
    required this.service,
    required this.session,
    super.key,
  });

  final MarketplaceCustomerService service;
  final MarketplaceCustomerSessionSnapshot session;

  @override
  State<MarketplaceCustomerRequestScreen> createState() =>
      _MarketplaceCustomerRequestScreenState();
}

class _MarketplaceCustomerRequestScreenState
    extends State<MarketplaceCustomerRequestScreen> {
  List<MarketplaceCustomerServiceOption> _services =
      const <MarketplaceCustomerServiceOption>[];

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    try {
      final services = await widget.service.listCustomerServices();

      if (!mounted) return;

      setState(() {
        _services = services;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'No pudimos cargar los servicios disponibles.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva solicitud'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : _error != null
                      ? Center(child: Text(_error!))
                      : _services.isEmpty
                          ? const Center(
                              child: Text(
                                'Todavía no hay servicios disponibles.',
                              ),
                            )
                          : ListView.separated(
                              itemCount: _services.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final service = _services[index];

                                return Card(
                                  child: ListTile(
                                    title: Text(service.name),
                                    subtitle: Text(
                                      'Precio calculado en ${service.currency}',
                                    ),
                                    trailing: const Icon(
                                      Icons.chevron_right,
                                    ),
                                    onTap: null,
                                  ),
                                );
                              },
                            ),
            ),
          ),
        ),
      ),
    );
  }
}

String _marketplaceUuid() {
  final random = Random.secure();
  final bytes = List<int>.generate(
    16,
    (_) => random.nextInt(256),
  );

  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;

  String hex(int value) => value.toRadixString(16).padLeft(2, '0');

  final value = bytes.map(hex).join();

  return '${value.substring(0, 8)}-'
      '${value.substring(8, 12)}-'
      '${value.substring(12, 16)}-'
      '${value.substring(16, 20)}-'
      '${value.substring(20)}';
}
