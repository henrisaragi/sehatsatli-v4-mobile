import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';

/// Permanent banner shown on the main tab screens while
/// `FFAppState().trainingMode` is true, per CLAUDE.md §9.4 — reminds field
/// officers that reports created right now aren't counted as production data.
class TrainingModeBanner extends StatelessWidget {
  const TrainingModeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    if (!FFAppState().trainingMode) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: FlutterFlowTheme.of(context).accent2,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.graduationCap,
              color: FlutterFlowTheme.of(context).warning, size: 16.0),
          const SizedBox(width: 8.0),
          Expanded(
            child: Text(
              'Mode Latihan Aktif — data tidak dihitung resmi',
              style: FlutterFlowTheme.of(context).bodySmall.override(
                  color: FlutterFlowTheme.of(context).warning,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
