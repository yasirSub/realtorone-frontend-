List<int> normalizeVersionParts(String version) {
  var normalized = version.trim().toLowerCase();
  if (normalized.startsWith('v')) {
    normalized = normalized.substring(1);
  }
  normalized = normalized.split('+').first;
  normalized = normalized.split('-').first;
  if (normalized.isEmpty) return [0];

  return normalized
      .split('.')
      .map((segment) => int.tryParse(segment.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
      .toList();
}

int compareSemanticVersions(String a, String b) {
  final pa = normalizeVersionParts(a);
  final pb = normalizeVersionParts(b);
  final maxLen = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < maxLen; i++) {
    final va = i < pa.length ? pa[i] : 0;
    final vb = i < pb.length ? pb[i] : 0;
    if (va > vb) return 1;
    if (va < vb) return -1;
  }
  return 0;
}
