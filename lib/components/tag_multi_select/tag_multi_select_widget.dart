import '/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';

/// Multi-select `FilterChip` + `Wrap` picker over a master option list.
/// Generalized from `new_general_report_widget.dart`'s `_chipGroup`/
/// `report_verification_widget.dart`'s `_doctorChips()` (same UX pattern,
/// duplicated per call site) into ids rather than labels, so selection stays
/// correct even if two options share a display label.
///
/// Used for `live_sign`/`dead_sign` (master `clinical_signs`, filtered by
/// `type == "Live"`/`"Dead"`) and `insitu_conservation`/`exsitu_conservation`
/// (master `conservation_institutions`, filtered by `conservation_type ==
/// "IS"`/`"ES"`).
class TagMultiSelectWidget extends StatelessWidget {
  const TagMultiSelectWidget({
    super.key,
    required this.label,
    required this.options,
    required this.selectedIds,
    required this.optionLabel,
    required this.optionId,
    required this.onChanged,
  });

  final String label;
  final List<Map<String, dynamic>> options;
  final List<dynamic> selectedIds;
  final String Function(Map<String, dynamic>) optionLabel;
  final dynamic Function(Map<String, dynamic>) optionId;
  final ValueChanged<List<dynamic>> onChanged;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) return const SizedBox.shrink();
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
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: options.map((opt) {
            final id = optionId(opt);
            final isSelected = selectedIds.contains(id);
            return FilterChip(
              label: Text(optionLabel(opt)),
              selected: isSelected,
              onSelected: (v) {
                final next = List<dynamic>.from(selectedIds);
                if (v) {
                  next.add(id);
                } else {
                  next.remove(id);
                }
                onChanged(next);
              },
              selectedColor: FlutterFlowTheme.of(context).primary.withAlpha(38),
              checkmarkColor: FlutterFlowTheme.of(context).primary,
            );
          }).toList(),
        ),
      ],
    );
  }
}
