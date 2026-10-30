import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'court_assets.dart';
import 'court_theme.dart';
import 'court_scene.dart';
import '../l10n/app_strings.dart';

class CasePaperScope extends InheritedWidget {
  const CasePaperScope({
    required this.maxHeight,
    required super.child,
    super.key,
  });
  final double maxHeight;
  static double? heightOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CasePaperScope>()?.maxHeight;
  @override
  bool updateShouldNotify(CasePaperScope oldWidget) =>
      maxHeight != oldWidget.maxHeight;
}

abstract final class PaperImages {
  static const caseImage = AssetImage(CourtAssets.caseSheet);
  static const ruleImage = AssetImage(CourtAssets.ruleSheet);
  static const providers = [caseImage, ruleImage];
}

/// Keeps the two decoded papers alive across routes and case/rule changes.
/// Providers and decode keys do not depend on the text, round or viewport size.
class PaperAssetWarmup extends StatefulWidget {
  const PaperAssetWarmup({required this.child, super.key});
  final Widget child;
  @override
  State<PaperAssetWarmup> createState() => _PaperAssetWarmupState();
}

class _PaperAssetWarmupState extends State<PaperAssetWarmup> {
  AssetBundle? _bundle;
  final _streams = <ImageStream>[];
  late final _listener = ImageStreamListener(
    (image, _) => image.dispose(),
    onError: (Object _, StackTrace? _) {},
  );
  void _release() {
    for (final stream in _streams) {
      stream.removeListener(_listener);
    }
    _streams.clear();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bundle = DefaultAssetBundle.of(context);
    if (_bundle == bundle) return;
    _release();
    _bundle = bundle;
    for (final provider in PaperImages.providers) {
      final stream = provider.resolve(createLocalImageConfiguration(context));
      _streams.add(stream);
      stream.addListener(_listener);
    }
  }

  @override
  void dispose() {
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Nine-slice only the empty paper: the seal and rolled edges keep their shape.
class IllustratedPaper extends StatefulWidget {
  const IllustratedPaper({
    required this.rule,
    required this.height,
    required this.child,
    this.growToContent = false,
    this.asset,
    this.slice,
    this.proportional = false,
    super.key,
  });
  final bool growToContent;
  final bool proportional;
  final String? asset;
  final Rect? slice;
  final bool rule;
  final double height;
  final Widget child;
  @override
  State<IllustratedPaper> createState() => _IllustratedPaperState();
}

class _IllustratedPaperState extends State<IllustratedPaper> {
  ImageStream? _stream;
  ImageInfo? _image;
  AssetBundle? _bundle;
  late final _listener = ImageStreamListener((image, sync) {
    final previous = _image;
    if (sync) {
      _image = image;
    } else if (mounted) {
      setState(() => _image = image);
    } else {
      image.dispose();
    }
    if (previous != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
    }
  }, onError: (Object _, StackTrace? _) {});
  void _bind() {
    final bundle = DefaultAssetBundle.of(context);
    if (_bundle == bundle && _stream != null) return;
    _stream?.removeListener(_listener);
    _bundle = bundle;
    _stream =
        (widget.asset != null
                ? AssetImage(widget.asset!)
                : widget.rule
                ? PaperImages.ruleImage
                : PaperImages.caseImage)
            .resolve(createLocalImageConfiguration(context));
    _stream!.addListener(_listener);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bind();
  }

  @override
  void didUpdateWidget(IllustratedPaper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rule != widget.rule || oldWidget.asset != widget.asset) {
      final previous = _image;
      _image = null;
      if (previous != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
      }
      _bundle = null;
      _bind();
    }
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    final previous = _image;
    if (previous != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = LayoutBuilder(
      builder: (context, constraints) {
        final image = _image?.image;
        final slice =
            widget.slice ??
            (widget.rule
                ? const Rect.fromLTRB(120, 400, 640, 800)
                : const Rect.fromLTRB(150, 600, 870, 1100));
        return Stack(
          fit: widget.growToContent ? StackFit.loose : StackFit.expand,
          children: [
            Positioned.fill(
              child: image != null
                  ? ExcludeSemantics(
                      child: CustomPaint(
                        painter: PaperBackgroundPainter(
                          image,
                          slice,
                          proportional: widget.proportional,
                        ),
                      ),
                    )
                  : const ColoredBox(color: CourtSceneTokens.parchment),
            ),
            widget.child,
          ],
        );
      },
    );
    return widget.growToContent
        ? ConstrainedBox(
            constraints: BoxConstraints(minHeight: widget.height),
            child: content,
          )
        : SizedBox(height: widget.height, child: content);
  }
}

const paperInk = CourtTokens.ink;
TextStyle paperTextStyle(double size, {FontWeight weight = FontWeight.w500}) =>
    TextStyle(
      inherit: false,
      fontFamily: 'CourtRoboto',
      fontSize: size,
      height: 1.25,
      fontWeight: weight,
      color: paperInk,
    );

Size measurePaperText(
  String text,
  double width,
  double fontSize,
  TextScaler scaler,
  TextDirection direction, {
  FontWeight weight = FontWeight.w500,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: paperTextStyle(fontSize, weight: weight),
    ),
    textDirection: direction,
    textScaler: scaler,
  )..layout(maxWidth: width);
  final size = painter.size;
  painter.dispose();
  return size;
}

double fitPaperFont(
  String text,
  Size bounds,
  TextScaler scaler,
  TextDirection direction, {
  double min = 16,
  double max = 28,
  FontWeight weight = FontWeight.w500,
}) {
  var low = min, high = max;
  for (var i = 0; i < 12; i++) {
    final middle = (low + high) / 2;
    final size = measurePaperText(
      text,
      bounds.width,
      middle,
      scaler,
      direction,
      weight: weight,
    );
    if (size.height <= bounds.height && size.width <= bounds.width + .01) {
      low = middle;
    } else {
      high = middle;
    }
  }
  return low;
}

class FittedPaperText extends StatelessWidget {
  const FittedPaperText(
    this.text, {
    required this.height,
    this.min = 16,
    this.max = 28,
    this.weight = FontWeight.w500,
    super.key,
  });
  final String text;
  final double height, min, max;
  final FontWeight weight;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: LayoutBuilder(
      builder: (context, bounds) => Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: paperTextStyle(
            fitPaperFont(
              text,
              Size(bounds.maxWidth, height),
              MediaQuery.textScalerOf(context),
              Directionality.of(context),
              min: min,
              max: max,
              weight: weight,
            ),
            weight: weight,
          ),
        ),
      ),
    ),
  );
}

