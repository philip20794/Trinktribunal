import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/design/case_file.dart';
import 'package:trinktribunal/design/case_stage.dart';
import 'package:trinktribunal/design/court_scene.dart';
import 'package:trinktribunal/design/illustrated_paper.dart';

const incomingKey = ValueKey('case-stack-incoming');
const outgoingKey = ValueKey('case-stack-outgoing');

class _Harness extends StatefulWidget {
  const _Harness({super.key});
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  int caseNumber = 0, draw = 0, refreshes = 0;
  void external(int next) => setState(() => caseNumber = next);
  @override
  Widget build(BuildContext context) => CourtScaffold(
    title: const Text('Navigation'),
    footer: CourtActionBar(
      primary: FilledButton(
        onPressed: () => setState(() => caseNumber++),
        child: const Text('Next'),
      ),
    ),
    bodyBuilder: (_) => CaseStage(
      rules: 0,
      onRules: () {},
      judge: const Text('Player'),
      child: CourtQuestion(
        animationKey: caseNumber,
        label: 'Case $caseNumber',
        text: 'Question $caseNumber / $draw',
        green: 'Low',
        connector: '',
        red: 'High',
        maximum: 12,
        showRefresh: true,
        onRefresh: () => setState(() {
          refreshes++;
          draw++;
        }),
      ),
    ),
  );
}

Future<void> _host(
  WidgetTester tester,
  GlobalKey<_HarnessState> key, {
  double width = 390,
  bool reduced = false,
  bool accessible = false,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 860));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: reduced,
          accessibleNavigation: accessible,
        ),
        child: child!,
      ),
      home: RepaintBoundary(
        key: const ValueKey('motion-review'),
        child: _Harness(key: key),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final imageContext = tester.element(
    find.byKey(const ValueKey('motion-review')),
  );
  final providers = tester
      .widgetList<Image>(find.byType(Image))
      .map((w) => w.image)
      .toList();
  await tester.runAsync(
    () => Future.wait(
      providers.map((provider) => precacheImage(provider, imageContext)),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> review(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('TT_RENDER_REVIEW')) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('motion-review')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory('build/ui-review').create(recursive: true);
    await File('build/ui-review/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    final fonts = FontLoader('CourtRoboto');
    for (final weight in ['regular', 'medium', 'bold']) {
      fonts.addFont(rootBundle.load('assets/fonts/roboto-$weight.ttf'));
    }
    await fonts.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  for (final width in [280.0, 390.0, 760.0]) {
    testWidgets(
      'whole stacks exchange in 480ms with stationary chrome: $width',
      (tester) async {
        final key = GlobalKey<_HarnessState>();
        await _host(tester, key, width: width);
        final player = tester.getRect(find.text('Player'));
        final navigation = tester.getRect(find.text('Navigation'));
        final footer = tester.getRect(find.text('Next'));
        final paper = tester.getRect(find.byType(IllustratedPaper));
        if (width == 390) await review(tester, 'stack-exchange-start');
        final refresh = find.byKey(const ValueKey('case-paper-refresh'));
        await tester.tap(refresh);
        await tester.tap(refresh);
        expect(key.currentState!.refreshes, 1);
        await tester.pump();
        expect(find.byType(IllustratedPaper), findsNWidgets(2));
        final layers = tester
            .widget<Stack>(find.byKey(const ValueKey('case-stack-layers')))
            .children;
        expect(layers.map((w) => w.key), [incomingKey, outgoingKey]);
        expect(
          tester
              .widget<FractionalTranslation>(find.byKey(incomingKey))
              .translation,
          const Offset(-.16, .018),
        );
        await tester.pump(const Duration(milliseconds: 240));
        final progress = Curves.easeInOutCubic.transform(.5);
        final old = find.byKey(outgoingKey), next = find.byKey(incomingKey);
        final outgoing = tester.widget<FractionalTranslation>(old).translation;
        expect(outgoing.dx, closeTo(1.1 * progress, .001));
        expect(outgoing.dy, closeTo(.065 * progress, .001));
        expect(
          tester.widget<FractionalTranslation>(next).translation.dx,
          closeTo(-.16 * (1 - progress), .001),
        );
        final rotation = tester
            .widget<Transform>(
              find.descendant(of: old, matching: find.byType(Transform)).first,
            )
            .transform;
        expect(
          math.atan2(rotation.storage[1], rotation.storage[0]),
          closeTo(math.pi / 90 * progress, .001),
        );
        for (final layer in [old, next]) {
          expect(
            find.descendant(of: layer, matching: find.byType(IllustratedPaper)),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: layer,
              matching: find.byType(IllustratedQuestion),
            ),
            findsOneWidget,
          );
        }
        await tester.tap(
          find.descendant(of: next, matching: refresh),
          warnIfMissed: false,
        );
        await tester.tap(find.text('Next'), warnIfMissed: false);
        expect(key.currentState!.refreshes, 1);
        expect(key.currentState!.caseNumber, 0);
        expect(tester.getRect(find.text('Player')), player);
        expect(tester.getRect(find.text('Navigation')), navigation);
        expect(tester.getRect(find.text('Next')), footer);
        if (width == 390) await review(tester, 'stack-exchange-middle');
        await tester.pump(const Duration(milliseconds: 239));
        expect(find.byKey(outgoingKey), findsOneWidget);
        // Finish on the next display frame after the 480ms tween boundary.
        await tester.pump(const Duration(milliseconds: 17));
        await tester.pump();
        expect(find.byKey(outgoingKey), findsNothing);
        expect(find.byType(IllustratedPaper), findsOneWidget);
        expect(tester.getRect(find.byType(IllustratedPaper)), paper);
        expect(
          tester.widget<FractionalTranslation>(next).translation,
          Offset.zero,
        );
        expect(tester.getRect(find.text('Next')), footer);
        if (width == 390) await review(tester, 'stack-exchange-end');
        await tester.tap(find.text('Next'));
        await tester.pump();
        expect(key.currentState!.caseNumber, 1);
        expect(find.byKey(outgoingKey), findsOneWidget);
        await tester.pumpAndSettle();
        expect(find.byKey(outgoingKey), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'rapid external updates retain at most two layers and settle the newest card',
    (tester) async {
      final key = GlobalKey<_HarnessState>();
      await _host(tester, key);
      key.currentState!.external(1);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      key.currentState!.external(2);
      await tester.pump();
      key.currentState!.external(3);
      await tester.pump();
      expect(find.byType(IllustratedPaper), findsNWidgets(2));
      expect(find.byKey(outgoingKey), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(find.byType(IllustratedPaper), findsOneWidget);
      expect(find.text('Question 3 / 0'), findsOneWidget);
      expect(find.byKey(outgoingKey), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final accessible in [false, true]) {
    testWidgets(
      'reduced motion switches immediately without blocking: accessible=$accessible',
      (tester) async {
        final key = GlobalKey<_HarnessState>();
        await _host(tester, key, reduced: !accessible, accessible: accessible);
        await tester.tap(find.byKey(const ValueKey('case-paper-refresh')));
        await tester.pump();
        await tester.pump();
        expect(find.byKey(outgoingKey), findsNothing);
        expect(find.text('Question 0 / 1'), findsOneWidget);
        await tester.tap(find.text('Next'));
        await tester.pump();
        expect(key.currentState!.caseNumber, 1);
        expect(find.byKey(outgoingKey), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
