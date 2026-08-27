part of '../main.dart';

String? _googleProfilePhotoUrl(User? user) {
  final metadata = user?.userMetadata;
  for (final key in const ['avatar_url', 'picture']) {
    final value = metadata?[key]?.toString().trim();
    if (value != null && value.isNotEmpty) return value;
  }
  return null;
}

Future<bool> _runLicensedWrite(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
    return true;
  } on ReadOnlyLicenseException {
    if (context.mounted) {
      toast(context, tr('Tu licencia no permite realizar cambios.'));
    }
    return false;
  }
}

class AppShell extends StatefulWidget {
  const AppShell({required this.store, super.key});

  final RecordStore store;

  @override
  State<AppShell> createState() => _AppShellState();
}

class AppLogoMark extends StatelessWidget {
  const AppLogoMark({this.size = 34, this.transparent = false, super.key});

  final double size;
  final bool transparent;

  @override
  Widget build(BuildContext context) {
    if (transparent) {
      return SizedBox.square(
        dimension: size,
        child: Image.asset(
          'assets/branding/tuktuk_logo_transparent.png',
          fit: BoxFit.contain,
          semanticLabel: 'TukTuk Control',
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * .24),
        boxShadow: [
          BoxShadow(
            color: kPrimary.withValues(alpha: .28),
            blurRadius: size * .35,
            offset: Offset(0, size * .12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * .24),
        child: Image.asset(
          'assets/branding/tuktuk_logo.png',
          fit: BoxFit.cover,
          semanticLabel: 'TukTuk Control',
        ),
      ),
    );
  }
}

class _ExchangeRateHeader extends StatelessWidget {
  const _ExchangeRateHeader({required this.store});

  final RecordStore store;

  String? _updatedLabel() {
    final updatedAt = store.exchangeRateUpdatedAt;
    if (updatedAt == null) return null;

    final local = updatedAt.toLocal();
    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);
    final updatedDay = DateTime(local.year, local.month, local.day);
    final difference = today.difference(updatedDay).inDays;
    final time = DateFormat('HH:mm').format(local);

    if (difference == 0) {
      return 'Actualizado $time';
    }

    if (difference == 1) {
      return 'Ayer · $time';
    }

    return '${DateFormat('d MMM', activeLanguage).format(local)} · $time';
  }

  Color _freshnessColor() {
    final updatedAt = store.exchangeRateUpdatedAt;

    if (updatedAt == null) {
      return kMuted;
    }

    final age = DateTime.now().difference(updatedAt.toLocal());

    if (age <= const Duration(hours: 2)) {
      return kPrimary;
    }

    if (age <= const Duration(hours: 6)) {
      return kTertiary;
    }

    return kDanger;
  }

  @override
  Widget build(BuildContext context) {
    final rate = store.exchangeRate;
    final updatedLabel = _updatedLabel();
    final freshnessColor = _freshnessColor();

    final text = rate == null
        ? '${store.exchangeRateBaseCurrency}/${store.exchangeRateChargeCurrency} · ${store.exchangeRateSource}'
        : '1 ${store.exchangeRateBaseCurrency} = ${numFmt(rate)} ${store.exchangeRateChargeCurrency} · ${store.exchangeRateSource}';

    return Tooltip(
      message: tr('Tasa de cambio'),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: store.user == null
            ? null
            : () => unawaited(store.refreshExchangeRate()),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 3,
          ),
          child: Row(
            children: [
              Icon(
                Icons.currency_exchange_rounded,
                color: freshnessColor,
                size: 19,
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (updatedLabel != null)
                      Text(
                        updatedLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: freshnessColor,
                          fontSize: 9.5,
                          height: 1.05,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppBackground extends StatelessWidget {
  const AppBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [
                  Color(0xFF0B1718),
                  Color(0xFF080D14),
                  Color(0xFF101827),
                ]
              : const [
                  Color(0xFFE7F8F3),
                  Color(0xFFF7FAFE),
                  Color(0xFFEAF1FC),
                ],
        ),
      ),
      child: child,
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen(
      {required this.store, this.previewOnly = false, super.key});

  final RecordStore store;
  final bool previewOnly;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool saving = false;
  String? error;

  Future<void> continueDirectly() async {
    if (widget.previewOnly) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.store.configureFirstVehicle(name: tr('Mi Tuk Tuk'));
    } catch (_) {
      if (mounted) {
        setState(() => error = tr('No se pudo iniciar la aplicacion.'));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> continueWithGoogle() async {
    if (widget.previewOnly) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      // El callback OAuth completa la sesion de forma asincrona.
      // RecordStore restaura o crea el vehiculo cuando recibe la sesion.
      await widget.store.signIn();
    } catch (_) {
      if (mounted) {
        setState(() => error = tr('No se pudo iniciar con Google.'));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 18,
                ),
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: AspectRatio(
                      aspectRatio: 2,
                      child: Image.asset(
                        'assets/branding/tuktuk_welcome.png',
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  GlassCard(
                    child: Column(
                      children: [
                        Text(
                          tr('Puedes registrarte con Google para respaldar tus datos o entrar directamente y usar la aplicacion sin conexion.'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: kMuted, height: 1.4),
                        ),
                        if (error != null) ...[
                          const SizedBox(height: 12),
                          Text(error!, style: const TextStyle(color: kDanger)),
                        ],
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: saving ? null : continueWithGoogle,
                            icon: saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.login_rounded),
                            label: Text(tr('Continuar con Google')),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: saving ? null : continueDirectly,
                            icon: const Icon(Icons.arrow_forward_rounded),
                            label: Text(tr('Entrar directamente')),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  Center(
                    child: Semantics(
                      label: 'Vrixora Solutions',
                      image: true,
                      child: SizedBox(
                        width: 230,
                        height: 58,
                        child: Image.asset(
                          'assets/branding/vrixora_solutions.png',
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Soluciones inteligentes para negocios inteligentes',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                      letterSpacing: .35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppShellState extends State<AppShell> {
  int index = 0;
  String? _lastAuthenticatedUserId;

  RecordStore get store => widget.store;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        if (!store.initialized) {
          return const Scaffold(
            body: AppBackground(
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        final previewWelcome = Uri.base.queryParameters['preview'] == 'welcome';
        if (store.needsOnboarding || previewWelcome) {
          return OnboardingScreen(
            store: store,
            previewOnly: previewWelcome && !store.needsOnboarding,
          );
        }
        final authenticatedUserId = store.user?.id;
        if (_lastAuthenticatedUserId == null && authenticatedUserId != null) {
          index = 0;
        }
        _lastAuthenticatedUserId = authenticatedUserId;
        final isSynchronized = store.user != null &&
            store.pendingSyncCount == 0 &&
            store.lastSyncAt != null;
        final syncColor = store.syncing
            ? kTertiary
            : isSynchronized
                ? kPrimary
                : kDanger;
        final useDesktopNavigation = MediaQuery.sizeOf(context).width >= 1100;
        final screens = [
          DashboardScreen(store: store),
          RegisterScreen(
            store: store,
            onSaved: () => setState(() => index = 0),
          ),
          HistoryScreen(store: store),
          StatsScreen(store: store),
          const StoreScreen(),
          LoginScreen(store: store),
        ];
        return Scaffold(
          extendBody: true,
          appBar: AppBar(
            toolbarHeight: 44,
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(14),
                bottomRight: Radius.circular(14),
              ),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(14),
                      bottomRight: Radius.circular(14),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        kPrimary.withValues(alpha: .13),
                        kSurfaceHigh.withValues(alpha: .72),
                        kSecondary.withValues(alpha: .08),
                      ],
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: kPrimary.withValues(alpha: .22),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            titleSpacing: 12,
            title: _ExchangeRateHeader(store: store),
            actions: [
              IconButton(
                tooltip: tr('Sincronizar'),
                color: syncColor,
                disabledColor: syncColor,
                onPressed:
                    store.user == null || store.syncing ? null : store.syncNow,
                icon: store.syncing
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: syncColor,
                        ),
                      )
                    : const Icon(Icons.cloud_sync_outlined),
              ),
            ],
          ),
          body: AppBackground(
            child: SafeArea(
              child: Row(
                children: [
                  if (useDesktopNavigation)
                    _DesktopNavigationRail(
                      selectedIndex: index,
                      onDestinationSelected: (value) {
                        if (value == 1 && store.isReadOnly) {
                          toast(
                            context,
                            tr('Tu licencia no permite realizar cambios.'),
                          );
                          return;
                        }
                        if (value == 5) unawaited(store.loadReferrals());
                        setState(() => index = value);
                      },
                      profilePhotoUrl: _googleProfilePhotoUrl(store.user),
                    ),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: useDesktopNavigation ? 1120 : 980,
                        ),
                        child: Column(
                          children: [
                            if (store.isReadOnly)
                              _ReadOnlyLicenseBanner(store: store),
                            Expanded(child: screens[index]),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          floatingActionButton: index == 0 && store.canWrite
              ? Semantics(
                  button: true,
                  label: tr('Agregar nuevo registro'),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [kPrimary, kSecondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: kPrimary.withValues(alpha: .3),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: FloatingActionButton(
                      tooltip: tr('Agregar nuevo'),
                      heroTag: 'home-new-record',
                      elevation: 0,
                      backgroundColor: Colors.transparent,
                      foregroundColor: kBg,
                      onPressed: () => setState(() => index = 1),
                      child: const Icon(Icons.add_rounded, size: 32),
                    ),
                  ),
                )
              : null,
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          bottomNavigationBar: useDesktopNavigation
              ? null
              : _LiquidGlassNavigation(
                  selectedIndex: index,
                  onDestinationSelected: (value) {
                    if (value == 1 && store.isReadOnly) {
                      toast(
                        context,
                        tr('Tu licencia no permite realizar cambios.'),
                      );
                      return;
                    }
                    if (value == 5) unawaited(store.loadReferrals());
                    setState(() => index = value);
                  },
                  profilePhotoUrl: _googleProfilePhotoUrl(store.user),
                ),
        );
      },
    );
  }
}

class _DesktopNavigationRail extends StatelessWidget {
  const _DesktopNavigationRail({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.profilePhotoUrl,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final String? profilePhotoUrl;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: NavigationRail(
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
          extended: MediaQuery.sizeOf(context).width >= 1380,
          groupAlignment: 0,
          backgroundColor:
              Theme.of(context).colorScheme.surface.withValues(alpha: .82),
          indicatorColor: kPrimary.withValues(alpha: .18),
          selectedIconTheme: const IconThemeData(color: kPrimary),
          selectedLabelTextStyle: const TextStyle(
            color: kPrimary,
            fontWeight: FontWeight.w800,
          ),
          destinations: [
            NavigationRailDestination(
              icon: const Icon(Icons.dashboard_outlined),
              selectedIcon: const Icon(Icons.dashboard),
              label: Text(tr('Inicio')),
            ),
            NavigationRailDestination(
              icon: const Icon(Icons.add_circle_outline),
              selectedIcon: const Icon(Icons.add_circle),
              label: Text(tr('Nuevo')),
            ),
            NavigationRailDestination(
              icon: const Icon(Icons.history_outlined),
              selectedIcon: const Icon(Icons.history),
              label: Text(tr('Historial')),
            ),
            NavigationRailDestination(
              icon: const Icon(Icons.insights_outlined),
              selectedIcon: const Icon(Icons.insights),
              label: Text(tr('Estads.')),
            ),
            NavigationRailDestination(
              icon: const Icon(Icons.storefront_outlined),
              selectedIcon: const Icon(Icons.storefront),
              label: Text(tr('Tienda')),
            ),
            NavigationRailDestination(
              icon: profilePhotoUrl == null
                  ? const Icon(Icons.account_circle_outlined)
                  : _UserNavigationAvatar(
                      photoUrl: profilePhotoUrl!,
                      selected: false,
                    ),
              selectedIcon: profilePhotoUrl == null
                  ? const Icon(Icons.account_circle)
                  : _UserNavigationAvatar(
                      photoUrl: profilePhotoUrl!,
                      selected: true,
                    ),
              label: Text(tr('Usuario')),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyLicenseBanner extends StatelessWidget {
  const _ReadOnlyLicenseBanner({required this.store});

  final RecordStore store;

  @override
  Widget build(BuildContext context) {
    final license = store.license;
    final expiry = license.expiresAt ?? license.trialEndsAt;
    final paymentAction = store.paymentWhatsAppAction();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kDanger.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kDanger.withValues(alpha: .55)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline_rounded, color: kDanger),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(
                    'Tu licencia no permite realizar cambios. Puedes consultar tus datos en modo solo lectura.',
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '${tr('Estado')}: ${license.statusLabel}'
                  '${expiry == null ? '' : ' · ${tr('Vencimiento')}: ${DateFormat('d MMM yyyy', activeLanguage).format(expiry.toLocal())}'}',
                  style: const TextStyle(color: kMuted, fontSize: 12),
                ),
                if (license.requiresAdministrator && paymentAction != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    tr(
                      'Para renovar tu licencia o resolver cualquier problema, contáctanos por WhatsApp.',
                    ),
                    style: const TextStyle(
                      color: kDanger,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (paymentAction != null) ...[
                  const SizedBox(height: 10),
                  FilledButton.tonalIcon(
                    onPressed: () => _launchWhatsApp(context, paymentAction),
                    icon: const Icon(Icons.chat_outlined, size: 18),
                    label: Text(paymentAction.buttonText),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LiquidGlassNavigation extends StatelessWidget {
  const _LiquidGlassNavigation({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.profilePhotoUrl,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final String? profilePhotoUrl;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 34,
              offset: Offset(0, 16),
            ),
            BoxShadow(
              color: Color(0x182DD4A3),
              blurRadius: 24,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withValues(alpha: .13)),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: dark
                      ? [
                          Colors.white.withValues(alpha: .13),
                          const Color(0xD9142230),
                          const Color(0xE6081019),
                        ]
                      : [
                          Colors.white.withValues(alpha: .92),
                          const Color(0xDDE7F1FA),
                          const Color(0xEED8E7F3),
                        ],
                  stops: const [0, .42, 1],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 26,
                    right: 26,
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.white.withValues(alpha: .5),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  NavigationBar(
                    selectedIndex: selectedIndex,
                    onDestinationSelected: onDestinationSelected,
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    destinations: [
                      NavigationDestination(
                        icon: const Icon(Icons.dashboard_outlined),
                        selectedIcon: const Icon(Icons.dashboard),
                        label: tr('Inicio'),
                      ),
                      NavigationDestination(
                        icon: const Icon(Icons.add_circle_outline),
                        selectedIcon: const Icon(Icons.add_circle),
                        label: tr('Nuevo'),
                      ),
                      NavigationDestination(
                        icon: const Icon(Icons.history_outlined),
                        selectedIcon: const Icon(Icons.history),
                        label: tr('Historial'),
                      ),
                      NavigationDestination(
                        icon: const Icon(Icons.insights_outlined),
                        selectedIcon: const Icon(Icons.insights),
                        label: tr('Estads.'),
                      ),
                      NavigationDestination(
                        icon: const Icon(Icons.storefront_outlined),
                        selectedIcon: const Icon(Icons.storefront),
                        label: tr('Tienda'),
                      ),
                      NavigationDestination(
                        icon: profilePhotoUrl == null
                            ? const Icon(Icons.account_circle_outlined)
                            : _UserNavigationAvatar(
                                photoUrl: profilePhotoUrl!,
                                selected: false,
                              ),
                        selectedIcon: profilePhotoUrl == null
                            ? const Icon(Icons.account_circle)
                            : _UserNavigationAvatar(
                                photoUrl: profilePhotoUrl!,
                                selected: true,
                              ),
                        label: tr('Usuario'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UserNavigationAvatar extends StatelessWidget {
  const _UserNavigationAvatar({
    required this.photoUrl,
    required this.selected,
  });

  final String photoUrl;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 27,
      height: 27,
      padding: EdgeInsets.all(selected ? 2 : 1),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? kPrimary : kMuted,
          width: selected ? 2 : 1,
        ),
      ),
      child: ClipOval(
        child: Image.network(
          photoUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.account_circle_outlined, size: 22),
        ),
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({required this.store, super.key});

  final RecordStore store;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DateTime selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final metrics =
        Metrics(widget.store.records, widget.store.maintenanceRecords);
    final maintenance = MaintenanceSnapshot.from(
      records: widget.store.maintenanceRecords,
      intervalKm: widget.store.maintenanceIntervalKm,
      currentOdometer: metrics.latestOdometer,
    );
    final comparison = metrics.comparisonFor(selectedMonth);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        MetricHero(
          label: tr('Ingreso de hoy'),
          value: money(metrics.todayEarnings),
          sublabel:
              '${tr('Mes actual')}: ${money(metrics.currentCycleEarnings)}',
          icon: Icons.payments_outlined,
          trailing: const AppLogoMark(size: 90, transparent: true),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: MetricCard(
                  label: tr('Mes'),
                  value: metrics.currentCycle.label,
                  icon: Icons.route_outlined,
                  color: kTertiary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MetricCard(
                  label: tr('Distancia del mes'),
                  value: '${numFmt(metrics.currentCycleDistance)} km',
                  icon: Icons.route_outlined,
                  color: kSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: MetricCard(
                  label: tr('Ingresos históricos'),
                  value: money(metrics.totalEarnings),
                  icon: Icons.account_balance_wallet_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MetricCard(
                  label: tr('Eficiencia'),
                  value: '${numFmt(metrics.efficiency)} $activeCurrency/km',
                  icon: Icons.bolt_outlined,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: MetricCard(
                  label: tr('Gastos del mes'),
                  value: money(metrics.currentCycleExpenses),
                  icon: Icons.receipt_long_outlined,
                  color: kDanger,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MetricCard(
                  label: tr('Ganancia neta del mes'),
                  value: money(metrics.currentCycleNet),
                  icon: Icons.account_balance_outlined,
                  color: metrics.currentCycleNet >= 0 ? kPrimary : kDanger,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        MonthlyComparisonGauge(
          comparison: comparison,
          onPreviousMonth: () => setState(
            () => selectedMonth =
                DateTime(selectedMonth.year, selectedMonth.month - 1),
          ),
          onNextMonth: () => setState(
            () => selectedMonth =
                DateTime(selectedMonth.year, selectedMonth.month + 1),
          ),
          canGoNext: selectedMonth.isBefore(
            DateTime(DateTime.now().year, DateTime.now().month),
          ),
        ),
        const SizedBox(height: 14),
        MaintenanceDashboardCard(snapshot: maintenance),
        const SizedBox(height: 20),
        SectionTitle(title: tr('Hitos y mensajes')),
        DriverSystemMessages(
          metrics: metrics,
          maintenance: maintenance,
          comparison: comparison,
        ),
      ],
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    required this.store,
    super.key,
    this.record,
    this.onSaved,
  });

  final RecordStore store;
  final DailyRecord? record;
  final VoidCallback? onSaved;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

enum _NewRecordType { earnings, expense, maintenance }

class _RegisterScreenState extends State<RegisterScreen> {
  late DateTime date;
  late final TextEditingController earnings;
  late final TextEditingController expense;
  late final TextEditingController expenseCategory;
  late final TextEditingController odometer;
  late final TextEditingController battery;
  late final TextEditingController note;
  _NewRecordType recordType = _NewRecordType.earnings;

  @override
  void initState() {
    super.initState();
    final record = widget.record;
    date = record?.date ?? DateTime.now();
    earnings = TextEditingController(
        text: record == null ? '' : trimNum(record.earnings));
    expense = TextEditingController(
        text: record == null ? '' : trimNum(record.expense));
    expenseCategory =
        TextEditingController(text: record?.expenseCategory ?? '');
    odometer = TextEditingController(
        text: record == null ? '' : trimNum(record.odometer));
    battery = TextEditingController(
      text: record?.batteryVoltage == null
          ? ''
          : trimNum(record!.batteryVoltage!),
    );
    note = TextEditingController(text: record?.note ?? '');
    if ((record?.expense ?? 0) > 0) recordType = _NewRecordType.expense;
  }

  @override
  void dispose() {
    earnings.dispose();
    expense.dispose();
    expenseCategory.dispose();
    odometer.dispose();
    battery.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.record != null;
    final editingExpense = editing && widget.record!.expense > 0;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (editing) SectionTitle(title: tr('Editar registro')),
        if (!editing) ...[
          const SizedBox(height: 8),
          Text(
            tr('Selecciona qué dato vas a guardar.'),
            style: const TextStyle(color: kMuted),
          ),
          const SizedBox(height: 14),
          SegmentedButton<_NewRecordType>(
            segments: [
              ButtonSegment(
                value: _NewRecordType.earnings,
                icon: const Icon(Icons.payments_outlined),
                label: Text(tr('Ingreso')),
              ),
              ButtonSegment(
                value: _NewRecordType.expense,
                icon: const Icon(Icons.receipt_long_outlined),
                label: Text(tr('Gasto')),
              ),
              ButtonSegment(
                value: _NewRecordType.maintenance,
                icon: const Icon(Icons.build_outlined),
                label: Text(tr('Mant.')),
              ),
            ],
            selected: {recordType},
            showSelectedIcon: false,
            onSelectionChanged: (selection) =>
                setState(() => recordType = selection.first),
          ),
          const SizedBox(height: 18),
        ],
        if (!editing && recordType == _NewRecordType.maintenance) ...[
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Label(tr('Registrar mantenimiento')),
                const SizedBox(height: 8),
                Text(
                  tr('Guarda kilometraje, trabajo realizado, fecha, hora y costo.'),
                  style: const TextStyle(color: kMuted),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: widget.store.canWrite
                        ? () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => Scaffold(
                                  appBar: AppBar(
                                    title: Text(tr('Nuevo mantenimiento')),
                                  ),
                                  body: MaintenanceFormScreen(
                                    store: widget.store,
                                    onSaved: widget.onSaved,
                                  ),
                                ),
                              ),
                            )
                        : null,
                    icon: const Icon(Icons.add_task_outlined),
                    label: Text(tr('Completar mantenimiento')),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: pickDate,
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text(
                DateFormat('EEEE d MMMM yyyy', activeLanguage).format(date)),
          ),
          const SizedBox(height: 14),
          if ((editing && !editingExpense) ||
              recordType == _NewRecordType.earnings) ...[
            TextField(
              controller: earnings,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: tr('Ingreso del día'),
                suffixText: activeCurrency,
                prefixIcon: const Icon(Icons.payments_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: odometer,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: tr('Odómetro final (km, opcional)'),
                prefixIcon: const Icon(Icons.speed),
              ),
            ),
          ],
          if (editingExpense ||
              (!editing && recordType == _NewRecordType.expense)) ...[
            TextField(
              controller: expense,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: tr('Importe del gasto'),
                suffixText: activeCurrency,
                prefixIcon: const Icon(Icons.receipt_long_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: expenseCategory,
              decoration: InputDecoration(
                labelText: tr('Categoría del gasto'),
                prefixIcon: const Icon(Icons.sell_outlined),
              ),
            ),
          ],
          if ((editing && !editingExpense) ||
              recordType == _NewRecordType.earnings) ...[
            const SizedBox(height: 12),
            TextField(
              controller: battery,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: tr('Voltaje de batería'),
                suffixText: 'V',
                prefixIcon: const Icon(Icons.battery_charging_full_outlined),
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: note,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: tr('Nota opcional'),
              prefixIcon: const Icon(Icons.notes_outlined),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: widget.store.canWrite ? save : null,
            icon: const Icon(Icons.save_outlined),
            label: Text(
              editing
                  ? tr('Guardar cambios')
                  : recordType == _NewRecordType.expense
                      ? tr('Guardar gasto')
                      : tr('Guardar ingreso'),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (!mounted) return;
    if (picked != null) setState(() => date = picked);
  }

  Future<void> save() async {
    final isExpense = (editingRecord && widget.record!.expense > 0) ||
        (!editingRecord && recordType == _NewRecordType.expense);
    final earned = isExpense ? 0.0 : _parseOptionalNumber(earnings.text) ?? 0.0;
    final spent = isExpense ? _parseOptionalNumber(expense.text) ?? 0.0 : 0.0;
    final odo = isExpense ? 0.0 : _parseOptionalNumber(odometer.text) ?? 0.0;
    final batteryVoltage = _parseOptionalNumber(battery.text);
    if (earned < 0 || spent < 0 || odo < 0) {
      toast(context, tr('Ingreso, gasto y odometro no pueden ser negativos'));
      return;
    }
    if (earned == 0 &&
        spent == 0 &&
        odo == 0 &&
        batteryVoltage == null &&
        note.text.trim().isEmpty) {
      toast(context, tr('Agrega ingreso, gasto, odometro, carga o una nota'));
      return;
    }
    if (batteryVoltage != null && batteryVoltage < 0) {
      toast(context, tr('El voltaje no puede ser negativo'));
      return;
    }
    final base = widget.record;
    final saved = await _runLicensedWrite(
        context,
        () => widget.store.save(
              base == null
                  ? DailyRecord(
                      id: DateTime.now().microsecondsSinceEpoch.toString(),
                      date: date,
                      earnings: earned,
                      odometer: odo,
                      expense: spent,
                      expenseCategory: expenseCategory.text.trim(),
                      batteryVoltage: batteryVoltage,
                      note: note.text.trim(),
                    )
                  : DailyRecord(
                      id: base.id,
                      date: date,
                      earnings: earned,
                      odometer: odo,
                      expense: spent,
                      expenseCategory: expenseCategory.text.trim(),
                      batteryVoltage: batteryVoltage,
                      note: note.text.trim(),
                      createdAt: base.createdAt,
                      deviceId: base.deviceId,
                      schemaVersion: base.schemaVersion,
                    ),
            ));
    if (!saved) return;
    if (!mounted) return;
    toast(context, tr('Registro guardado'));
    if (base != null) {
      Navigator.pop(context);
    } else {
      widget.onSaved?.call();
    }
  }

  bool get editingRecord => widget.record != null;
}

enum _HistoryFilter { earnings, expense, maintenance }

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({required this.store, super.key});

  final RecordStore store;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final search = TextEditingController();
  _HistoryFilter filter = _HistoryFilter.earnings;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final term = search.text.trim().toLowerCase();
    final records = widget.store.records.where((record) {
      final matchesType =
          (filter == _HistoryFilter.earnings && record.expense <= 0) ||
              (filter == _HistoryFilter.expense && record.expense > 0);
      final haystack = '${record.note} ${numFmt(record.odometer)} '
              '${DateFormat('d MMM yyyy', activeLanguage).format(record.date)}'
          .toLowerCase();
      return matchesType && (term.isEmpty || haystack.contains(term));
    }).toList();
    final showMaintenance = filter == _HistoryFilter.expense ||
        filter == _HistoryFilter.maintenance;
    final maintenances = showMaintenance
        ? widget.store.maintenanceRecords.where((record) {
            final haystack = '${record.type} ${record.description} '
                    '${record.notes} ${numFmt(record.odometer)}'
                .toLowerCase();
            return term.isEmpty || haystack.contains(term);
          }).toList()
        : <MaintenanceRecord>[];
    final filterOptions = [
      (_HistoryFilter.earnings, Icons.payments_outlined, tr('Ingreso')),
      (_HistoryFilter.expense, Icons.receipt_long_outlined, tr('Gasto')),
      (_HistoryFilter.maintenance, Icons.build_outlined, tr('Mant.')),
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          tr('Cada cambio recalcula el inicio y las estadísticas.'),
          style: const TextStyle(color: kMuted),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: filterOptions
              .map(
                (option) => ChoiceChip(
                  avatar: Icon(option.$2, size: 17),
                  label: Text(option.$3),
                  selected: filter == option.$1,
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onSelected: (_) => setState(() => filter = option.$1),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: tr('Buscar por fecha, nota o km'),
            prefixIcon: const Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 16),
        if (records.isEmpty && maintenances.isEmpty)
          EmptyState(tr('Cuando guardes registros, apareceran aqui.'))
        else ...[
          ...records.map((record) => Dismissible(
                key: ValueKey(record.id),
                direction: widget.store.canWrite
                    ? DismissDirection.endToStart
                    : DismissDirection.none,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: kDanger.withValues(alpha: .25),
                  child: const Icon(Icons.delete_outline, color: kDanger),
                ),
                confirmDismiss: (_) => confirmDelete(context),
                onDismissed: (_) => unawaited(
                  _runLicensedWrite(
                    context,
                    () => widget.store.delete(record.id),
                  ),
                ),
                child: RecordTile(
                  record: record,
                  onTap: widget.store.canWrite
                      ? () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => Scaffold(
                                appBar:
                                    AppBar(title: Text(tr('Editar registro'))),
                                body: RegisterScreen(
                                  store: widget.store,
                                  record: record,
                                ),
                              ),
                            ),
                          )
                      : null,
                ),
              )),
          ...maintenances.map((record) => GlassCard(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.build_outlined, color: kPrimary),
                  title: Text(record.type),
                  subtitle: Text(
                    '${DateFormat('d MMM yyyy, HH:mm', activeLanguage).format(record.dateTime)} · ${numFmt(record.odometer)} km · ${money(record.cost ?? 0)}\n${record.description}',
                  ),
                  isThreeLine: true,
                  trailing: widget.store.canWrite
                      ? const Icon(Icons.chevron_right)
                      : const Icon(Icons.lock_outline, color: kMuted),
                  onTap: widget.store.canWrite
                      ? () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => Scaffold(
                                appBar: AppBar(
                                  title: Text(tr('Editar mantenimiento')),
                                ),
                                body: MaintenanceFormScreen(
                                  store: widget.store,
                                  record: record,
                                ),
                              ),
                            ),
                          )
                      : null,
                ),
              )),
        ],
      ],
    );
  }

  Future<bool> confirmDelete(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(tr('Eliminar registro')),
            content: Text(tr('Esto cambiara todos los calculos derivados.')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(tr('Cancelar')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(tr('Eliminar')),
              ),
            ],
          ),
        ) ??
        false;
  }
}

class StatsScreen extends StatelessWidget {
  const StatsScreen({required this.store, super.key});

  final RecordStore store;

  @override
  Widget build(BuildContext context) {
    final metrics = Metrics(store.records, store.maintenanceRecords);
    final earningRecords = store.records
        .where((record) => record.earnings > 0)
        .toList()
      ..sort((a, b) => b.earnings.compareTo(a.earnings));
    final cycles = metrics.cycleSummaries;
    final bestCycle = cycles.isEmpty
        ? null
        : cycles.reduce((a, b) => a.earnings >= b.earnings ? a : b);
    final maintenance = MaintenanceSnapshot.from(
      records: store.maintenanceRecords,
      intervalKm: store.maintenanceIntervalKm,
      currentOdometer: metrics.latestOdometer,
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth >= 700
                ? (constraints.maxWidth - 24) / 3
                : (constraints.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                StatOverviewCard(
                    width: width,
                    label: tr('Ingresos totales'),
                    value: money(metrics.totalEarnings)),
                StatOverviewCard(
                    width: width,
                    label: tr('Gastos totales'),
                    value: money(metrics.totalExpenses),
                    color: kDanger),
                StatOverviewCard(
                    width: width,
                    label: tr('Ganancia neta'),
                    value: money(metrics.netEarnings),
                    color: metrics.netEarnings >= 0 ? kPrimary : kDanger),
                StatOverviewCard(
                    width: width,
                    label: tr('Ingreso promedio por día trabajado'),
                    value: money(metrics.averageDailyEarnings)),
                StatOverviewCard(
                    width: width,
                    label: tr('Eficiencia'),
                    value: '${numFmt(metrics.efficiency)} $activeCurrency/km'),
                StatOverviewCard(
                  width: width,
                  label: tr('Mejor día'),
                  value: earningRecords.isEmpty
                      ? '-'
                      : money(earningRecords.first.earnings),
                  note: earningRecords.isEmpty
                      ? tr('Sin datos')
                      : DateFormat('d MMM yyyy', activeLanguage)
                          .format(earningRecords.first.date),
                ),
                StatOverviewCard(
                  width: width,
                  label: tr('Mejor mes'),
                  value: bestCycle == null ? '-' : money(bestCycle.earnings),
                  note: bestCycle?.label ?? tr('Sin datos mensuales'),
                ),
                StatOverviewCard(
                  width: width,
                  label: tr('Mantenimiento'),
                  value: tr(maintenance.status),
                  note: maintenance.remainingKm < 0
                      ? '${tr('Vencido por')} ${numFmt(maintenance.remainingKm.abs())} km'
                      : '${tr('Próximo en')} ${numFmt(maintenance.remainingKm)} km',
                  color: maintenance.color,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        SectionTitle(title: tr('Ingresos y gastos por mes')),
        MonthlyEarningsBars(cycles: cycles),
        const SizedBox(height: 18),
        SectionTitle(title: tr('Tendencia de días trabajados')),
        EarningsTrendCard(records: earningRecords.take(10).toList().reversed),
        const SizedBox(height: 18),
        SectionTitle(title: tr('Información relevante')),
        DataHealthCard(metrics: metrics),
      ],
    );
  }
}

Uri buildRevolicoSearchUri(String term) => Uri.https(
      'www.revolico.com',
      '/search',
      {'q': term.trim(), 'order': 'relevance'},
    );

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  final search = TextEditingController();

  static const categories = <_StoreCategory>[
    _StoreCategory('Baterías', 'batería 72V', Icons.battery_charging_full),
    _StoreCategory('Cargadores', 'cargador 72V', Icons.electrical_services),
    _StoreCategory('Neumáticos', 'neumático triciclo', Icons.tire_repair),
    _StoreCategory('Motores', 'motor eléctrico', Icons.electric_bolt),
    _StoreCategory(
      'Controladores',
      'controlador moto eléctrica',
      Icons.memory,
    ),
    _StoreCategory(
      'Piezas eléctricas',
      'piezas eléctricas triciclo',
      Icons.cable,
    ),
    _StoreCategory(
      'Repuestos mecánicos',
      'repuestos triciclo',
      Icons.settings,
    ),
    _StoreCategory(
      'Luces y accesorios',
      'luces accesorios triciclo',
      Icons.lightbulb_outline,
    ),
    _StoreCategory('Herramientas', 'herramientas taller moto', Icons.handyman),
    _StoreCategory(
      'Triciclos eléctricos',
      'triciclo eléctrico',
      Icons.electric_rickshaw,
    ),
    _StoreCategory(
      'Talleres y reparación',
      'taller moto eléctrica',
      Icons.home_repair_service,
    ),
  ];

  static const quickSearches = <String>[
    'batería 72V',
    'batería litio triciclo',
    'batería gel',
    'cargador 72V',
    'neumático triciclo',
    'motor eléctrico',
    'controlador moto eléctrica',
    'repuestos triciclo',
    'taller moto eléctrica',
  ];

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          tr('Encuentra piezas, accesorios y servicios para tu vehículo.'),
          style: const TextStyle(color: kMuted, height: 1.4),
        ),
        const SizedBox(height: 14),
        GlassCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.open_in_new_rounded, color: kTertiary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  tr('Las búsquedas se abren externamente en Revolico. TukTuk Control no copia ni almacena anuncios.'),
                  style: const TextStyle(color: kMuted, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SectionTitle(title: tr('Buscar en Revolico')),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: search,
                textInputAction: TextInputAction.search,
                onSubmitted: openSearch,
                decoration: InputDecoration(
                  hintText: tr('¿Qué necesitas para tu vehículo?'),
                  prefixIcon: const Icon(Icons.search),
                ),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: () => openSearch(search.text),
              style: FilledButton.styleFrom(
                minimumSize: const Size(54, 54),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Icon(Icons.open_in_new_rounded),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SectionTitle(title: tr('Categorías')),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 720 ? 3 : 2;
            final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final category in categories)
                  SizedBox(
                    width: width,
                    child: _StoreCategoryCard(
                      category: category,
                      onTap: () => openSearch(category.query),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        SectionTitle(title: tr('Búsquedas rápidas')),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final term in quickSearches)
              ActionChip(
                avatar: const Icon(Icons.north_east_rounded, size: 16),
                label: Text(term),
                onPressed: () => openSearch(term),
              ),
          ],
        ),
        const SizedBox(height: 110),
      ],
    );
  }

  Future<void> openSearch(String value) async {
    final term = value.trim();
    if (term.isEmpty) {
      toast(context, tr('Escribe lo que deseas buscar'));
      return;
    }
    final opened = await launchUrl(
      buildRevolicoSearchUri(term),
      mode:
          kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
    if (!opened && mounted) {
      toast(context, tr('No se pudo abrir el navegador'));
    }
  }
}

class _StoreCategory {
  const _StoreCategory(this.label, this.query, this.icon);

  final String label;
  final String query;
  final IconData icon;
}

class _StoreCategoryCard extends StatelessWidget {
  const _StoreCategoryCard({required this.category, required this.onTap});

  final _StoreCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 126,
      child: GlassCard(
        padding: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(category.icon, color: kPrimary, size: 25),
                const SizedBox(height: 12),
                Text(
                  tr(category.label),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const Spacer(),
                Text(
                  tr('Abrir búsqueda'),
                  style: const TextStyle(color: kMuted, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({required this.store, super.key});

  final RecordStore store;

  @override
  Widget build(BuildContext context) {
    final user = store.user;
    final photoUrl = _googleProfilePhotoUrl(user);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: kPrimary.withValues(alpha: .16),
                    backgroundImage:
                        photoUrl == null ? null : NetworkImage(photoUrl),
                    child: photoUrl == null
                        ? Icon(
                            user == null ? Icons.person_outline : Icons.person,
                            color: kPrimary,
                            size: 34,
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Label(tr('Cuenta de usuario')),
                        const SizedBox(height: 5),
                        Text(
                          store.profileDisplayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user == null
                              ? tr(
                                  'Sin cuenta Google vinculada · Guardado local')
                              : user.email ?? '',
                          style: TextStyle(
                            color: user == null ? kMuted : kPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: tr('Personalizar perfil'),
                    onPressed:
                        store.canWrite ? () => _editProfileName(context) : null,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Label(tr('Google y respaldo')),
              const SizedBox(height: 12),
              ..._googleBackupChildren(context),
            ],
          ),
        ),
        const SizedBox(height: 18),
        VehicleSettingsPanel(store: store),
        const SizedBox(height: 18),
        _SupportAndPaymentsCard(
          supportAction: store.supportWhatsAppAction(),
          paymentAction: store.paymentWhatsAppAction(),
          onTap: (action) => _launchWhatsApp(context, action),
        ),
        const SizedBox(height: 18),
        _ReferralCard(store: store),
        const SizedBox(height: 18),
        AppPreferencesPanel(store: store),
      ],
    );
  }

  List<Widget> _googleBackupChildren(BuildContext context) {
    final user = store.user;
    return [
      Row(
        children: [
          Icon(
            user == null ? Icons.cloud_off_outlined : Icons.cloud_done_outlined,
            color: user == null ? kMuted : kPrimary,
            size: 28,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              user == null ? tr('No conectado') : user.email ?? '',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        user == null
            ? tr(
                'Conecta Google para sincronizar tus datos de forma segura y recuperarlos al reinstalar.')
            : tr(store.syncMessage),
        style: const TextStyle(color: kMuted),
      ),
      const SizedBox(height: 8),
      Text(
        '${store.pendingSyncCount} ${tr('cambios locales pendientes de sincronizacion')}',
        style: const TextStyle(color: kMuted, fontSize: 12),
      ),
      if (store.lastSyncAt != null) ...[
        const SizedBox(height: 8),
        Text(
          '${tr('Ultima sincronizacion')}: ${DateFormat('d MMM, HH:mm', activeLanguage).format(store.lastSyncAt!)}',
          style: const TextStyle(color: kMuted, fontSize: 12),
        ),
      ],
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: store.syncing
            ? null
            : user == null
                ? store.signIn
                : store.syncNow,
        icon: Icon(user == null ? Icons.login : Icons.cloud_sync_outlined),
        label: Text(
          user == null ? tr('Entrar con Google') : tr('Respaldar ahora'),
        ),
      ),
      if (user != null) ...[
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: store.syncing ? null : store.restoreThenSync,
          icon: const Icon(Icons.restore_outlined),
          label: Text(tr('Recuperar desde Drive')),
        ),
        TextButton.icon(
          onPressed: store.signOut,
          icon: const Icon(Icons.logout),
          label: Text(tr('Cerrar sesion')),
        ),
      ],
      const SizedBox(height: 12),
      const Divider(color: kOutline),
      const SizedBox(height: 8),
      Label(tr('Respaldo local')),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: () => _copyBackup(context, csv: false),
            icon: const Icon(Icons.data_object_outlined),
            label: Text(tr('Exportar JSON')),
          ),
          OutlinedButton.icon(
            onPressed: () => _copyBackup(context, csv: true),
            icon: const Icon(Icons.table_view_outlined),
            label: Text(tr('Exportar CSV')),
          ),
          OutlinedButton.icon(
            onPressed: store.canWrite ? () => _restoreBackup(context) : null,
            icon: const Icon(Icons.upload_file_outlined),
            label: Text(tr('Restaurar JSON')),
          ),
        ],
      ),
    ];
  }

  Future<void> _editProfileName(BuildContext context) async {
    final controller = TextEditingController(text: store.profileDisplayName);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Personalizar perfil')),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          decoration: InputDecoration(
            labelText: tr('Nombre de usuario'),
            prefixIcon: const Icon(Icons.person_outline),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('Cancelar')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(tr('Guardar')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null && context.mounted) {
      await _runLicensedWrite(
        context,
        () => store.setProfileDisplayName(value),
      );
    }
  }

  Future<void> _copyBackup(BuildContext context, {required bool csv}) async {
    final value = csv ? store.exportBackupCsv() : store.exportBackupJson();
    await Clipboard.setData(ClipboardData(text: value));
    if (context.mounted) {
      toast(context, tr(csv ? 'CSV copiado al portapapeles' : 'JSON copiado'));
    }
  }

  Future<void> _restoreBackup(BuildContext context) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Restaurar respaldo JSON')),
        content: TextField(
          controller: controller,
          minLines: 6,
          maxLines: 12,
          decoration: InputDecoration(
            hintText: tr('Pega aquí el contenido del respaldo JSON'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('Cancelar')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(tr('Restaurar')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.trim().isEmpty) return;
    if (!context.mounted) return;
    try {
      final restored = await _runLicensedWrite(
        context,
        () => store.restoreBackupJson(value),
      );
      if (!restored) return;
      if (context.mounted) toast(context, tr('Respaldo restaurado'));
    } catch (_) {
      if (context.mounted) toast(context, tr('El respaldo JSON no es válido'));
    }
  }
}

class _SupportAndPaymentsCard extends StatelessWidget {
  const _SupportAndPaymentsCard({
    required this.supportAction,
    required this.paymentAction,
    required this.onTap,
  });

  final WhatsAppContactAction? supportAction;
  final WhatsAppContactAction? paymentAction;
  final ValueChanged<WhatsAppContactAction> onTap;

  @override
  Widget build(BuildContext context) {
    if (supportAction == null && paymentAction == null) {
      return const SizedBox.shrink();
    }
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.support_agent_rounded,
                color: kPrimary,
                size: 34,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  tr('Soporte y pagos'),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          if (supportAction != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => onTap(supportAction!),
                icon: const Icon(Icons.support_agent_rounded, size: 19),
                label: Text(supportAction!.buttonText),
              ),
            ),
          ],
          if (paymentAction != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => onTap(paymentAction!),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF25D366),
                ),
                icon: const Icon(Icons.payments_outlined, size: 19),
                label: Text(paymentAction!.buttonText),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> _launchWhatsApp(
  BuildContext context,
  WhatsAppContactAction action,
) async {
  final opened = await launchUrl(
    action.uri,
    mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
    webOnlyWindowName: '_blank',
  );
  if (!opened && context.mounted) {
    toast(context, tr('No se pudo abrir WhatsApp'));
  }
}

class _ReferralCard extends StatelessWidget {
  const _ReferralCard({required this.store});

  final RecordStore store;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xFF102D2B), Color(0xFF0C201F)]
              : const [Color(0xFFE5F7F2), Color(0xFFF2FBF8)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: dark ? const Color(0xFF2A7067) : const Color(0xFF75BEB0),
        ),
        boxShadow: dark
            ? const [
                BoxShadow(
                  color: Color(0x2400CFA0),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ]
            : const [
                BoxShadow(
                  color: Color(0x16006E60),
                  blurRadius: 14,
                  offset: Offset(0, 6),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: dark
                      ? const Color(0x332DD4A3)
                      : const Color(0x292A9D83),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: dark
                        ? const Color(0x664ED9B5)
                        : const Color(0x6675BEB0),
                  ),
                ),
                child: const Icon(
                  Icons.card_giftcard_rounded,
                  color: Color(0xFF58E0BA),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Invita amigos y paga menos',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: dark ? kText : const Color(0xFF123D37),
                        fontSize: 17,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Gana 15 días gratis por cada referido.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: dark
                            ? const Color(0xFF8DE5CE)
                            : const Color(0xFF287C6C),
                        fontSize: 13,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (store.user == null) ...[
            const Text(
              'Inicia sesión con Google para obtener tu enlace personal, invitar conductores y consultar tus recompensas.',
              style: TextStyle(color: kMuted, height: 1.4),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: store.signIn,
              icon: const Icon(Icons.login),
              label: const Text('Entrar con Google'),
            ),
          ] else
            ..._authenticatedContent(context),
        ],
      ),
    );
  }

  List<Widget> _authenticatedContent(BuildContext context) {
    if (store.referralLoadState == ReferralLoadState.loading ||
        store.referralLoadState == ReferralLoadState.idle) {
      return const [
        Center(
          child: Padding(
            padding: EdgeInsets.all(18),
            child: CircularProgressIndicator(),
          ),
        ),
      ];
    }
    if (store.referralLoadState == ReferralLoadState.error) {
      return [
        Text(
          store.referralError ?? 'No se pudo cargar el programa de referidos.',
          style: const TextStyle(color: kMuted),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => store.loadReferrals(force: true),
          icon: const Icon(Icons.refresh),
          label: const Text('Reintentar'),
        ),
      ];
    }

    final program = store.referralProgram;
    if (program == null || !program.enabled) {
      return const [
        Text(
          'No hay una campaña de referidos activa en este momento.',
          style: TextStyle(color: kMuted),
        ),
      ];
    }

    final link = program.link;
    return [
      if (program.campaignName != null) ...[
        Text(
          program.campaignName!,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 5),
      ],
      Text(
        referralQualificationLabel(program.qualificationMode),
        style: const TextStyle(color: kMuted),
      ),
      const SizedBox(height: 4),
      Text(
        'Gana ${program.rewardDays} días por cada referido',
        style: const TextStyle(color: kPrimary, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 14),
      _ReferralValue(label: 'Tu código', value: program.code ?? '—'),
      const SizedBox(height: 8),
      _ReferralValue(label: 'Tu enlace', value: link ?? '—'),
      if (link != null) ...[
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => _copyLink(context, link),
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Copiar enlace'),
            ),
            FilledButton.tonalIcon(
              onPressed: () => _shareLink(context, link),
              icon: const Icon(Icons.share_outlined, size: 18),
              label: const Text('Compartir'),
            ),
          ],
        ),
      ],
      if (store.referralClaimNeedsRetry) ...[
        const SizedBox(height: 12),
        const Text(
          'No se pudo verificar el código recibido. Puedes reintentarlo.',
          style: TextStyle(color: kTertiary, fontSize: 12),
        ),
        TextButton.icon(
          onPressed: store.retryPendingReferralClaim,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Reintentar código'),
        ),
      ],
      const SizedBox(height: 16),
      Container(
        decoration: BoxDecoration(
          border: Border.all(color: kOutline),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            _ReferralMetric(
              label: 'Invitados',
              value: '${program.referredCount}',
            ),
            const _ReferralDivider(),
            _ReferralMetric(
              label: 'Cumplieron',
              value: '${program.qualifiedCount}',
            ),
            const _ReferralDivider(),
            _ReferralMetric(
              label: 'Días obtenidos',
              value: '${program.earnedDays}',
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      Text(
        'Recompensas obtenidas: ${program.earnedRewards} · Aplicadas: ${program.appliedRewards} · Días aplicados: ${program.appliedDays}',
        style: const TextStyle(color: kMuted, fontSize: 12),
      ),
      const SizedBox(height: 18),
      Row(
        children: [
          const Expanded(
            child: Text(
              'Mis referidos',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ),
          IconButton(
            tooltip: 'Actualizar',
            onPressed: () => store.loadReferrals(force: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      if (store.referrals.isEmpty)
        const Text(
          'Todavía no tienes referidos.',
          style: TextStyle(color: kMuted),
        )
      else
        ...store.referrals.map(_ReferralEntryTile.new),
    ];
  }

  Future<void> _copyLink(BuildContext context, String link) async {
    await Clipboard.setData(ClipboardData(text: link));
    if (context.mounted) toast(context, 'Enlace copiado');
  }

  Future<void> _shareLink(BuildContext context, String link) async {
    final shared = await shareReferralLink(
      title: 'TukTuk Control',
      text: 'Únete a TukTuk Control con mi invitación.',
      url: link,
    );
    if (!shared && context.mounted) await _copyLink(context, link);
  }
}

class _ReferralValue extends StatelessWidget {
  const _ReferralValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kSurface.withValues(alpha: .42),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kOutline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: kMuted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          SelectableText(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _ReferralEntryTile extends StatelessWidget {
  const _ReferralEntryTile(this.entry);

  final ReferralEntry entry;

  @override
  Widget build(BuildContext context) {
    final createdAt = entry.createdAt;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kSurface.withValues(alpha: .35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kOutline),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0x222DD4A3),
            child: Icon(Icons.person_outline, color: kPrimary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  '${referralEntryStatusLabel(entry.status)}'
                  '${createdAt == null ? '' : ' · ${DateFormat('d MMM yyyy', activeLanguage).format(createdAt.toLocal())}'}',
                  style: const TextStyle(color: kMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          if (entry.rewardDays > 0)
            Text(
              '+${entry.rewardDays} días',
              style: const TextStyle(
                color: kPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
        ],
      ),
    );
  }
}

// Kept temporarily as a visual migration reference; it is never rendered.
// ignore: unused_element
class _ReferralPreviewCardLegacy extends StatelessWidget {
  const _ReferralPreviewCardLegacy();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xFF35191E), Color(0xFF21151B)]
              : const [Color(0xFFFFE9EA), Color(0xFFFFF4F3)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: dark ? const Color(0xFF713640) : const Color(0xFFE8A5AA),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9F3340).withValues(alpha: dark ? .18 : .10),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: kPrimary.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.card_giftcard_rounded,
                  color: kPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          tr('Referidos'),
                          style: const TextStyle(
                            color: kPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: kTertiary.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            tr('Próximamente'),
                            style: const TextStyle(
                              color: kTertiary,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tr('Invita a otros conductores y gana días adicionales.'),
                      style: const TextStyle(color: kMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: kOutline),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                _ReferralMetric(
                  label: tr('Tu código'),
                  value: 'TUK-DEMO',
                ),
                const _ReferralDivider(),
                _ReferralMetric(
                  label: tr('Referidos'),
                  value: '0',
                ),
                const _ReferralDivider(),
                _ReferralMetric(
                  label: tr('Días acumulados'),
                  value: '0',
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Semantics(
            button: true,
            enabled: false,
            label: tr('Compartir mi código'),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFFB44752).withValues(alpha: .14),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFD65A66).withValues(alpha: .55),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.share_outlined,
                    color: Color(0xFFFF7B86),
                    size: 19,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    tr('Compartir mi código'),
                    style: const TextStyle(
                      color: Color(0xFFFF7B86),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferralMetric extends StatelessWidget {
  const _ReferralMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        child: Column(
          children: [
            Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: kMuted,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: kPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReferralDivider extends StatelessWidget {
  const _ReferralDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 54, color: kOutline);
  }
}

class AppPreferencesPanel extends StatefulWidget {
  const AppPreferencesPanel({required this.store, super.key});

  final RecordStore store;

  @override
  State<AppPreferencesPanel> createState() => _AppPreferencesPanelState();
}

class _AppPreferencesPanelState extends State<AppPreferencesPanel> {
  late String currency = widget.store.preferredCurrency;
  late String language = widget.store.preferredLanguage;
  late String theme = widget.store.preferredTheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(title: tr('Ajustes')),
        GlassCard(
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                initialValue: currency,
                decoration: InputDecoration(
                  labelText: tr('Moneda de trabajo'),
                  prefixIcon: const Icon(Icons.currency_exchange),
                ),
                items: [
                  DropdownMenuItem(
                      value: 'CUP', child: Text('CUP · ${tr('Peso cubano')}')),
                  DropdownMenuItem(
                      value: 'USD',
                      child: Text('USD · ${tr('Dólar estadounidense')}')),
                  DropdownMenuItem(
                      value: 'EUR', child: Text('EUR · ${tr('Euro')}')),
                  DropdownMenuItem(
                      value: 'MXN',
                      child: Text('MXN · ${tr('Peso mexicano')}')),
                ],
                onChanged: (value) => setState(() => currency = value ?? 'CUP'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: language,
                decoration: InputDecoration(
                  labelText: tr('Idioma'),
                  prefixIcon: const Icon(Icons.language_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'es', child: Text('Español')),
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(value: 'pt', child: Text('Português')),
                  DropdownMenuItem(value: 'fr', child: Text('Français')),
                ],
                onChanged: (value) => setState(() => language = value ?? 'es'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: theme,
                decoration: InputDecoration(
                  labelText: tr('Modo visual'),
                  prefixIcon: const Icon(Icons.contrast_outlined),
                ),
                items: [
                  DropdownMenuItem(
                      value: 'system', child: Text(tr('Predeterminado'))),
                  DropdownMenuItem(value: 'dark', child: Text(tr('Oscuro'))),
                  DropdownMenuItem(value: 'light', child: Text(tr('Claro'))),
                ],
                onChanged: (value) => setState(() => theme = value ?? 'system'),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: widget.store.canWrite
                      ? () async {
                          final saved = await _runLicensedWrite(
                            context,
                            () => widget.store.savePreferences(
                              currency: currency,
                              language: language,
                              theme: theme,
                            ),
                          );
                          if (saved && context.mounted) {
                            toast(context, tr('Ajustes guardados'));
                          }
                        }
                      : null,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(tr('Guardar ajustes')),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class VehicleSettingsPanel extends StatefulWidget {
  const VehicleSettingsPanel({required this.store, super.key});

  final RecordStore store;

  @override
  State<VehicleSettingsPanel> createState() => _VehicleSettingsPanelState();
}

class _VehicleSettingsPanelState extends State<VehicleSettingsPanel> {
  late final TextEditingController name;
  late final TextEditingController interval;
  late final TextEditingController registration;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final vehicle = widget.store.activeVehicle;
    name = TextEditingController(text: vehicle?.name ?? '');
    interval = TextEditingController(
      text: trimNum(widget.store.maintenanceIntervalKm),
    );
    registration = TextEditingController(text: vehicle?.registration ?? '');
  }

  @override
  void didUpdateWidget(covariant VehicleSettingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final vehicle = widget.store.activeVehicle;
    if (vehicle != null && name.text.isEmpty) name.text = vehicle.name;
    final currentInterval = trimNum(widget.store.maintenanceIntervalKm);
    if (interval.text != currentInterval) interval.text = currentInterval;
  }

  @override
  void dispose() {
    name.dispose();
    interval.dispose();
    registration.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (name.text.trim().isEmpty) return;
    final intervalKm = _parseOptionalNumber(interval.text);
    if (intervalKm == null || intervalKm <= 0) {
      toast(context, tr('El intervalo debe ser mayor que 0'));
      return;
    }
    setState(() => saving = true);
    final saved = await _runLicensedWrite(context, () async {
      await widget.store.updateActiveVehicle(
        name: name.text,
        registration: registration.text,
      );
      await widget.store.setMaintenanceInterval(intervalKm);
    });
    if (!saved) {
      if (mounted) setState(() => saving = false);
      return;
    }
    if (mounted) {
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Vehiculo actualizado'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = widget.store.activeVehicle;
    if (vehicle == null) return const SizedBox.shrink();
    final shortId = vehicle.id.length <= 18
        ? vehicle.id
        : '${vehicle.id.substring(0, 8)}…${vehicle.id.substring(vehicle.id.length - 6)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(title: tr('Vehiculo activo')),
        GlassCard(
          child: Column(
            children: [
              TextField(
                controller: name,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: tr('Nombre del vehiculo'),
                  prefixIcon: const Icon(Icons.electric_rickshaw),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: interval,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: tr('Intervalo de mantenimiento (km)'),
                  prefixIcon: const Icon(Icons.settings_suggest_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: registration,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: tr('Matricula o identificador'),
                  prefixIcon: const Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      tr('ID interno'),
                      style: const TextStyle(color: kMuted, fontSize: 12),
                    ),
                  ),
                  Tooltip(
                    message: vehicle.id,
                    child: Text(
                      shortId,
                      style: const TextStyle(
                        color: kMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        fontFeatures: [ui.FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: saving || !widget.store.canWrite ? null : save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(tr('Guardar vehiculo')),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class MaintenanceFormScreen extends StatefulWidget {
  const MaintenanceFormScreen({
    required this.store,
    super.key,
    this.record,
    this.onSaved,
  });

  final RecordStore store;
  final MaintenanceRecord? record;
  final VoidCallback? onSaved;

  @override
  State<MaintenanceFormScreen> createState() => _MaintenanceFormScreenState();
}

class _MaintenanceFormScreenState extends State<MaintenanceFormScreen> {
  DateTime date = DateTime.now();
  TimeOfDay time = TimeOfDay.now();
  late final TextEditingController odometer;
  late final TextEditingController type;
  late final TextEditingController description;
  late final TextEditingController cost;
  late final TextEditingController notes;

  @override
  void initState() {
    super.initState();
    final record = widget.record;
    if (record != null) {
      date = record.dateTime;
      time = TimeOfDay.fromDateTime(record.dateTime);
    }
    odometer = TextEditingController(
      text: record == null ? '' : trimNum(record.odometer),
    );
    type = TextEditingController(text: record?.type ?? 'General');
    description = TextEditingController(text: record?.description ?? '');
    final initialCost = record?.cost;
    cost = TextEditingController(
      text: initialCost == null ? '' : trimNum(initialCost),
    );
    notes = TextEditingController(text: record?.notes ?? '');
  }

  @override
  void dispose() {
    odometer.dispose();
    type.dispose();
    description.dispose();
    cost.dispose();
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionTitle(
          title: tr(widget.record == null
              ? 'Registrar mantenimiento'
              : 'Editar mantenimiento'),
        ),
        FilledButton.tonalIcon(
          onPressed: pickDate,
          icon: const Icon(Icons.calendar_month_outlined),
          label:
              Text(DateFormat('EEEE d MMMM yyyy', activeLanguage).format(date)),
        ),
        const SizedBox(height: 10),
        FilledButton.tonalIcon(
          onPressed: pickTime,
          icon: const Icon(Icons.schedule_outlined),
          label: Text(time.format(context)),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: odometer,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: tr('Kilometraje del mantenimiento'),
            prefixIcon: const Icon(Icons.speed),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: type,
          decoration: InputDecoration(
            labelText: tr('Tipo de mantenimiento'),
            prefixIcon: const Icon(Icons.category_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: description,
          minLines: 2,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: tr('Descripcion'),
            prefixIcon: const Icon(Icons.description_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: cost,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: tr('Costo opcional'),
            prefixIcon: const Icon(Icons.payments_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: notes,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: tr('Observaciones'),
            prefixIcon: const Icon(Icons.notes_outlined),
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: widget.store.canWrite ? save : null,
          icon: const Icon(Icons.save_outlined),
          label: Text(tr('Guardar mantenimiento')),
        ),
      ],
    );
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (!mounted) return;
    if (picked != null) setState(() => date = picked);
  }

  Future<void> pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: time,
    );
    if (!mounted) return;
    if (picked != null) setState(() => time = picked);
  }

  Future<void> save() async {
    final odo = double.tryParse(odometer.text.replaceAll(',', '.'));
    final parsedCost = _parseOptionalNumber(cost.text);
    if (odo == null || odo <= 0) {
      toast(context, tr('El kilometraje debe ser valido'));
      return;
    }
    if (type.text.trim().isEmpty || description.text.trim().isEmpty) {
      toast(context, tr('Faltan tipo o descripcion'));
      return;
    }
    if (cost.text.trim().isNotEmpty && parsedCost == null) {
      toast(context, tr('El costo no es valido'));
      return;
    }
    final saved = await _runLicensedWrite(
      context,
      () => widget.store.saveMaintenance(MaintenanceRecord(
        id: widget.record?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        dateTime:
            DateTime(date.year, date.month, date.day, time.hour, time.minute),
        odometer: odo,
        type: type.text.trim(),
        description: description.text.trim(),
        cost: parsedCost,
        notes: notes.text.trim(),
        createdAt: widget.record?.createdAt,
        deviceId: widget.record?.deviceId ?? '',
        schemaVersion: widget.record?.schemaVersion ?? _databaseSchemaVersion,
      )),
    );
    if (!saved) return;
    if (!mounted) return;
    toast(context, tr('Mantenimiento guardado'));
    Navigator.pop(context);
    if (widget.record == null) widget.onSaved?.call();
  }
}
