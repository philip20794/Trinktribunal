import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/domain/avatar_config.dart';
import 'package:trinktribunal/features/profile/avatar_options.dart';
import 'package:trinktribunal/l10n/app_strings.dart';

void main() {
  for (final language in ['de', 'en']) {
    testWidgets(
      'all 14 editor categories expose localized choices and remain independently editable: $language',
      (tester) async {
        var config = AvatarConfig();
        await tester.pumpWidget(
          MaterialApp(
            home: AppLanguageScope(
              language: language,
              child: Scaffold(
                body: SingleChildScrollView(
                  child: StatefulBuilder(
                    builder: (context, setState) => AvatarOptions(
                      config: config,
                      onChanged: (value) => setState(() => config = value),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        Finder fields() => find.byWidgetPredicate(
          (widget) => widget is DropdownButtonFormField<String>,
        );
        expect(fields(), findsNWidgets(14));
        var index = 0;
        for (final category in AvatarCatalog.options.entries) {
          final field = tester
              .widgetList<DropdownButtonFormField<String>>(fields())
              .elementAt(index++);
          expect(
            field.decoration.labelText,
            AppStrings(language).get('avatarCategory${category.key}'),
          );
          final dropdown = tester.widget<DropdownButton<String>>(
            find.descendant(
              of: fields().at(index - 1),
              matching: find.byWidgetPredicate(
                (widget) => widget is DropdownButton<String>,
              ),
            ),
          );
          expect(dropdown.items!.map((item) => item.value), category.value);
          expect(field.onChanged, isNotNull);
          for (final item in dropdown.items!) {
            expect(
              (item.child as Text).data,
              AppStrings(language).get('avatarOption${item.value}'),
            );
            expect(
              (item.child as Text).data,
              isNot(startsWith('avatarOption')),
            );
          }
          field.onChanged!(category.value.last);
          await tester.pump();
          expect(config[category.key], category.value.last);
        }
        expect(config.selections, {
          for (final entry in AvatarCatalog.options.entries)
            entry.key: entry.value.last,
        });
        expect(tester.takeException(), isNull);
      },
    );
  }
}
