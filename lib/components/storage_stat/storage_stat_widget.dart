import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:provider/provider.dart';
import 'storage_stat_model.dart';
export 'storage_stat_model.dart';

class StorageStatWidget extends StatefulWidget {
  const StorageStatWidget({
    super.key,
    String? label,
    String? value,
    double? progress,
    Color? color,
  })  : this.label = label ?? 'Local Reports',
        this.value = value ?? '12 Drafts',
        this.progress = progress ?? 0.4,
        this.color = color ?? const Color(0x00000000);

  final String label;
  final String value;
  final double progress;
  final Color color;

  @override
  State<StorageStatWidget> createState() => _StorageStatWidgetState();
}

class _StorageStatWidgetState extends State<StorageStatWidget> {
  late StorageStatModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => StorageStatModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          valueOrDefault<String>(
            widget!.label,
            'Local Reports',
          ),
          style: FlutterFlowTheme.of(context).labelSmall.override(
                font: GoogleFonts.inter(
                  fontWeight:
                      FlutterFlowTheme.of(context).labelSmall.fontWeight,
                  fontStyle: FlutterFlowTheme.of(context).labelSmall.fontStyle,
                ),
                color: FlutterFlowTheme.of(context).secondaryText,
                letterSpacing: 0.0,
                fontWeight: FlutterFlowTheme.of(context).labelSmall.fontWeight,
                fontStyle: FlutterFlowTheme.of(context).labelSmall.fontStyle,
                lineHeight: 1.27,
              ),
        ),
        Text(
          valueOrDefault<String>(
            widget!.value,
            '12 Drafts',
          ),
          style: FlutterFlowTheme.of(context).titleSmall.override(
                font: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontStyle: FlutterFlowTheme.of(context).titleSmall.fontStyle,
                ),
                color: FlutterFlowTheme.of(context).primaryText,
                letterSpacing: 0.0,
                fontWeight: FontWeight.bold,
                fontStyle: FlutterFlowTheme.of(context).titleSmall.fontStyle,
                lineHeight: 1.4,
              ),
        ),
        LinearPercentIndicator(
          percent: valueOrDefault<double>(
            widget!.progress,
            0.4,
          ),
          lineHeight: 4.0,
          animation: true,
          animateFromLastPercent: true,
          progressColor: valueOrDefault<Color>(
            widget!.color,
            FlutterFlowTheme.of(context).secondary,
          ),
          backgroundColor: FlutterFlowTheme.of(context).alternate,
          barRadius: Radius.circular(2.0),
          padding: EdgeInsets.zero,
        ),
      ].divide(SizedBox(height: 4.0)),
    );
  }
}