class PaperDivider extends StatelessWidget {
  const PaperDivider({super.key});
  @override
  Widget build(BuildContext context) => const Row(
    children: [
      Expanded(child: Divider(color: Color(0xFFBD9665))),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 10),
        child: Icon(Icons.diamond_outlined, size: 14, color: Color(0xFFBD9665)),
      ),
      Expanded(child: Divider(color: Color(0xFFBD9665))),
    ],
  );
}

/// Coordinates measured on fallakte_pergament_leer.png (1024 x 1536).
/// The seal overlaps the front sheet; content starts just beneath it.
class CaseCardGeometry {
  CaseCardGeometry.fit(Size available) {
    final scale = math.min(
      available.width / assetSize.width,
      available.height / assetSize.height,
    );
    size = Size(assetSize.width * scale, assetSize.height * scale);
    frontCardRect = _scaled(sourceFrontCardRect, scale);
    contentRect = _scaled(sourceContentRect, scale);
  }
  static const assetSize = Size(1024, 1536);
  static const sourceFrontCardRect = Rect.fromLTRB(112, 192, 920, 1360);
  static const sourceContentRect = Rect.fromLTRB(140, 326, 892, 1324);
  late final Size size;
  late final Rect frontCardRect, contentRect;
  static Rect _scaled(Rect rect, double scale) => Rect.fromLTRB(
    rect.left * scale,
    rect.top * scale,
    rect.right * scale,
    rect.bottom * scale,
  );
}

