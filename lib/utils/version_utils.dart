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

/// True when [current] is below [min] or above [max] (empty bound = ignored).
bool isVersionOutsideAllowedRange(
  String current, {
  required String min,
  required String max,
}) {
  final normalized = current.trim();
  if (normalized.isEmpty) return false;
  if (min.isNotEmpty && compareSemanticVersions(normalized, min) < 0) {
    return true;
  }
  if (max.isNotEmpty && compareSemanticVersions(normalized, max) > 0) {
    return true;
  }
  return false;
}

bool isVersionUpdateRequired({
  required bool versionControlEnabled,
  required String currentVersion,
  required String minVersion,
  required String maxVersion,
}) {
  if (!versionControlEnabled) return false;
  if (minVersion.isEmpty && maxVersion.isEmpty) return false;
  return isVersionOutsideAllowedRange(
    currentVersion,
    min: minVersion,
    max: maxVersion,
  );
}
