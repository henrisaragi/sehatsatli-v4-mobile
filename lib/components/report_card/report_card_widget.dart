import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '/flutter_flow/flutter_flow_theme.dart';

/// Report row card: species + status badge, then date and report code.
class ReportCardWidget extends StatelessWidget {
  const ReportCardWidget({
    super.key,
    this.onTap,
    required this.icon,
    required this.species,
    required this.status,
    required this.syncStatus,
    required this.date,
    required this.reportCode,
    this.footer,
  });

  final VoidCallback? onTap;
  final Widget icon;
  final String species;

  /// Badge text.
  final String status;

  /// draft | pending | synced | failed | legacy — picks the badge colours.
  final String syncStatus;
  final String date;
  final String reportCode;

  /// Extra content under the row, e.g. a sync error with a retry button.
  final Widget? footer;

  (Color, Color) _badgeColors(FlutterFlowTheme theme) {
    switch (syncStatus) {
      case 'synced':
        return (theme.accent1, theme.success);
      case 'pending':
        return (theme.accent2, theme.warning);
      case 'draft':
        return (theme.accent3, theme.info);
      case 'failed':
        return (theme.accent4, theme.error);
      default:
        return (theme.alternate, theme.secondaryText);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final (badgeBg, badgeFg) = _badgeColors(theme);
    final metaStyle = theme.bodySmall.override(
      font: GoogleFonts.inter(),
      color: theme.secondaryText,
      letterSpacing: 0.0,
    );

    return Material(
      color: theme.secondaryBackground,
      borderRadius: BorderRadius.circular(12.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.0),
        child: Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(color: theme.alternate),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 44.0,
                    height: 44.0,
                    decoration: BoxDecoration(
                      color: theme.primary10,
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    alignment: Alignment.center,
                    child: icon,
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                species,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.titleSmall.override(
                                  font: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600),
                                  color: theme.primaryText,
                                  letterSpacing: 0.0,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8.0),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10.0, vertical: 3.0),
                              decoration: BoxDecoration(
                                color: badgeBg,
                                borderRadius: BorderRadius.circular(999.0),
                              ),
                              child: Text(
                                status,
                                style: theme.labelSmall.override(
                                  font: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600),
                                  color: badgeFg,
                                  letterSpacing: 0.0,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6.0),
                        Row(
                          children: [
                            Icon(LucideIcons.calendar,
                                size: 14.0, color: theme.secondaryText),
                            const SizedBox(width: 4.0),
                            Text(date, style: metaStyle),
                            const SizedBox(width: 12.0),
                            Icon(LucideIcons.fileText,
                                size: 14.0, color: theme.secondaryText),
                            const SizedBox(width: 4.0),
                            Expanded(
                              child: Text(
                                reportCode,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: metaStyle,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (footer != null) ...[
                const SizedBox(height: 12.0),
                footer!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
