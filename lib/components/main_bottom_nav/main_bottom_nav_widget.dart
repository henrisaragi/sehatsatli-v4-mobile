import 'package:flutter/material.dart';

import '/components/nav_item/nav_item_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';

/// The 4 real tabs per docs/tasks.md's IA — Beranda/Laporan/Notifikasi/Profil.
/// "Buat Laporan" is a separate flow reached via the FAB, not a tab.
enum MainTab { beranda, laporan, notifikasi, profil }

class MainBottomNavWidget extends StatelessWidget {
  const MainBottomNavWidget({super.key, required this.currentTab});

  final MainTab currentTab;

  void _goTo(BuildContext context, MainTab tab) {
    if (tab == currentTab) return;
    switch (tab) {
      case MainTab.beranda:
        context.goNamed(DashboardWidget.routeName);
        break;
      case MainTab.laporan:
        context.goNamed(ReportHistoryWidget.routeName);
        break;
      case MainTab.notifikasi:
        context.goNamed(NotificationInboxWidget.routeName);
        break;
      case MainTab.profil:
        context.goNamed(UserProfileSettingsWidget.routeName);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        border: Border(
            top: BorderSide(color: FlutterFlowTheme.of(context).alternate)),
      ),
      child: SafeArea(
        top: false,
        child: Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                NavItemWidget(
                  label: 'Beranda',
                  icon: Icon(
                    Icons.home_rounded,
                    color: currentTab == MainTab.beranda
                        ? FlutterFlowTheme.of(context).primary
                        : FlutterFlowTheme.of(context).secondaryText,
                  ),
                  selected: currentTab == MainTab.beranda,
                  onTap: () => _goTo(context, MainTab.beranda),
                ),
                NavItemWidget(
                  label: 'Laporan',
                  icon: Icon(
                    Icons.list_alt_rounded,
                    color: currentTab == MainTab.laporan
                        ? FlutterFlowTheme.of(context).primary
                        : FlutterFlowTheme.of(context).secondaryText,
                  ),
                  selected: currentTab == MainTab.laporan,
                  onTap: () => _goTo(context, MainTab.laporan),
                ),
                // Spacer for the FAB notch.
                SizedBox(width: 64.0),
                NavItemWidget(
                  label: 'Notifikasi',
                  icon: Icon(
                    Icons.notifications_rounded,
                    color: currentTab == MainTab.notifikasi
                        ? FlutterFlowTheme.of(context).primary
                        : FlutterFlowTheme.of(context).secondaryText,
                  ),
                  selected: currentTab == MainTab.notifikasi,
                  onTap: () => _goTo(context, MainTab.notifikasi),
                ),
                NavItemWidget(
                  label: 'Profil',
                  icon: Icon(
                    Icons.person_rounded,
                    color: currentTab == MainTab.profil
                        ? FlutterFlowTheme.of(context).primary
                        : FlutterFlowTheme.of(context).secondaryText,
                  ),
                  selected: currentTab == MainTab.profil,
                  onTap: () => _goTo(context, MainTab.profil),
                ),
              ],
            ),
            Positioned(
              top: -24.0,
              child: InkWell(
                borderRadius: BorderRadius.circular(9999.0),
                onTap: () =>
                    context.pushNamed(QuickReportWidget.routeName),
                child: Container(
                  width: 56.0,
                  height: 56.0,
                  decoration: BoxDecoration(
                    color: FlutterFlowTheme.of(context).secondary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(51),
                        blurRadius: 8.0,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.add_rounded,
                    color: FlutterFlowTheme.of(context).onSecondary,
                    size: 28.0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
