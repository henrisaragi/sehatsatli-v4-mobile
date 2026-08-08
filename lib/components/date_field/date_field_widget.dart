import '/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';

/// A single tappable date field that opens the platform date picker.
/// Extracted from `report_investigation_widget.dart`'s `_dateField`/
/// `_pickDate`. For a from/to range, place two instances side by side (as
/// the investigation date range does) rather than building a dedicated
/// range widget.
class DateFieldWidget extends StatelessWidget {
  const DateFieldWidget({
    super.key,
    required this.label,
    required this.date,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
  });

  final String label;
  final DateTime? date;
  final ValueChanged<DateTime> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: date ?? DateTime.now(),
      firstDate: firstDate ?? DateTime(2000),
      lastDate: lastDate ?? DateTime(2100),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _pickDate(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: FlutterFlowTheme.of(context).secondaryBackground,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: FlutterFlowTheme.of(context).alternate),
          ),
        ),
        child: Text(
          date == null ? 'Pilih tanggal' : date!.toIso8601String().split('T').first,
          style: FlutterFlowTheme.of(context).bodyMedium.override(
                color: date == null
                    ? FlutterFlowTheme.of(context).secondaryText
                    : FlutterFlowTheme.of(context).primaryText,
              ),
        ),
      ),
    );
  }
}
