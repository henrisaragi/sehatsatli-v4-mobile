import '/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';

/// Canonical master-option dropdown — one version replacing the `_dropdown`
/// helper previously duplicated across `new_general_report_widget.dart`,
/// `report_verification_widget.dart`, and `report_lab_widget.dart`.
///
/// [optionId] deliberately returns `dynamic`, not `int` — some master option
/// groups (e.g. `upt_type`) use string codes like `"PUSAT"`/`"KSDA"` as ids,
/// not numeric ones (revisi.md bug note #1). Never coerce it to `int` at a
/// call site.
class SimpleDropdownWidget extends StatelessWidget {
  const SimpleDropdownWidget({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.optionLabel,
    required this.optionId,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final dynamic value;
  final List<Map<String, dynamic>> options;
  final String Function(Map<String, dynamic>) optionLabel;
  final dynamic Function(Map<String, dynamic>) optionId;
  final ValueChanged<dynamic>? onChanged;

  /// When false, renders the current selection as a read-only field instead
  /// of an interactive dropdown — used for the UPT auto-fill fields, which
  /// must display the logged-in user's UPT but not be editable (revisi.md
  /// §2 Tab 1's Lokasi section).
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    // If a previously-selected value no longer matches any option (e.g. a
    // cascading parent changed), DropdownButtonFormField would assert.
    final validValue = options.any((o) => optionId(o) == value) ? value : null;

    if (!enabled) {
      final current = options.firstWhere(
        (o) => optionId(o) == value,
        orElse: () => const {},
      );
      final display = current.isEmpty ? null : optionLabel(current);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: 6.0),
            child: Text(
              label,
              style: FlutterFlowTheme.of(context)
                  .labelMedium
                  .override(fontWeight: FontWeight.w600),
            ),
          ),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
            decoration: BoxDecoration(
              color: FlutterFlowTheme.of(context).secondaryBackground,
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: FlutterFlowTheme.of(context).alternate),
            ),
            child: Text(
              display ?? '-',
              style: FlutterFlowTheme.of(context)
                  .bodyMedium
                  .override(color: FlutterFlowTheme.of(context).secondaryText),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 6.0),
          child: Text(
            label,
            style: FlutterFlowTheme.of(context)
                .labelMedium
                .override(fontWeight: FontWeight.w600),
          ),
        ),
        DropdownButtonFormField<dynamic>(
          value: validValue,
          isExpanded: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: FlutterFlowTheme.of(context).secondaryBackground,
            contentPadding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
              borderSide: BorderSide(color: FlutterFlowTheme.of(context).alternate),
            ),
            hintText: options.isEmpty ? 'Belum ada data cache' : 'Pilih $label',
          ),
          items: options
              .map((opt) =>
                  DropdownMenuItem(value: optionId(opt), child: Text(optionLabel(opt))))
              .toList(),
          onChanged: options.isEmpty ? null : onChanged,
        ),
      ],
    );
  }
}
