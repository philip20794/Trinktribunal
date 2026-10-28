import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/design/court_assets.dart';
import 'package:trinktribunal/design/court_scene.dart';
import 'package:trinktribunal/design/court_theme.dart';
import 'package:trinktribunal/features/design_gallery/design_gallery_screen.dart';
import 'package:trinktribunal/l10n/app_strings.dart';

class _UnavailableAssets extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) =>
      Future.error(StateError('synthetic unavailable art'));
}

const _review = bool.fromEnvironment('TT_RENDER_REVIEW');
const _boundary = ValueKey('scene-review');
Future<void> host(
  WidgetTester tester,
  Widget screen, {
  Size size = const Size(360, 800),
  double scale = 1,
  double keyboard = 0,
  bool missing = false,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    DefaultAssetBundle(
      bundle: missing ? _UnavailableAssets() : rootBundle,
      child: AppLanguageScope(
        language: 'de',
        child: MaterialApp(
          theme: courtTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              devicePixelRatio: 3,
              disableAnimations: true,
              viewInsets: EdgeInsets.only(bottom: keyboard),
            ),
            child: child!,
          ),
          home: RepaintBoundary(key: _boundary, child: screen),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> reviewImage(WidgetTester tester, String name) async {
  if (!_review) return;
  final context = tester.element(find.byKey(_boundary));
  final providers = tester
      .widgetList<Image>(find.byType(Image))
      .map((image) => image.image)
      .toList();
  await tester.runAsync(
    () => Future.wait(
      providers.map((provider) => precacheImage(provider, context)),
    ),
  );
  await tester.pumpAndSettle();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_boundary),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory('build/ui-review').create(recursive: true);
    await File('build/ui-review/$name.png')
        .writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    if (_review) {
      final loader = FontLoader('CourtRoboto');
      for (final font in ['regular', 'medium', 'bold']) {
        loader.addFont(rootBundle.load('assets/fonts/roboto-$font.ttf'));
      }
      await loader.load();
    }
  });
  test('scene, paper, primary actions and focus accents retain readable text contrast', () {
    for (final pair in [
      (CourtSceneTokens.cream, CourtSceneTokens.night),
      (CourtSceneTokens.cream, CourtSceneTokens.panel),
      (CourtTokens.ink, CourtSceneTokens.parchment),
      (CourtSceneTokens.cream, CourtSceneTokens.crimson),
      (CourtSceneTokens.gold, CourtSceneTokens.night),
      (CourtTokens.blue, CourtSceneTokens.parchment),
    ]) {
      final a = pair.$1.computeLuminance(), b = pair.$2.computeLuminance();
      expect(
        (math.max(a, b) + .05) / (math.min(a, b) + .05),
        greaterThanOrEqualTo(4.5),
      );
    }
  });
  test(
    'only explicitly selected courtroom artwork is packaged and decodable',
    () async {
      for (final asset in CourtAssets.nativeWidths.keys) {
        final bytes = await rootBundle.load(asset);
        expect(bytes.lengthInBytes, greaterThan(100));
        final codec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(),
        );
        final frame = await codec.getNextFrame();
        expect(frame.image.width, CourtAssets.nativeWidths[asset]);
        frame.image.dispose();
        codec.dispose();
      }
    },
  );
  for (final size in [const Size(320, 640), const Size(1440, 900)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'gallery ${size.width}×${size.height}, scale $scale: responsive paper, actions and semantics',
        (tester) async {
          final semantics = tester.ensureSemantics();
          try {
            await host(
              tester,
              const DesignGalleryScreen(),
              size: size,
              scale: scale,
            );
            expect(tester.takeException(), isNull);
            await expectLater(
              tester,
              meetsGuideline(labeledTapTargetGuideline),
            );
            await expectLater(
              tester,
              meetsGuideline(androidTapTargetGuideline),
            );
            expect(find.bySemanticsLabel('Trinktribunal'), findsOneWidget);
            await reviewImage(
              tester,
              'gallery-${size.width.toInt()}-${scale.toInt()}',
            );
          } finally {
            semantics.dispose();
          }
        },
      );
    }
  }
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'missing art at scale $scale preserves content, focus and primary/secondary actions',
      (tester) async {
        var primary = 0, secondary = 0;
        await host(
          tester,
          CourtScaffold(
            title: const Text('Fallakte'),
            background: 'assets/missing-background.png',
            bodyBuilder: (context) => ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const CourtBrandMark(),
                CourtPaper(
                  asset: 'assets/missing-paper.png',
                  child: Column(
                    children: [
                      const Text('Lesbarer Inhalt'),
                      TextField(
                        decoration: const InputDecoration(labelText: 'Name'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            footer: CourtActionBar(
              primary: CourtPrimaryButton(
                onPressed: () => primary++,
                child: const Text('Weiter'),
              ),
              secondary: CourtSecondaryButton(
                onPressed: () => secondary++,
                child: const Text('Zurück'),
              ),
            ),
          ),
          scale: scale,
          missing: true,
        );
        expect(find.text('Lesbarer Inhalt'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Weiter'));
        await tester.tap(find.text('Weiter'));
        await tester.pump();
        await tester.ensureVisible(find.text('Zurück'));
        await tester.tap(find.text('Zurück'));
        await tester.pump();
        expect(primary, 1);
        expect(secondary, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'dark page builder and paper builder expose their own correct themes',
    (tester) async {
      late Brightness page, paper;
      late Color? ink;
      await host(
        tester,
        CourtScaffold(
          bodyBuilder: (context) {
            page = Theme.of(context).brightness;
            return CourtPaper(
              child: Builder(
                builder: (context) {
                  paper = Theme.of(context).brightness;
                  ink = DefaultTextStyle.of(context).style.color;
                  return const Text('Lesen');
                },
              ),
            );
          },
        ),
      );
      expect(page, Brightness.dark);
      expect(paper, Brightness.light);
      expect(ink, CourtTokens.ink);
    },
  );
  testWidgets(
    'decode size remains bounded with an expanding image on a high-density wide viewport',
    (tester) async {
      await host(
        tester,
        const Scaffold(
          body: CourtArt(CourtAssets.wood, width: double.infinity),
        ),
        size: const Size(1440, 900),
      );
      final image = tester.widget<Image>(find.byType(Image));
      expect((image.image as ResizeImage).width, lessThanOrEqualTo(1080));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'footer remains reachable with keyboard and enlarged long labels',
    (tester) async {
      var activated = false;
      await host(
        tester,
        CourtScaffold(
          title: const Text('Profil'),
          body: ListView(
            children: const [
              CourtPaper(
                child: TextField(
                  decoration: InputDecoration(labelText: 'Dein Name'),
                ),
              ),
            ],
          ),
          footer: CourtActionBar(
            primary: CourtPrimaryButton(
              onPressed: () => activated = true,
              child: const Text('Änderungen jetzt speichern'),
            ),
          ),
        ),
        scale: 2,
        keyboard: 300,
      );
      final button = find.text('Änderungen jetzt speichern');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pump();
      expect(activated, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'action focus can traverse and activate without decorative images taking focus',
    (tester) async {
      var count = 0;
      await host(
        tester,
        CourtScaffold(
          body: const Center(child: CourtBrandMark()),
          footer: CourtActionBar(
            primary: CourtPrimaryButton(
              onPressed: () => count++,
              child: const Text('Weiter'),
            ),
            secondary: CourtSecondaryButton(
              onPressed: () {},
              child: const Text('Zurück'),
            ),
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(count, 1);
    },
  );
}
