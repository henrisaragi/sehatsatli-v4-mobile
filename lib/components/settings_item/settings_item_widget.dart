import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '/flutter_flow/flutter_flow_theme.dart';

/// One row in a settings group: tinted icon, title + optional subtitle, and
/// a chevron (or [trailing]). Sits inside a card, so it has no own border.
class SettingsItemWidget extends StatelessWidget {
  const SettingsItemWidget({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.iconColor,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Icon tint; defaults to the primary text colour on a neutral chip.
  final Color? iconColor;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final subtitle = this.subtitle;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            Container(
              width: 36.0,
              height: 36.0,
              decoration: BoxDecoration(
                color: theme.surfaceVariant,
                borderRadius: BorderRadius.circular(10.0),
              ),
              alignment: Alignment.center,
              child:
                  Icon(icon, color: iconColor ?? theme.primaryText, size: 18.0),
            ),
            const SizedBox(width: 12.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.bodyLarge.override(
                      font: GoogleFonts.inter(fontWeight: FontWeight.w500),
                      color: theme.primaryText,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.0,
                      lineHeight: 1.3,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2.0),
                    Text(
                      subtitle,
                      style: theme.bodySmall.override(
                        color: theme.secondaryText,
                        letterSpacing: 0.0,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8.0),
            trailing ??
                Icon(LucideIcons.chevronRight,
                    color: theme.secondaryText, size: 18.0),
          ],
        ),
      ),
    );
  }
}
