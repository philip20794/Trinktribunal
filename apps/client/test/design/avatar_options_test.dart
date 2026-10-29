import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/domain/avatar_config.dart';
import 'package:trinktribunal/features/profile/avatar_options.dart';
import 'package:trinktribunal/l10n/app_strings.dart';

void main() {
  Future<void> host(WidgetTester tester,{double scale=1.0, String lang='de'}) async {
    await tester.binding.setSurfaceSize(const Size(380,700));
    await tester.pumpWidget(MaterialApp(home: AppLanguageScope(
      language: lang,
      child: MediaQuery(data: MediaQueryData(textScaler:TextScaler.linear(scale)),
        child: Scaffold(body: SizedBox.expand(child: AvatarOptions(
          config: AvatarConfig(), onChanged: (_) {},
        )))),
    )));
    await tester.pumpAndSettle();
  }

  for(final scale in [1.0,2.0]) {
    testWidgets('portrait options are compact and accessible at text scale $scale',(tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await host(tester,scale:scale);
      final first=tester.getRect(find.byKey(const ValueKey('avatar-option-hair')));
      final second=tester.getRect(find.byKey(const ValueKey('avatar-option-eyes')));
      if(scale==1.0) {
        expect(second.top,first.top);
        expect(second.left,greaterThan(first.left));
      } else {
        expect(second.top,greaterThan(first.top));
      }
      expect(tester.takeException(),isNull);
    });
  }

  for(final language in ['de','en']) {
    testWidgets('face, outfit and colors tabs keep selected controls editable: $language',(tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var selected=AvatarConfig();
      await tester.binding.setSurfaceSize(const Size(380,700));
      await tester.pumpWidget(MaterialApp(home: AppLanguageScope(
        language:language,
        child: Scaffold(body: StatefulBuilder(builder:(context,setState)=>
          SizedBox.expand(child: AvatarOptions(
            config:selected,
            onChanged:(value)=>setState(()=>selected=value),
          )),
        )),
      )));
      await tester.pumpAndSettle();
      final hair=find.byKey(const ValueKey('avatar-option-hair'));
      expect(hair,findsOneWidget);
      final hairField=tester.widget<DropdownButtonFormField<String>>(hair);
      hairField.onChanged!('long01');
      await tester.pump();
      expect(selected['hair'],'long01');
      await tester.tap(find.byKey(const ValueKey('avatar-tab-1')));
      await tester.pumpAndSettle();
      final outfit=find.byKey(const ValueKey('avatar-option-outfit'));
      tester.widget<DropdownButtonFormField<String>>(outfit).onChanged!('hoodie');
      await tester.pump();
      expect(selected['outfit'],'hoodie');
      await tester.tap(find.byKey(const ValueKey('avatar-tab-2')));
      await tester.pumpAndSettle();
      final skin=find.byKey(const ValueKey('avatar-option-skinColor'));
      tester.widget<DropdownButtonFormField<String>>(skin).onChanged!('#763900');
      await tester.pump();
      expect(selected['skinColor'],'#763900');
      await tester.tap(find.byKey(const ValueKey('avatar-tab-0')));
      await tester.pumpAndSettle();
      expect(tester.widget<DropdownButtonFormField<String>>(hair).value,'long01');
      expect(tester.takeException(),isNull);
    });
  }
}
