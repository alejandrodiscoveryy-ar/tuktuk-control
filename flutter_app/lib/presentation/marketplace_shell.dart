part of '../main.dart';

class MarketplaceRecordsScreen extends StatelessWidget {
  const MarketplaceRecordsScreen({required this.store, super.key});

  final RecordStore store;

  static int initialTabIndexFor({required bool isReadOnly}) =>
      isReadOnly ? 1 : 0;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final active = dark
        ? (isBlueAccentTheme(context) ? const Color(0xFFA8D0FF) : const Color(0xFF80E5C3))
        : const Color(0xFF174C75);
    final inactive = dark ? const Color(0xFFD0DCE9) : const Color(0xFF40566B);
    return DefaultTabController(
      length: 2,
      initialIndex: initialTabIndexFor(isReadOnly: store.isReadOnly),
      child: Builder(
        builder: (tabContext) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: GlassCard(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        Container(
                          width: 34, height: 34,
                          decoration: BoxDecoration(
                            color: active.withValues(alpha: .14),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.receipt_long_rounded, size: 22, color: active),
                        ),
                        const SizedBox(width: 9),
                        Expanded(child: Text(tr('Registros'), style: TextStyle(
                          color: appTextColor(context), fontSize: 21,
                          fontWeight: FontWeight.w800, letterSpacing: -.35))),
                      ]),
                      const SizedBox(height: 6),
                      TabBar(
                        dividerColor: Colors.transparent,
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicator: BoxDecoration(
                          color: active.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: active.withValues(alpha: .6)),
                        ),
                        labelColor: active,
                        unselectedLabelColor: inactive,
                        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                        tabs: [
                          Tab(
                            height: 48,
                            icon: const Icon(Icons.add_circle_rounded, size: 23),
                            text: tr('Nuevo'),
                          ),
                          Tab(
                            height: 48,
                            icon: const Icon(Icons.history_rounded, size: 23),
                            text: tr('Historial'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
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
      width: 64,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: color.withValues(alpha: .34)),
      ),
      child: Icon(icon, size: 34, color: color),
    );
  }
}

// The home receipt and More menu share the same guarded registration route.
void _openMarketplaceRegistration(BuildContext context, RecordStore store,
    ValueChanged<MarketplaceRegistrationReceipt>? finished) {
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (routeContext) => Scaffold(
      appBar: AppBar(title: const Text('Conviértete en conductor')),
      body: AppBackground(child: SafeArea(child: AnimatedBuilder(
        animation: store,
        builder: (context, _) => store.conductorAppAccessGateVisible
          ? ConductorAppAccessGate(store: store, child: const SizedBox.shrink())
          : store.conductorLocalOnly
            ? _AgencyAccessUnavailable(store: store)
            : MarketplaceOnboardingScreen(store: store,
                onRegistrationFinished: finished == null ? null : (receipt) {
                  if (!routeContext.mounted || store.user?.id != receipt.userId) return;
                  Navigator.of(routeContext).pop();
                  finished(receipt);
                }),
      ))),
    ),
  ));
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
      padding: EdgeInsets.fromLTRB(16, 20, 16, 110 + MediaQuery.paddingOf(context).bottom),
      children: [
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 9),
            horizontalTitleGap: 18,
            minVerticalPadding: 8,
            minTileHeight: 82,
            leading: const _MoreSectionIcon(
              icon: Icons.work_outline_rounded,
              color: Color(0xFF2DD4A3),
            ),
            title: const Text('Conviértete en conductor'),

            trailing: const Icon(Icons.chevron_right_rounded, size: 28),
            onTap: () => _openMarketplaceRegistration(context, store, onRegistrationFinished),
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 9),
            horizontalTitleGap: 18,
            minVerticalPadding: 8,
            minTileHeight: 82,
            leading: profilePhoto == null
                ? const _MoreSectionIcon(
                    icon: Icons.account_circle_outlined,
                    color: Color(0xFF55A7FF),
                  )
                : Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF55A7FF).withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(
                        color: const Color(0xFF55A7FF).withValues(alpha: .34),
                      ),
                    ),
                    child: _UserNavigationAvatar(
                      photoUrl: profilePhoto,
                      selected: false,
                      size: 44,
                    ),
                  ),
            title: Text(tr('Cuenta y sincronización')),

            trailing: const Icon(Icons.chevron_right_rounded, size: 28),
            onTap: () {
              _openPage(
                context,
                title: tr('Cuenta y sincronización'),
                child: LoginScreen(store: store),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 9),
            horizontalTitleGap: 18,
            minVerticalPadding: 8,
            minTileHeight: 82,
            leading: const _MoreSectionIcon(
              icon: Icons.campaign_outlined,
              color: Color(0xFFFB923C),
            ),
            title: const Text('Impulsa'),
            trailing: const Icon(Icons.chevron_right_rounded, size: 28),
            onTap: () => _openPage(
              context,
              title: 'Impulsa',
              agency: true,
              child: MarketplaceDriverPromotionScreen(store: store),
            ),
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 9),
            horizontalTitleGap: 18,
            minVerticalPadding: 8,
            minTileHeight: 82,
            leading: const _MoreSectionIcon(
              icon: Icons.redeem_outlined,
              color: Color(0xFF9A7BFF),
            ),
            title: Text(tr('Referidos')),

            trailing: const Icon(Icons.chevron_right_rounded, size: 28),
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
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 9),
            horizontalTitleGap: 18,
            minVerticalPadding: 8,
            minTileHeight: 82,
            key: const ValueKey('more-direct-support'),
            leading: const _MoreSectionIcon(
              icon: Icons.support_agent_rounded,
              color: Color(0xFFFFB547),
            ),
            title: Text(tr('Soporte')),
            trailing: const Icon(Icons.open_in_new_rounded, size: 26),
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