class IllustratedQuestion extends StatelessWidget {
  const IllustratedQuestion({
    required this.label,
    required this.text,
    required this.low,
    required this.high,
    required this.maximum,
    required this.showRefresh,
    this.onRefresh,
    super.key,
  });
  final String label, text, low, high;
  final int maximum;
  final bool showRefresh;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final width = math.min(560.0, bounds.maxWidth);
      final scopedHeight = CasePaperScope.heightOf(context);
      final height = math.min(
        scopedHeight ?? double.infinity,
        bounds.hasBoundedHeight ? bounds.maxHeight : width * 1.5,
      );
      final geometry = CaseCardGeometry.fit(Size(width, math.max(1, height)));
      final content = geometry.contentRect;
      final spacer = math.min(
        (content.height * .018).clamp(4.0, 12.0),
        content.height * .03,
      );
      final headerHeight = math.min(
        (content.height * .085).clamp(24.0, 34.0),
        content.height * .18,
      );
      final footerHeight = math.min(
        (content.height * .34).clamp(108.0, 140.0),
        content.height * .55,
      );
      return Align(
        alignment: Alignment.topCenter,
        heightFactor: 1,
        child: SizedBox.fromSize(
          size: geometry.size,
          child: Stack(
            children: [
              IllustratedPaper(
                rule: false,
                height: geometry.size.height,
                proportional: true,
                child: const SizedBox.expand(),
              ),
              Positioned.fromRect(
                rect: geometry.frontCardRect,
                child: const IgnorePointer(
                  child: SizedBox(key: ValueKey('case-front-card')),
                ),
              ),
              Positioned.fromRect(
                rect: content,
                child: Column(
                  key: const ValueKey('case-content'),
                  children: [
                    SizedBox(
                      key: const ValueKey('case-top-spacer'),
                      height: spacer,
                    ),
                    SizedBox(
                      key: const ValueKey('case-header'),
                      height: headerHeight,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: Column(
                              children: [
                                Expanded(
                                  child: _CaseLabel(
                                    label.toUpperCase(),
                                    min: 10,
                                    max: 14,
                                    weight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(
                                  height: 7,
                                  child: PaperDivider(),
                                ),
                              ],
                            ),
                          ),
                          if (showRefresh)
                            Positioned(
                              top: -10,
                              right: -8,
                              child: IconButton(
                                key: const ValueKey('case-paper-refresh'),
                                tooltip: context.tr('refreshQuestion'),
                                onPressed: onRefresh,
                                color: paperInk,
                                disabledColor: Colors.black38,
                                icon: const Icon(Icons.refresh),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: _CaseQuestionText(text, key: ValueKey(text)),
                      ),
                    ),
                    SizedBox(
                      height: footerHeight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.bottomCenter,
                        child: SizedBox(
                          width: math.max(160, content.width),
                          height: math.max(108, footerHeight),
                          child: _CaseScaleFooter(
                            low: low,
                            high: high,
                            maximum: maximum,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Fit the question alone, preserving a readable minimum. Only this area scrolls.
class _CaseQuestionText extends StatefulWidget {
  const _CaseQuestionText(this.text, {super.key});
  final String text;
  @override
  State<_CaseQuestionText> createState() => _CaseQuestionTextState();
}

class _CaseQuestionTextState extends State<_CaseQuestionText> {
  final _scroll = ScrollController();
  String get text => widget.text;
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, area) {
      final scaler = MediaQuery.textScalerOf(context);
      final direction = Directionality.of(context);
      final font = fitPaperFont(
        text,
        area.biggest,
        scaler,
        direction,
        min: 16,
        max: 28,
      );
      final overflows =
          measurePaperText(text, area.maxWidth, 16, scaler, direction).height >
          area.maxHeight;
      final question = Text(
        text,
        style: paperTextStyle(font),
        textAlign: TextAlign.center,
      );
      return SizedBox.expand(
        key: const ValueKey('case-question-area'),
        child: overflows
            ? Scrollbar(
                controller: _scroll,
                child: SingleChildScrollView(
                  key: const ValueKey('case-question-scroll'),
                  controller: _scroll,
                  primary: false,
                  child: question,
                ),
              )
            : Align(alignment: Alignment.topCenter, child: question),
      );
    },
  );
}

/// At most two lines for scale endpoints, with a small local font adjustment.
/// This never scales the card, the question or neighbouring layout regions.
class _CaseLabel extends StatelessWidget {
  const _CaseLabel(
    this.text, {
    this.min = 10,
    this.max = 16,
    this.lines = 1,
    this.weight = FontWeight.w500,
    this.align = TextAlign.center,
  });
  final String text;
  final double min, max;
  final int lines;
  final FontWeight weight;
  final TextAlign align;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, area) {
      final scaler = MediaQuery.textScalerOf(context);
      final direction = Directionality.of(context);
      bool fits(double font) {
        final painter = TextPainter(
          text: TextSpan(
            text: text,
            style: paperTextStyle(font, weight: weight),
          ),
          textScaler: scaler,
          textDirection: direction,
          maxLines: lines,
        )..layout(maxWidth: area.maxWidth);
        final result =
            !painter.didExceedMaxLines && painter.height <= area.maxHeight;
        painter.dispose();
        return result;
      }

      var low = min, high = max;
      for (var i = 0; i < 10; i++) {
        final middle = (low + high) / 2;
        if (fits(middle)) {
          low = middle;
        } else {
          high = middle;
        }
      }
      return Tooltip(
        message: text,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: area.maxWidth,
            child: Text(
              text,
              semanticsLabel: text,
              style: paperTextStyle(low, weight: weight),
              textAlign: align,
              maxLines: lines,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      );
    },
  );
}

class _CaseScaleFooter extends StatelessWidget {
  const _CaseScaleFooter({
    required this.low,
    required this.high,
    required this.maximum,
  });
  final String low, high;
  final int maximum;
  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('question-range-box'),
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(
      color: const Color(0x2DB18548),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0x668D6C43)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 16,
          child: _CaseLabel(
            context.tr('questionRange', {'max': maximum}),
            max: 14,
            weight: FontWeight.w700,
            align: TextAlign.start,
          ),
        ),
        const SizedBox(height: 4),
        Expanded(child: _endpoint('1', low)),
        const SizedBox(height: 4),
        Expanded(child: _endpoint('$maximum', high)),
      ],
    ),
  );
  Widget _endpoint(String number, String text) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0x24A87C3C),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: CourtSceneTokens.crimson,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: Text(
                      number,
                      style: const TextStyle(
                        color: CourtSceneTokens.cream,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 5),
          Expanded(child: _CaseLabel(text, lines: 2)),
        ],
      ),
    ),
  );
}

class CaseProgressHeader extends StatelessWidget {
  const CaseProgressHeader({
    required this.completed,
    required this.total,
    required this.rules,
    required this.onRules,
    super.key,
  });
  final int completed, total, rules;
  final VoidCallback onRules;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.tr('casesCompleted', {
                  'done': completed,
                  'total': total,
                }),
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: (completed / total).clamp(0, 1),
                color: CourtSceneTokens.gold,
                backgroundColor: const Color(0x66563B2F),
                minHeight: 5,
                borderRadius: BorderRadius.circular(4),
                semanticsLabel: context.tr('completedCases'),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        IconButton(
          tooltip: context.tr('activeRules'),
          onPressed: onRules,
          icon: Badge(
            label: Text('$rules'),
            child: const Icon(Icons.menu_book_outlined),
          ),
        ),
      ],
    ),
  );
}

