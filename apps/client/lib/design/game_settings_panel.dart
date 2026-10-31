import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import 'court_assets.dart';
import 'court_scene.dart';
import 'court_theme.dart';
import 'illustrated_paper.dart';
import 'setting_label.dart';

/// Shared proportional paper for local setup and online room administration.
class GameSettingsPanel extends StatelessWidget {
  const GameSettingsPanel({
    required this.cases,
    required this.rules,
    required this.factorTenths,
    required this.maxCases,
    required this.maxRules,
    required this.onCasesChanged,
    required this.onRulesChanged,
    required this.onFactorChanged,
    this.playerCount,
    this.onChangeEnd,
    this.enabled = true,
    this.allJudges,
    this.contentLanguage,
    this.onAllJudgesChanged,
    this.onLanguageChanged,
    super.key,
  });
  final int cases, rules, factorTenths, maxCases, maxRules;
  final int? playerCount;
  final bool enabled;
  final bool? allJudges;
  final String? contentLanguage;
  final ValueChanged<bool>? onAllJudgesChanged;
  final ValueChanged<String>? onLanguageChanged;
  final ValueChanged<int>? onCasesChanged, onRulesChanged, onFactorChanged;
  final VoidCallback? onChangeEnd;
  static const assetSize = Size(1080, 1400);
  static const sourceContentRect = Rect.fromLTRB(124, 330, 966, 1224);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final width = math.min(PaperGeometry.maxWidth, bounds.maxWidth);
      final paper = PaperGeometry.fit(
        Size(width, width * assetSize.height / assetSize.width),
        assetSize,
      );
      final scale = paper.size.width / 400;
      final online = allJudges != null;
      final multiplier = factorTenths % 10 == 0
          ? '${factorTenths ~/ 10}×'
          : '${(factorTenths / 10).toStringAsFixed(1).replaceAll('.', AppLanguageScope.of(context).language == 'de' ? ',' : '.')}×';
      Widget divider() => SizedBox(
        height: (online ? 6 : 10) * scale,
        child: PaperDivider(scale: scale),
      );
      return Align(
        alignment: Alignment.topCenter,
        heightFactor: 1,
        child: IgnorePointer(
          ignoring: !enabled,
          child: Opacity(
            opacity: enabled ? 1 : .55,
            child: Theme(
              data: courtPaperTheme(),
              child: SizedBox.fromSize(
                key: const ValueKey('game-settings-paper'),
                size: paper.size,
                child: Stack(
                  children: [
                    Positioned.fill(child: CourtArt(CourtAssets.settingsPanel)),
                    Positioned.fromRect(
                      rect: paper.mapRect(sourceContentRect),
                      child: Column(
                        key: const ValueKey('game-settings-content'),
                        children: [
                          if (online) ...[
                            Expanded(
                              flex: 2,
                              child: _PanelOption(
                                key: const ValueKey('room-all-judges'),
                                leading: CourtArt(CourtAssets.gavel),
                                title: context.tr('onlineAllJudges'),
                                helpKey: 'gameRulesAllJudgesBody',
                                scale: scale,
                                controlWidth: 64,
                                control: FittedBox(
                                  child: Switch(
                                    value: allJudges!,
                                    onChanged: enabled
                                        ? onAllJudgesChanged
                                        : null,
                                    activeTrackColor: CourtSceneTokens.crimson,
                                    activeThumbColor: CourtSceneTokens.cream,
                                    inactiveThumbColor: CourtSceneTokens.cream,
                                    inactiveTrackColor: CourtTokens.border,
                                    trackOutlineColor:
                                        const WidgetStatePropertyAll(
                                          CourtSceneTokens.gold,
                                        ),
                                  ),
                                ),
                              ),
                            ),
                            divider(),
                          ],
                          Expanded(
                            flex: 3,
                            child: _Setting(
                              id: 'cases',
                              asset: CourtAssets.settingsCases,
                              title: context.tr('settingsCasesTitle'),
                              helpKey: 'localCasesHelp',
                              value: cases,
                              display: '$cases',
                              min: 10,
                              max: math.min(150, maxCases),
                              scale: scale,
                              compact: online,
                              onChanged: enabled ? onCasesChanged : null,
                              onChangeEnd: onChangeEnd,
                            ),
                          ),
                          divider(),
                          Expanded(
                            flex: 3,
                            child: _Setting(
                              id: 'rules',
                              asset: CourtAssets.settingsRules,
                              title: context.tr('settingsRulesTitle'),
                              helpKey: 'localRulesHelp',
                              value: rules,
                              display: '$rules',
                              min: 0,
                              max: maxRules,
                              scale: scale,
                              compact: online,
                              onChanged: enabled ? onRulesChanged : null,
                              onChangeEnd: onChangeEnd,
                            ),
                          ),
                          divider(),
                          Expanded(
                            flex: 3,
                            child: _Setting(
                              id: 'numbers',
                              asset: CourtAssets.settingsNumbers,
                              title: context.tr('factorLabel'),
                              helpKey: 'localFactorHelp',
                              value: factorTenths,
                              display: multiplier,
                              min: 10,
                              max: 40,
                              step: 5,
                              scale: scale,
                              compact: online,
                              onChanged: enabled ? onFactorChanged : null,
                              onChangeEnd: onChangeEnd,
                            ),
                          ),
                          if (online) ...[
                            divider(),
                            Expanded(
                              flex: 2,
                              child: _PanelOption(
                                leading: const Icon(
                                  Icons.translate,
                                  color: CourtTokens.ink,
                                ),
                                title: context.tr('settingsLanguageTitle'),
                                helpKey: 'settingsLanguageHelp',
                                scale: scale,
                                controlWidth: 88,
                                control: Container(
                                  decoration: BoxDecoration(
                                    color: CourtSceneTokens.crimson,
                                    borderRadius: BorderRadius.circular(
                                      9 * scale,
                                    ),
                                    border: Border.all(
                                      color: CourtSceneTokens.gold,
                                      width: 1.5 * scale,
                                    ),
                                    boxShadow: kElevationToShadow[1],
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 5 * scale,
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      key: ValueKey(
                                        'online-language-${contentLanguage ?? 'de'}',
                                      ),
                                      value: contentLanguage ?? 'de',
                                      isExpanded: true,
                                      dropdownColor: CourtSceneTokens.crimson,
                                      iconEnabledColor: CourtSceneTokens.cream,
                                      iconDisabledColor: CourtSceneTokens.cream,
                                      iconSize: 18 * scale,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium!
                                          .copyWith(
                                            color: CourtSceneTokens.cream,
                                            fontSize: 14 * scale,
                                          ),
                                      selectedItemBuilder: (context) => [
                                        for (final language in [
                                          'Deutsch',
                                          'English',
                                        ])
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(language),
                                          ),
                                      ],
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'de',
                                          child: Text('Deutsch'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'en',
                                          child: Text('English'),
                                        ),
                                      ],
                                      onChanged:
                                          enabled && onLanguageChanged != null
                                          ? (value) {
                                              if (value != null) {
                                                onLanguageChanged!(value);
                                              }
                                            }
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _PanelOption extends StatelessWidget {
  const _PanelOption({
    required this.leading,
    required this.title,
    required this.helpKey,
    required this.control,
    required this.controlWidth,
    required this.scale,
    super.key,
  });
  final Widget leading, control;
  final String title, helpKey;
  final double controlWidth, scale;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 42 * scale,
        height: 42 * scale,
        child: FittedBox(
          child: SizedBox(width: 42, height: 42, child: leading),
        ),
      ),
      SizedBox(width: 6 * scale),
      Expanded(
        child: SettingLabel(
          controlScale: scale,
          helpKey: helpKey,
          title: FittedPaperText(
            title,
            height: 40 * scale,
            min: 7 * scale,
            max: 18 * scale,
            weight: FontWeight.w700,
            alignment: Alignment.centerLeft,
            textAlign: TextAlign.left,
          ),
        ),
      ),
      SizedBox(width: 6 * scale),
      SizedBox(width: controlWidth * scale, height: 36 * scale, child: control),
    ],
  );
}

class _Setting extends StatelessWidget {
  const _Setting({
    required this.id,
    required this.asset,
    required this.title,
    required this.helpKey,
    required this.value,
    required this.display,
    required this.min,
    required this.max,
    required this.scale,
    required this.onChanged,
    required this.onChangeEnd,
    this.compact = false,
    this.step = 1,
  });
  final String id, asset, title, helpKey, display;
  final bool compact;
  final int step;
  final int value, min, max;
  final double scale;
  final ValueChanged<int>? onChanged;
  final VoidCallback? onChangeEnd;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      SizedBox(
        height: (compact ? 40 : 50) * scale,
        child: Row(
          children: [
            CourtArt(
              asset,
              width: (compact ? 40 : 50) * scale,
              height: (compact ? 40 : 50) * scale,
            ),
            SizedBox(width: 6 * scale),
            Expanded(
              child: SettingLabel(
                helpKey: helpKey,
                controlScale: scale,
                title: FittedPaperText(
                  title,
                  height: (compact ? 38 : 48) * scale,
                  min: 8 * scale,
                  max: 20 * scale,
                  weight: FontWeight.w700,
                  alignment: Alignment.centerLeft,
                  textAlign: TextAlign.left,
                ),
              ),
            ),
            SizedBox(width: 6 * scale),
            Container(
              key: ValueKey('settings-$id-value'),
              width: 58 * scale,
              height: 38 * scale,
              alignment: Alignment.center,
              padding: EdgeInsets.all(4 * scale),
              decoration: BoxDecoration(
                color: CourtSceneTokens.crimson,
                borderRadius: BorderRadius.circular(9 * scale),
                border: Border.all(
                  color: CourtSceneTokens.gold,
                  width: 1.5 * scale,
                ),
                boxShadow: kElevationToShadow[1],
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  display,
                  style: Theme.of(context).textTheme.titleLarge!.copyWith(
                    fontSize: 23 * scale,
                    fontWeight: FontWeight.w700,
                    color: CourtSceneTokens.cream,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      SizedBox(
        height: (compact ? 30 : 38) * scale,
        child: SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4 * scale,
            activeTrackColor: CourtSceneTokens.crimson,
            inactiveTrackColor: CourtTokens.ink.withValues(alpha: .18),
            thumbColor: CourtSceneTokens.crimson,
            disabledThumbColor: CourtTokens.border,
            disabledActiveTrackColor: CourtTokens.border,
            disabledInactiveTrackColor: CourtTokens.ink.withValues(alpha: .12),
            activeTickMarkColor: CourtSceneTokens.gold,
            inactiveTickMarkColor: CourtTokens.ink.withValues(alpha: .45),
            overlayColor: CourtSceneTokens.crimson.withValues(alpha: .12),
            overlayShape: RoundSliderOverlayShape(overlayRadius: 18 * scale),
            thumbShape: _OutlinedThumb(scale),
            trackShape: _SettingsTrack(
              scale,
              divisions: math.max(1, math.min(10, (max - min) ~/ step)),
            ),
            tickMarkShape: SliderTickMarkShape.noTickMark,
            showValueIndicator: ShowValueIndicator.never,
          ),
          child: Slider(
            key: ValueKey('settings-$id-slider'),
            value: value.clamp(min, max).toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max > min ? (max - min) ~/ step : null,
            semanticFormatterCallback: (_) => '$title: $display',
            onChanged: max > min && onChanged != null
                ? (next) => onChanged!(next.round())
                : null,
            onChangeEnd: onChanged != null && onChangeEnd != null
                ? (_) => onChangeEnd!()
                : null,
          ),
        ),
      ),
    ],
  );
}

/// Sparse visual markers stay legible even with 490 discrete case steps.
/// The Slider still owns its original divisions and input handling.
class _SettingsTrack extends RoundedRectSliderTrackShape {
  const _SettingsTrack(this.scale, {required this.divisions});
  final double scale;
  final int divisions;

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
  }) {
    super.paint(
      context,
      offset,
      parentBox: parentBox,
      sliderTheme: sliderTheme,
      enableAnimation: enableAnimation,
      textDirection: textDirection,
      thumbCenter: thumbCenter,
      secondaryOffset: secondaryOffset,
      isDiscrete: isDiscrete,
      isEnabled: isEnabled,
      additionalActiveTrackHeight: scale,
    );
    final track = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    for (var index = 0; index <= divisions; index++) {
      final center = Offset(
        track.left + track.width * index / divisions,
        track.center.dy,
      );
      final active = textDirection == TextDirection.ltr
          ? center.dx <= thumbCenter.dx
          : center.dx >= thumbCenter.dx;
      context.canvas.drawCircle(
        center,
        scale,
        Paint()
          ..color = ColorTween(
            begin: active
                ? sliderTheme.disabledActiveTickMarkColor
                : sliderTheme.disabledInactiveTickMarkColor,
            end: active
                ? sliderTheme.activeTickMarkColor
                : sliderTheme.inactiveTickMarkColor,
          ).evaluate(enableAnimation)!,
      );
    }
  }
}

class _OutlinedThumb extends RoundSliderThumbShape {
  _OutlinedThumb(this.scale)
    : super(enabledThumbRadius: 9 * scale, elevation: 1);
  final double scale;

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    super.paint(
      context,
      center,
      activationAnimation: activationAnimation,
      enableAnimation: enableAnimation,
      isDiscrete: isDiscrete,
      labelPainter: labelPainter,
      parentBox: parentBox,
      sliderTheme: sliderTheme,
      textDirection: textDirection,
      value: value,
      textScaleFactor: textScaleFactor,
      sizeWithOverflow: sizeWithOverflow,
    );
    context.canvas.drawCircle(
      center,
      9 * scale,
      Paint()
        ..color = CourtTokens.ink.withValues(alpha: .55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = scale,
    );
  }
}
