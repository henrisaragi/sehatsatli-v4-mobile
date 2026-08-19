import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '/flutter_flow/flutter_flow_theme.dart';

/// Server/network error surface shared across forms that need more room
/// than a snackbar (docs/update-profile.md's edit-profile checklist calls
/// for endpoint/server errors to show via a bottom sheet specifically).
Future<void> showErrorBottomSheet(BuildContext context, String message) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24.0, 28.0, 24.0, 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.circleAlert,
                color: FlutterFlowTheme.of(context).error, size: 40.0),
            SizedBox(height: 12.0),
            Text(
              'Terjadi Kesalahan',
              style: FlutterFlowTheme.of(context)
                  .titleMedium
                  .override(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8.0),
            Text(
              message,
              textAlign: TextAlign.center,
              style: FlutterFlowTheme.of(context).bodyMedium.override(
                  color: FlutterFlowTheme.of(context).secondaryText),
            ),
            SizedBox(height: 20.0),
            SizedBox(
              width: double.infinity,
              child: InkWell(
                onTap: () => Navigator.of(sheetContext).pop(),
                child: Container(
                  height: 48.0,
                  decoration: BoxDecoration(
                    color: FlutterFlowTheme.of(context).primary,
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Tutup',
                    style: FlutterFlowTheme.of(context).labelLarge.override(
                        color: FlutterFlowTheme.of(context).onPrimary,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
