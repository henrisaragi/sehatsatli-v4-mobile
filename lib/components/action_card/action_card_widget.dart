import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '/flutter_flow/flutter_flow_theme.dart';

/// Dashboard quick-action tile: tinted icon, title, and an optional count
/// pill (e.g. reports waiting at a stage).
class ActionCardWidget extends StatelessWidget {
  const ActionCardWidget({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    this.count,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;

  /// Shown top-right when non-null; hidden while unknown (offline/loading).
  final int? count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final count = this.count;

    return Material(
      color: theme.secondaryBackground,
      borderRadius: BorderRadius.circular(12.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.0),
        child: Container(
          padding: const EdgeInsets.all(14.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(color: theme.alternate),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40.0,
                    height: 40.0,
                    decoration: BoxDecoration(
                      color: iconBackground,
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, color: iconColor, size: 22.0),
                  ),
                  const Spacer(),
                  if (count != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8.0, vertical: 2.0),
                      decoration: BoxDecoration(
                        color: count > 0 ? iconColor : theme.alternate,
                        borderRadius: BorderRadius.circular(999.0),
                      ),
                      child: Text(
                        count > 99 ? '99+' : '$count',
                        style: theme.labelSmall.override(
                          font: GoogleFonts.inter(fontWeight: FontWeight.w600),
                          color: count > 0 ? Colors.white : theme.secondaryText,
                          letterSpacing: 0.0,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12.0),
              Text(
                title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.labelLarge.override(
                  font: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  color: theme.primaryText,
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.w600,
                  lineHeight: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
