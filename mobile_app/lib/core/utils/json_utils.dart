Map<String, dynamic> asMap(dynamic data) {
  if (data is Map) return Map<String, dynamic>.from(data);
  return <String, dynamic>{};
}

List<Map<String, dynamic>> asMapList(dynamic data) {
  if (data is! List) return <Map<String, dynamic>>[];
  return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
}

DateTime? parseDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString())?.toLocal();
}
