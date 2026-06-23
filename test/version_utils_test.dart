import 'package:flutter_test/flutter_test.dart';
import 'package:realtorone/utils/version_utils.dart';

void main() {
  test('compareSemanticVersions handles prefixed/build/prerelease versions', () {
    expect(compareSemanticVersions('v1.2.3+5', '1.2.3'), 0);
    expect(compareSemanticVersions('1.2.3-beta', '1.2.3'), 0);
    expect(compareSemanticVersions('1.2.4', '1.2.3'), 1);
    expect(compareSemanticVersions('1.2', '1.2.1'), -1);
  });

  test('isVersionOutsideAllowedRange enforces min and max bounds', () {
    expect(
      isVersionOutsideAllowedRange('1.0.9', min: '1.0.10', max: ''),
      isTrue,
    );
    expect(
      isVersionOutsideAllowedRange('2.0.1', min: '', max: '2.0.0'),
      isTrue,
    );
    expect(
      isVersionOutsideAllowedRange('1.0.10', min: '1.0.10', max: '2.0.0'),
      isFalse,
    );
    expect(
      isVersionUpdateRequired(
        versionControlEnabled: false,
        currentVersion: '1.0.0',
        minVersion: '9.0.0',
        maxVersion: '',
      ),
      isFalse,
    );
  });
}
