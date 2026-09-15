part of '../main.dart';

class MarketplaceRecordsScreen extends StatelessWidget {
  const MarketplaceRecordsScreen({
    required this.store,
    super.key,
  });

  final RecordStore store;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: store.isReadOnly ? 1 : 0,
      child: Builder(
        builder: (tabContext) => Column(
          children: [
            const SizedBox(height: 8),
            TabBar(
              tabs: [
                Tab(
                  icon: const Icon(Icons.add_circle_outline),
                  text: tr('Nuevo'),
                ),
                Tab(
                  icon: const Icon(Icons.history_outlined),
                  text: tr('Historial'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Expanded(
              child: TabBarView(
                children: [
                  RegisterScreen(
                    store: store,
                    onSaved: () =>
                        DefaultTabController.of(tabContext).animateTo(1),
                  ),
                  HistoryScreen(store: store),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MarketplaceJobsScreen extends StatelessWidget {
  const MarketplaceJobsScreen({
    required this.store,
    super.key,
  });

  final RecordStore store;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          const SizedBox(height: 8),
          TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: tr('Disponibles')),
              Tab(text: tr('Activos')),
              Tab(text: tr('Programados')),
              Tab(text: tr('Historial')),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: TabBarView(
              children: [
                _MarketplaceJobsPlaceholder(
                  icon: Icons.work_outline_rounded,
                  title: tr('Trabajos disponibles'),
                  message: tr(
                    'Aquí aparecerán las solicitudes que puedes aceptar.',
                  ),
                ),
                _MarketplaceJobsPlaceholder(
                  icon: Icons.route_outlined,
                  title: tr('Trabajos activos'),
                  message: tr(
                    'Aquí podrás seguir los servicios que ya aceptaste.',
                  ),
                ),
                _MarketplaceJobsPlaceholder(
                  icon: Icons.event_outlined,
                  title: tr('Trabajos programados'),
                  message: tr(
                    'Aquí aparecerán los servicios aceptados para más adelante.',
                  ),
                ),
                _MarketplaceJobsPlaceholder(
                  icon: Icons.history_rounded,
                  title: tr('Historial de trabajos'),
                  message: tr(
                    'Aquí podrás consultar los servicios ya finalizados.',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketplaceJobsPlaceholder extends StatelessWidget {
  const _MarketplaceJobsPlaceholder({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                Icon(
                  icon,
                  size: 44,
                  color: appPrimaryColor(context),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: appMutedColor(context),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class MarketplaceMoreScreen extends StatelessWidget {
  const MarketplaceMoreScreen({
    required this.store,
    super.key,
  });

  final RecordStore store;

  void _openPage(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: AppBackground(
            child: SafeArea(child: child),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profilePhoto = _googleProfilePhotoUrl(store.user);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          tr('Más'),
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          child: ListTile(
            leading: const Icon(Icons.work_outline_rounded),
            title: const Text('Quiero trabajar con TUKTUK'),
            subtitle: const Text(
              'Configura tu perfil de conductor y el vehículo que usarás para recibir solicitudes.',
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _openPage(
              context,
              title: 'Trabaja con TUKTUK',
              child: MarketplaceOnboardingScreen(store: store),
            ),
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          child: ListTile(
            leading: const Icon(Icons.storefront_outlined),
            title: Text(tr('Tienda')),
            subtitle: Text(
              tr('Productos y servicios para tu operación.'),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _openPage(
              context,
              title: tr('Tienda'),
              child: const StoreScreen(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          child: ListTile(
            leading: profilePhoto == null
                ? const Icon(Icons.account_circle_outlined)
                : _UserNavigationAvatar(
                    photoUrl: profilePhoto,
                    selected: false,
                  ),
            title: Text(tr('Cuenta y sincronización')),
            subtitle: Text(
              store.user == null
                  ? tr('Inicia sesión y administra tu cuenta.')
                  : tr('Cuenta, sincronización, soporte y referidos.'),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              if (store.user != null) {
                unawaited(store.loadReferrals());
              }
              _openPage(
                context,
                title: tr('Cuenta y sincronización'),
                child: LoginScreen(store: store),
              );
            },
          ),
        ),
      ],
    );
  }
}
