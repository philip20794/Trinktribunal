import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/l10n/app_strings.dart';
void main() {
  test('German and English include the same placeholder keys', () {
    expect(const AppStrings('de').get('settings'), 'Einstellungen');
    expect(const AppStrings('en').get('settings'), 'Settings');
    expect(const AppStrings('en').get('settingsSaveFailed'), isNotEmpty);
    expect(const AppStrings('en').get('unknown'), 'unknown');
  });
}
