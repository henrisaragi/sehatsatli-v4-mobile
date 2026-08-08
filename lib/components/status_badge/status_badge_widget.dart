import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'status_badge_model.dart';
export 'status_badge_model.dart';

class StatusBadgeWidget extends StatefulWidget {
  const StatusBadgeWidget({
    super.key,
    String? status,
  }) : this.status = status ?? '';

  final String status;

  @override
  State<StatusBadgeWidget> createState() => _StatusBadgeWidgetState();
}

class _StatusBadgeWidgetState extends State<StatusBadgeWidget> {
  late StatusBadgeModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => StatusBadgeModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: valueOrDefault<Color>(
          () {
            if (widget!.status == 'Synced') {
              return FlutterFlowTheme.of(context).accent1;
            } else if (widget!.status == 'Pending' ||
                widget!.status == 'Syncing') {
              return FlutterFlowTheme.of(context).accent2;
            } else if (widget!.status == 'Error') {
              return FlutterFlowTheme.of(context).accent4;
            } else {
              // 'Draft' and any unrecognized status.
              return FlutterFlowTheme.of(context).accent3;
            }
          }(),
          Color(0x00000000),
        ),
        borderRadius: BorderRadius.circular(12.0),
        shape: BoxShape.rectangle,
        border: Border.all(
          color: FlutterFlowTheme.of(context).alternate,
          width: 1.0,
        ),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(4.0, 8.0, 4.0, 8.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (widget!.status == 'Syncing') ...[
              SizedBox(
                width: 10.0,
                height: 10.0,
                child: SpinKitRing(
                  color: FlutterFlowTheme.of(context).warning,
                  size: 10.0,
                  lineWidth: 1.5,
                ),
              ),
              SizedBox(width: 4.0),
            ],
            Text(
              widget!.status,
              style: FlutterFlowTheme.of(context).labelSmall.override(
                    font: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontStyle:
                          FlutterFlowTheme.of(context).labelSmall.fontStyle,
                    ),
                    color: valueOrDefault<Color>(
                      () {
                        if (widget!.status == 'Synced') {
                          return FlutterFlowTheme.of(context).success;
                        } else if (widget!.status == 'Pending' ||
                            widget!.status == 'Syncing') {
                          return FlutterFlowTheme.of(context).warning;
                        } else if (widget!.status == 'Error') {
                          return FlutterFlowTheme.of(context).error;
                        } else {
                          return FlutterFlowTheme.of(context).info;
                        }
                      }(),
                      Color(0x00000000),
                    ),
                    letterSpacing: 0.0,
                    fontWeight: FontWeight.bold,
                    fontStyle:
                        FlutterFlowTheme.of(context).labelSmall.fontStyle,
                    lineHeight: 1.27,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
