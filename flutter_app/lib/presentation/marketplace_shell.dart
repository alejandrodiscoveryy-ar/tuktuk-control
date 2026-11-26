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
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: .34)),
      ),
      child: Icon(icon, size: 24, color: color),
    );
  }
}

class MarketplaceMoreScreen extends StatelessWidget {
  const MarketplaceMoreScreen({required this.store, this.onRegistrationFinished, super.key});

  final RecordStore store;
  final ValueChanged<MarketplaceRegistrationReceipt>? onRegistrationFinished;

  void _openPage(
    BuildContext context, {
    required String title,
    required Widget child,
    bool agency = false,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: AppBackground(
            child: SafeArea(
              child: AnimatedBuilder(
                animation: store,
                builder: (context, _) => store.conductorAppAccessGateVisible
                    ? ConductorAppAccessGate(store: store, child: child)
                    : agency && store.conductorLocalOnly
                        ? _AgencyAccessUnavailable(store: store)
                        : child,
              ),
            ),
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
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            minVerticalPadding: 6,
            minTileHeight: 56,
            leading: const _MoreSectionIcon(
              icon: Icons.work_outline_rounded,
              color: Color(0xFF2DD4A3),
            ),
            title: const Text('Conviértete en conductor'),

            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _openPage(
              context,
              title: 'Conviértete en conductor',
              agency: true,
              child: MarketplaceOnboardingScreen(
                store: store,
                onRegistrationFinished: onRegistrationFinished == null ? null : (receipt) {
                  if (!context.mounted || store.user?.id != receipt.userId) return;
                  Navigator.of(context).pop();
                  onRegistrationFinished!(receipt);
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            minVerticalPadding: 6,
            minTileHeight: 56,
            leading: profilePhoto == null
                ? const _MoreSectionIcon(
                    icon: Icons.account_circle_outlined,
                    color: Color(0xFF55A7FF),
                  )
                : Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF55A7FF).withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(12),
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
        const SizedBox(height: 10),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            minVerticalPadding: 6,
            minTileHeight: 56,
            leading: const _MoreSectionIcon(
              icon: Icons.campaign_outlined,
              color: Color(0xFFFB923C),
            ),
            title: const Text('Impulsa'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _openPage(
              context,
              title: 'Impulsa',
              agency: true,
              child: MarketplaceDriverPromotionScreen(store: store),
            ),
          ),
        ),
        const SizedBox(height: 10),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            minVerticalPadding: 6,
            minTileHeight: 56,
            leading: const _MoreSectionIcon(
              icon: Icons.redeem_outlined,
              color: Color(0xFF9A7BFF),
            ),
            title: Text(tr('Referidos')),

            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              if (store.conductorAgencyAccessAllowed) {
                unawaited(store.loadReferrals());
              }
              _openPage(
                context,
                title: tr('Referidos'),
                agency: true,
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
        const SizedBox(height: 10),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            minVerticalPadding: 6,
            minTileHeight: 56,
            key: const ValueKey('more-direct-support'),
            leading: const _MoreSectionIcon(
              icon: Icons.support_agent_rounded,
              color: Color(0xFFFFB547),
            ),
            title: Text(tr('Soporte')),
            trailing: const Icon(Icons.open_in_new_rounded),
            onTap: () {
              final action = store.supportWhatsAppAction();
              if (action == null) {
                toast(context, tr('El contacto de soporte no está disponible en este momento.'));
                return;
              }
              unawaited(_launchWhatsApp(context, action));
            },
          ),
        ),
      ],
    );
  }
}
