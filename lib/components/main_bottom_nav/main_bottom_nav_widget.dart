import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';

/// The 4 tabs — Beranda/Laporan/Sinkron/Profil. "Buat Laporan" is a
/// separate flow (pushed), shown as the middle button, not a tab.
enum MainTab { beranda, laporan, sinkron, profil }

/// Floating pill bottom bar (Instagram-style): icons only, the active tab
/// is shown by its icon colour.
class MainBottomNavWidget extends StatelessWidget {
  const MainBottomNavWidget({
    super.key,
    required this.currentTab,
    this.onQuickReportClosed,
  });

  final MainTab currentTab;

  /// Called when the user comes back from "Buat Laporan", so the page can
  /// reload what it lists.
  final VoidCallback? onQuickReportClosed;

  void _goTo(BuildContext context, MainTab tab) {
    if (tab == currentTab) return;
    switch (tab) {
      case MainTab.beranda:
        context.goNamed(DashboardWidget.routeName);
        break;
      case MainTab.laporan:
        context.goNamed(ReportHistoryWidget.routeName);
        break;
      case MainTab.sinkron:
        context.goNamed(SyncManagerWidget.routeName);
        break;
      case MainTab.profil:
        context.goNamed(UserProfileSettingsWidget.routeName);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    Widget tab(MainTab tab, IconData icon, String label) => _NavButton(
          icon: icon,
          label: label,
          selected: currentTab == tab,
          onTap: () => _goTo(context, tab),
        );

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 8.0),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 4.0),
        child: Container(
          height: 64.0,
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          decoration: BoxDecoration(
            color: theme.primaryBackground,
            borderRadius: BorderRadius.circular(999.0),
            border: Border.all(color: theme.alternate),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(20),
                blurRadius: 16.0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              tab(MainTab.beranda, LucideIcons.house, 'Beranda'),
              tab(MainTab.laporan, LucideIcons.listChecks, 'Laporan'),
              _NavButton(
                icon: LucideIcons.squarePlus,
                label: 'Buat Laporan',
                selected: false,
                color: theme.secondary,
                onTap: () async {
                  await context.pushNamed(QuickReportWidget.routeName);
                  onQuickReportClosed?.call();
                },
              ),
              tab(MainTab.sinkron, LucideIcons.refreshCw, 'Sinkron'),
              tab(MainTab.profil, LucideIcons.circleUserRound, 'Profil'),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: Tooltip(
          message: label,
          child: InkWell(
            onTap: onTap,
            customBorder: const StadiumBorder(),
            child: Center(
              child: Icon(
                icon,
                size: 26.0,
                color:
                    color ?? (selected ? theme.primary : theme.secondaryText),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
