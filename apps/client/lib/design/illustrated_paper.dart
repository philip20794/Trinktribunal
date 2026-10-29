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
    super.key,
  });
  final bool growToContent;
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
    _stream = (widget.rule ? PaperImages.ruleImage : PaperImages.caseImage)
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
    if (oldWidget.rule != widget.rule) {
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
        final slice = widget.rule
            ? const Rect.fromLTRB(120, 400, 640, 800)
            : const Rect.fromLTRB(150, 600, 870, 1100);
        return Stack(
          fit: widget.growToContent ? StackFit.loose : StackFit.expand,
          children: [
            Positioned.fill(
              child: image != null
                  ? ExcludeSemantics(
                      child: CustomPaint(
                        painter: PaperBackgroundPainter(image, slice),
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
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth,
              pad = width * .15,
              inner = width - pad * 2;
          final scaler = MediaQuery.textScalerOf(context),
              direction = Directionality.of(context);
          final bodyHeight = math.max(
            width * .40,
            measurePaperText(text, inner, 16, scaler, direction).height,
          );
          final numberWidth = math.max(
            34.0,
            measurePaperText(
                  '$maximum',
                  inner,
                  18,
                  scaler,
                  direction,
                  weight: FontWeight.w700,
                ).width +
                10,
          );
          final endpointWidth = math.max(1.0, inner - numberWidth - 40);
          final numberHeight = math.max(40.0, scaler.scale(18) * 1.5 + 22);
          final lowHeight = math.max(
            numberHeight,
            measurePaperText(low, endpointWidth, 14, scaler, direction).height +
                16,
          );
          final highHeight = math.max(
            numberHeight,
            measurePaperText(
                  high,
                  endpointWidth,
                  14,
                  scaler,
                  direction,
                ).height +
                16,
          );
          final scaleHeight =
              measurePaperText(
                context.tr('questionRange', {'max': maximum}),
                inner - 20,
                14,
                scaler,
                direction,
                weight: FontWeight.w700,
              ).height +
              lowHeight +
              highHeight +
              44;
          final viewport = CasePaperScope.heightOf(context);
          final headerHeight = math.max(
            viewport == null ? 48.0 : 28.0,
            measurePaperText(
              label.toUpperCase(),
              inner,
              14,
              scaler,
              direction,
            ).height,
          );
          final top = width * .33, bottom = width * .14;
          final naturalHeight = math.max(
            width * 1.5,
            top + headerHeight + 26 + bodyHeight + 16 + scaleHeight + bottom,
          );
          final height = viewport ?? naturalHeight;
          final contentHeight =
              headerHeight +
              (viewport == null ? 26 : 16) +
              bodyHeight +
              (viewport == null ? 16 : 10) +
              scaleHeight;
          return Stack(
            children: [
              IllustratedPaper(
                rule: false,
                height: height,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(pad, top, pad, bottom),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: inner,
                      height: contentHeight,
                      child: Column(
                        children: [
                          SizedBox(
                            height: headerHeight,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Text(
                                    label.toUpperCase(),
                                    style: paperTextStyle(
                                      14,
                                      weight: FontWeight.w700,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            height: viewport == null ? 18 : 12,
                            child: const PaperDivider(),
                          ),
                          SizedBox(height: viewport == null ? 8 : 4),
                          FittedPaperText(text, height: bodyHeight),
                          SizedBox(height: viewport == null ? 16 : 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0x2DB18548),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0x668D6C43),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  context.tr('questionRange', {'max': maximum}),
                                  style: paperTextStyle(
                                    14,
                                    weight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _endpoint('1', low, lowHeight),
                                const SizedBox(height: 8),
                                _endpoint('$maximum', high, highHeight),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (showRefresh)
                Positioned(
                  top: top - 18,
                  right: pad,
                  child: IconButton(
                    key: const ValueKey('case-paper-refresh'),
                    tooltip: context.tr('refreshQuestion'),
                    onPressed: onRefresh,
                    color: Colors.black,
                    disabledColor: Colors.black38,
                    icon: const Icon(Icons.refresh),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
  Widget _endpoint(String number, String text, double height) => Container(
    constraints: BoxConstraints(minHeight: height),
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(
      color: const Color(0x24A87C3C),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Container(
          constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: CourtSceneTokens.crimson,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            number,
            style: const TextStyle(
              color: CourtSceneTokens.cream,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FittedPaperText(text, height: height - 12, min: 14, max: 20),
        ),
      ],
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
  const PaperBackgroundPainter(this.image, this.slice);
  final ui.Image image;
  final Rect slice;
  @override
  void paint(Canvas canvas, Size size) {
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
      oldDelegate.image != image || oldDelegate.slice != slice;
}
