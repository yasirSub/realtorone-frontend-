import 'package:flutter_test/flutter_test.dart';
import 'package:realtorone/utils/version_utils.dart';

void main() {
  test('compareSemanticVersions handles prefixed/build/prerelease versions', () {
    expect(compareSemanticVersions('v1.2.3+5', '1.2.3'), 0);
    expect(compareSemanticVersions('1.2.3-beta', '1.2.3'), 0);
    expect(compareSemanticVersions('1.2.4', '1.2.3'), 1);
    expect(compareSemanticVersions('1.2', '1.2.1'), -1);
  });
}
