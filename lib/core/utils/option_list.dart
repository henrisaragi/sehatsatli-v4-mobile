/// Best-effort parsing for cached master-data option lists whose exact JSON
/// shape hasn't been confirmed against a live API response — tries a few
/// common key/list shapes before giving up and returning an empty list
/// (callers should degrade gracefully, not crash, when this is empty).
library;

List<Map<String, dynamic>> extractOptionList(dynamic data, List<String> keys) {
  if (data is List) {
    return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }
  if (data is Map) {
    for (final key in keys) {
      final value = data[key];
      if (value is List) {
        return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    }
  }
  return [];
}

dynamic optionId(Map<String, dynamic> option) => option['id'] ?? option['value'];

String optionLabel(Map<String, dynamic> option) =>
    (option['name'] ?? option['label'] ?? option['text'] ?? option['value'] ?? '').toString();
