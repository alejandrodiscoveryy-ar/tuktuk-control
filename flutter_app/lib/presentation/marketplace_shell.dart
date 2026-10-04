part of '../main.dart';

class MarketplaceRecordsScreen extends StatelessWidget {
  const MarketplaceRecordsScreen({required this.store, super.key});

  final RecordStore store;

  static int initialTabIndexFor({required bool isReadOnly}) =>
      isReadOnly ? 1 : 0;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialTabIndexFor(isReadOnly: store.isReadOnly),
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

class _MoreSectionIcon extends StatelessWidget {
  const _MoreSectionIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withValues(alpha: .34)),
      ),
      child: Icon(icon, size: 30, color: color),
    );
  }
}

class MarketplaceMoreScreen extends StatelessWidget {
  const MarketplaceMoreScreen({required this.store, super.key});

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
          body: AppBackground(child: SafeArea(child: child)),
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
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 16),
        GlassCard(
          child: ListTile(
            leading: const _MoreSectionIcon(
              icon: Icons.work_outline_rounded,
              color: Color(0xFF2DD4A3),
            ),
            title: const Text('Trabajar con nosotros'),
            subtitle: const Text(
              'Configura tu perfil de conductor y el vehículo que usarás para recibir solicitudes.',
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _openPage(
              context,
              title: 'Trabajar con nosotros',
              child: MarketplaceOnboardingScreen(store: store),
            ),
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          child: ListTile(
            leading: profilePhoto == null
                ? const _MoreSectionIcon(
                    icon: Icons.account_circle_outlined,
                    color: Color(0xFF55A7FF),
                  )
                : Container(
                    width: 50,
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF55A7FF).withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: const Color(0xFF55A7FF).withValues(alpha: .34),
                      ),
                    ),
                    child: _UserNavigationAvatar(
                      photoUrl: profilePhoto,
                      selected: false,
                    ),
                  ),
            title: Text(tr('Cuenta y sincronización')),
            subtitle: Text(
              store.user == null
                  ? tr('Inicia sesión y administra tu cuenta.')
                  : tr('Cuenta y sincronización'),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              _openPage(
                context,
                title: tr('Cuenta y sincronización'),
                child: LoginScreen(store: store),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          child: ListTile(
            leading: const _MoreSectionIcon(
              icon: Icons.support_agent_rounded,
              color: Color(0xFFFFB547),
            ),
            title: Text(tr('Soporte y pagos')),
            subtitle: Text(tr('Pagos y soporte')),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _openPage(
              context,
              title: tr('Soporte y pagos'),
              child: Builder(
                builder: (pageContext) => ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _SupportAndPaymentsCard(
                      supportAction: store.supportWhatsAppAction(),
                      paymentAction: store.paymentWhatsAppAction(),
                      onTap: (action) => _launchWhatsApp(pageContext, action),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          child: ListTile(
            leading: const _MoreSectionIcon(
              icon: Icons.redeem_outlined,
              color: Color(0xFF9A7BFF),
            ),
            title: Text(tr('Referidos')),
            subtitle: Text(
              store.referralProgram?.isRegistrationWalletLicense == true
                  ? 'Invita y gana saldo promocional por conductores referidos válidos.'
                  : store.referralProgram?.isWalletReward == true
                  ? 'Invita y gana saldo promocional.'
                  : 'Invita a otros conductores y consulta tus premios.',
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              if (store.user != null) {
                unawaited(store.loadReferrals());
              }
              _openPage(
                context,
                title: tr('Referidos'),
                // A pushed MaterialPageRoute does not rebuild when the shell
                // behind it receives a ChangeNotifier notification. Listen on
                // this route as well, otherwise loading never leaves the
                // spinner and newly credited rewards are not displayed.
                child: AnimatedBuilder(
                  animation: store,
                  builder: (context, _) => ListView(
                    padding: const EdgeInsets.all(16),
                    children: [_ReferralCard(store: store)],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