class IllustratedRule extends StatelessWidget {
  const IllustratedRule({required this.title, required this.text, super.key});
  final String title, text;
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth,
              pad = width * .14,
              inner = width - pad * 2;
          final scaler = MediaQuery.textScalerOf(context),
              direction = Directionality.of(context);
          final top = width * .36, bottom = width * .16;
          final heading = measurePaperText(
            title,
            inner,
            26,
            scaler,
            direction,
            weight: FontWeight.w700,
          ).height;
          final penalty = context.tr('oneSipPerViolation');
          final penaltyHeight = math.max(
            32.0,
            measurePaperText(penalty, inner - 48, 14, scaler, direction).height,
          );
          final body = math.max(
            width * .48,
            measurePaperText(text, inner, 16, scaler, direction).height,
          );
          final naturalHeight = math.max(
            width * 1083 / 768,
            top + heading + 28 + body + 28 + penaltyHeight + bottom,
          );
          final viewport = CasePaperScope.heightOf(context);
          final height = viewport ?? naturalHeight;
          return IllustratedPaper(
            rule: true,
            growToContent: viewport == null,
            height: height,
            child: Padding(
              padding: EdgeInsets.fromLTRB(pad, top, pad, bottom),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: inner,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: paperTextStyle(
                          26,
                          weight: FontWeight.w700,
                        ).copyWith(color: const Color(0xFF79152A)),
                      ),
                      const SizedBox(height: 20, child: PaperDivider()),
                      const SizedBox(height: 8),
                      FittedPaperText(text, height: body),
                      const SizedBox(height: 28),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.sports_bar_outlined,
                            size: 28,
                            color: paperInk,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(penalty, style: paperTextStyle(14)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

/// Scale the nine-slice canvas directly to avoid float equality in paintImage.
class PaperBackgroundPainter extends CustomPainter {
  const PaperBackgroundPainter(
    this.image,
    this.slice, {
    this.proportional = false,
  });
  final ui.Image image;
  final Rect slice;
  final bool proportional;
  @override
  void paint(Canvas canvas, Size size) {
    if (proportional) {
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Offset.zero & size,
        Paint()..filterQuality = FilterQuality.medium,
      );
      return;
    }
    final scale = size.width / image.width;
    canvas.save();
    canvas.scale(scale);
    canvas.drawImageNine(
      image,
      slice,
      Rect.fromLTWH(0, 0, image.width.toDouble(), size.height / scale),
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(PaperBackgroundPainter oldDelegate) =>
      oldDelegate.image != image ||
      oldDelegate.slice != slice ||
      oldDelegate.proportional != proportional;
}
