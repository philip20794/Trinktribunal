import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/l10n/app_strings.dart';

void main() {
  test('application feedback localizes without rewriting arbitrary player text', () {
    const de = AppStrings('de'), en = AppStrings('en');
    expect(
      en.feedback('Die Ordnung ist bereits gesperrt.'),
      'The order is already locked.',
    );
    expect(
      en.feedback(
        'Ein Name muss nach dem Trimmen 1 bis 24 sichtbare Zeichen enthalten.',
      ),
      contains('1 to 24'),
    );
    expect(
      en.feedback('factorTenths muss eine Ganzzahl sein.'),
      'factorTenths must be an integer.',
    );
    expect(
      de.feedback('Die Ordnung ist bereits gesperrt.'),
      'Die Ordnung ist bereits gesperrt.',
    );
    expect(en.feedback('Alex'), 'Alex');
    expect(en.get('judge', {'name': 'Röschen'}), 'Judge: Röschen');
  });
  test('German and English include the same placeholder keys', () {
    expect(const AppStrings('de').get('settings'), 'Einstellungen');
    expect(const AppStrings('en').get('settings'), 'Settings');
    expect(const AppStrings('en').get('settingsSaveFailed'), isNotEmpty);
    expect(const AppStrings('en').get('unknown'), 'unknown');
  });
}
