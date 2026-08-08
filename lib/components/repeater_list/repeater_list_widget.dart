import '/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';

/// Generic add/remove row-list editor. This is a dumb renderer — the caller
/// owns [items] and mutates it (typically via `setState`) inside [onAdd]/
/// [onRemove]; this widget just lays out each row (via [rowBuilder]) with a
/// remove button, plus an "add" button at the bottom.
///
/// Used for Full Report Tab 2's `involved_doctors` (`{name, occupation,
/// date, sign}`), Tab 4's `evidence` (`{type_of_evidence, amount,
/// description}`) and `data_investigation` (`{date, name, occupation,
/// sign}`) — none of which had a real repeater before (the old pages either
/// used an id-only chip list or comma-joined free text).
class RepeaterListWidget<T> extends StatelessWidget {
  const RepeaterListWidget({
    super.key,
    required this.items,
    required this.rowBuilder,
    required this.onAdd,
    required this.onRemove,
    this.addLabel = 'Tambah',
  });

  final List<T> items;
  final Widget Function(BuildContext context, int index, T item) rowBuilder;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;
  final String addLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: 12.0),
            child: Container(
              padding: EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: FlutterFlowTheme.of(context).secondaryBackground,
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(color: FlutterFlowTheme.of(context).alternate),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: rowBuilder(context, i, items[i])),
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        size: 20.0, color: FlutterFlowTheme.of(context).secondaryText),
                    onPressed: () => onRemove(i),
                    tooltip: 'Hapus',
                  ),
                ],
              ),
            ),
          ),
        OutlinedButton.icon(
          onPressed: onAdd,
          icon: Icon(Icons.add_rounded, size: 18.0),
          label: Text(addLabel),
          style: OutlinedButton.styleFrom(
            foregroundColor: FlutterFlowTheme.of(context).primary,
            side: BorderSide(color: FlutterFlowTheme.of(context).primary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
          ),
        ),
      ],
    );
  }
}
