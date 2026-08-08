import '/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';

/// Select2-style searchable picker: the field itself just displays the
/// current selection and opens a bottom sheet with a search box + filtered
/// list on tap, instead of rendering every option inline like a plain
/// dropdown — needed wherever an option list can run into the hundreds of
/// entries (e.g. the protected-species picker, ~900 entries).
///
/// Extracted from `new_general_report_widget.dart`'s `_searchSelect`/
/// `_openSearchSelectSheet` (the original single-use-site version).
class SearchSelectWidget extends StatelessWidget {
  const SearchSelectWidget({
    super.key,
    required this.label,
    required this.hint,
    required this.options,
    required this.selectedId,
    required this.selectedLabel,
    required this.optionLabel,
    required this.optionId,
    required this.onSelected,
  });

  final String label;
  final String hint;
  final List<Map<String, dynamic>> options;
  final dynamic selectedId;
  final String? selectedLabel;
  final String Function(Map<String, dynamic>) optionLabel;
  final dynamic Function(Map<String, dynamic>) optionId;
  final ValueChanged<Map<String, dynamic>> onSelected;

  @override
  Widget build(BuildContext context) {
    final hasSelection = selectedId != null && (selectedLabel ?? '').isNotEmpty;
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
        InkWell(
          borderRadius: BorderRadius.circular(8.0),
          onTap: options.isEmpty ? null : () => _openSheet(context),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
            decoration: BoxDecoration(
              color: FlutterFlowTheme.of(context).secondaryBackground,
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: FlutterFlowTheme.of(context).alternate),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    hasSelection
                        ? selectedLabel!
                        : (options.isEmpty
                            ? 'Belum ada data cache'
                            : 'Pilih $label'),
                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                          color: hasSelection
                              ? FlutterFlowTheme.of(context).primaryText
                              : FlutterFlowTheme.of(context).secondaryText,
                        ),
                  ),
                ),
                Icon(Icons.search,
                    size: 18.0, color: FlutterFlowTheme.of(context).secondaryText),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openSheet(BuildContext context) async {
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      builder: (sheetContext) {
        var query = '';
        var filtered = options;
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: DraggableScrollableSheet(
                initialChildSize: 0.7,
                minChildSize: 0.4,
                maxChildSize: 0.92,
                expand: false,
                builder: (context, scrollController) => Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 8.0),
                      child: Text(
                        'Pilih $label',
                        style: FlutterFlowTheme.of(context)
                            .titleMedium
                            .override(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.0),
                      child: TextField(
                        autofocus: true,
                        onChanged: (v) => setSheetState(() {
                          query = v;
                          filtered = query.isEmpty
                              ? options
                              : options
                                  .where((o) => optionLabel(o)
                                      .toLowerCase()
                                      .contains(query.toLowerCase()))
                                  .toList();
                        }),
                        decoration: InputDecoration(
                          hintText: hint,
                          prefixIcon: Icon(Icons.search),
                          filled: true,
                          fillColor: FlutterFlowTheme.of(context).secondaryBackground,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                            borderSide:
                                BorderSide(color: FlutterFlowTheme.of(context).alternate),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 8.0),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                'Tidak ditemukan',
                                style: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .override(
                                        color: FlutterFlowTheme.of(context).secondaryText),
                              ),
                            )
                          : ListView.separated(
                              controller: scrollController,
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => Divider(
                                  height: 1.0, color: FlutterFlowTheme.of(context).alternate),
                              itemBuilder: (context, index) {
                                final opt = filtered[index];
                                return ListTile(
                                  title: Text(optionLabel(opt),
                                      style: FlutterFlowTheme.of(context).bodyMedium),
                                  onTap: () => Navigator.of(sheetContext).pop(opt),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (selected != null) onSelected(selected);
  }
}
