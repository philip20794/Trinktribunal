import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/domain/avatar_config.dart';
import 'package:trinktribunal/features/profile/avatar_options.dart';
import 'package:trinktribunal/features/profile/avatar_color_picker.dart';
import 'package:trinktribunal/features/profile/avatar_editor.dart';
import 'package:trinktribunal/design/avatar_view.dart';
import 'package:trinktribunal/l10n/app_strings.dart';

void main() {
  Future<void> host(
    WidgetTester tester, {
    double scale = 1.0,
    String lang = 'de',
  }) async {
    await tester.binding.setSurfaceSize(const Size(380, 700));
    await tester.pumpWidget(
      MaterialApp(
        home: AppLanguageScope(
          language: lang,
          child: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              body: SizedBox.expand(
                child: AvatarOptions(
                  config: AvatarConfig(),
                  onOpenSheet: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'portrait options are compact and accessible at text scale $scale',
      (tester) async {
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await host(tester, scale: scale);
        final first = tester.getRect(
          find.byKey(const ValueKey('avatar-option-hair:short03')),
        );
        final second = tester.getRect(
          find.byKey(const ValueKey('avatar-option-eyes:variant05')),
        );
        if (scale == 1.0) {
          expect(second.top, first.top);
          expect(second.left, greaterThan(first.left));
        } else {
          expect(second.top, greaterThan(first.top));
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final language in ['de', 'en']) {
    testWidgets(
      'face, outfit and colors tabs keep selected controls editable: $language',
      (tester) async {
        addTearDown(() => tester.binding.setSurfaceSize(null));
        var selected = AvatarConfig();
        final name = TextEditingController(text: 'Alex');
        addTearDown(name.dispose);
        await tester.binding.setSurfaceSize(const Size(380, 700));
        await tester.pumpWidget(
          MaterialApp(
            home: AppLanguageScope(
              language: language,
              child: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) => SizedBox.expand(
                    child: AvatarEditor(
                      config: selected,
                      nameController: name,
                      onNameChanged: (_) {},
                      onChanged: (value) => setState(() => selected = value),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final hair = find.byKey(const ValueKey('avatar-option-hair:short03'));
        expect(hair, findsOneWidget);
        await tester.tap(hair);
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('avatar-variant-hair-long01')),
        );
        await tester.pumpAndSettle();
        expect(selected['hair'], 'long01');
        expect(find.byType(BottomSheet), findsOneWidget);
        expect(find.textContaining('Variante'), findsNothing);
        await tester.tap(find.byKey(const ValueKey('avatar-sheet-close')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const ValueKey('avatar-tab-1')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('avatar-tab-1')));
        await tester.pumpAndSettle();
        final outfit = find.byKey(const ValueKey('avatar-option-outfit:tee'));
        await tester.tap(outfit);
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('avatar-variant-outfit-hoodie')),
        );
        await tester.pumpAndSettle();
        expect(selected['outfit'], 'hoodie');
        await tester.tap(find.byKey(const ValueKey('avatar-sheet-close')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const ValueKey('avatar-tab-2')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('avatar-tab-2')));
        await tester.pumpAndSettle();
        final skin = find.byKey(
          const ValueKey('avatar-option-skinColor:#ecad80'),
        );
        expect(skin, findsOneWidget);
        expect(find.byType(DropdownButtonFormField<String>), findsNothing);
        await tester.tap(skin);
        await tester.pumpAndSettle();
        expect(find.byType(AvatarColorPicker), findsOneWidget);
        expect(find.byType(AlertDialog), findsNothing);
        final picker = find.byKey(const ValueKey('avatar-color-wheel'));
        await tester.tapAt(tester.getCenter(picker) + const Offset(95, 0));
        await tester.pumpAndSettle();
        expect(selected['skinColor'], isNot('#ecad80'));
        expect(find.byType(BottomSheet), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('avatar-sheet-close')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const ValueKey('avatar-tab-0')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('avatar-tab-0')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('avatar-option-hair:long01')),
          findsOneWidget,
        );
        expect(find.byType(AvatarPartPreview), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
