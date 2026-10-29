import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'court_assets.dart';
import 'court_theme.dart';

abstract final class CourtSceneTokens {
  static const night = Color(0xFF26130D);
  static const panel = Color(0xFF382017);
  static const cream = Color(0xFFFFF1D7);
  static const gold = Color(0xFFE9BC73);
  static const parchment = Color(0xFFF7E5C3);
  static const crimson = Color(0xFF9F1732);
}

final _sceneTheme = _buildSceneTheme();
final _paperTheme = _buildPaperTheme();
ThemeData courtSceneTheme() => _sceneTheme;
ThemeData courtPaperTheme() => _paperTheme;

ThemeData _buildSceneTheme() {
  final base = courtTheme();
  return base.copyWith(
    brightness: Brightness.dark,
    iconTheme: const IconThemeData(color: CourtSceneTokens.cream),
    scaffoldBackgroundColor: CourtSceneTokens.night,
    bottomSheetTheme: const BottomSheetThemeData(
      dragHandleColor: CourtSceneTokens.panel,
    ),
    colorScheme: const ColorScheme.dark(
      primary: CourtSceneTokens.gold,
      onPrimary: CourtSceneTokens.night,
      primaryContainer: Color(0xFF5C3B21),
      onPrimaryContainer: CourtSceneTokens.cream,
      secondary: CourtSceneTokens.gold,
      onSecondary: CourtSceneTokens.night,
      secondaryContainer: Color(0xFF4A2C1E),
      onSecondaryContainer: CourtSceneTokens.cream,
      surface: CourtSceneTokens.panel,
      onSurface: CourtSceneTokens.cream,
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: CourtSceneTokens.cream,
      displayColor: CourtSceneTokens.cream,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xF226130D),
      foregroundColor: CourtSceneTokens.cream,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: 'CourtRoboto',
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: CourtSceneTokens.cream,
      ),
    ),
    cardTheme: CardThemeData(
      color: CourtSceneTokens.panel,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: CourtSceneTokens.gold),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: CourtSceneTokens.panel,
      border: OutlineInputBorder(),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: CourtSceneTokens.cream,
        side: const BorderSide(color: CourtSceneTokens.gold),
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: CourtSceneTokens.cream,
        minimumSize: const Size(48, 48),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: CourtSceneTokens.crimson,
        foregroundColor: CourtSceneTokens.cream,
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
  );
}

ThemeData _buildPaperTheme() {
  final base = courtTheme();
  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      surface: CourtSceneTokens.parchment,
      onSurface: CourtTokens.ink,
      primary: CourtSceneTokens.crimson,
      onPrimary: CourtSceneTokens.cream,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: CourtTokens.file,
      border: OutlineInputBorder(),
    ),
  );
}

/// Decorative imagery is never a control or a source of game text.
class CourtArt extends StatelessWidget {
  const CourtArt(
    this.asset, {
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.fallback,
    super.key,
  });
  final String asset;
  final double? width, height;
  final BoxFit fit;
  final Alignment alignment;
  final Widget? fallback;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final logicalWidth = width?.isFinite == true
          ? width!
          : (constraints.hasBoundedWidth ? constraints.maxWidth : 256);
      final pixels =
          (logicalWidth * math.min(3, MediaQuery.devicePixelRatioOf(context)))
              .ceil();
      final decodeWidth = pixels.clamp(
        1,
        CourtAssets.nativeWidths[asset] ?? 1080,
      );
      return Image(
        image: ResizeImage(
          ExactAssetImage(asset, bundle: DefaultAssetBundle.of(context)),
          width: decodeWidth,
        ),
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        excludeFromSemantics: true,
        errorBuilder: (_, _, _) =>
            SizedBox(width: width, height: height, child: fallback),
      );
    },
  );
}

class CourtBrandMark extends StatelessWidget {
  const CourtBrandMark({this.width = 300, super.key});
  final double width;
  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'Trinktribunal',
    excludeSemantics: true,
    child: CourtArt(
      CourtAssets.logo,
      width: width,
      height: width * 840 / 1024,
      fallback: Center(
        child: Text(
          'Trinktribunal',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
      ),
    ),
  );
}

class CourtScaffold extends StatelessWidget {
  const CourtScaffold({
    this.body,
    this.bodyBuilder,
    this.title,
    this.centerTitle,
    this.actions,
    this.leading,
    this.appBarBottom,
    this.footer,
    this.background = CourtAssets.wood,
    this.maxWidth = CourtTokens.contentWidth,
    super.key,
  }) : assert((body == null) != (bodyBuilder == null));
  final Widget? body;
  final WidgetBuilder? bodyBuilder;
  final Widget? title, leading, footer;
  final bool? centerTitle;
  final List<Widget>? actions;
  final PreferredSizeWidget? appBarBottom;
  final String? background;
  final double maxWidth;
  @override
  Widget build(BuildContext context) => Theme(
    data: courtSceneTheme(),
    child: Builder(
      builder: (context) => Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: CourtSceneTokens.night),
          if (background != null)
            Positioned.fill(
              child: IgnorePointer(
                child: CourtArt(background!, fit: BoxFit.cover),
              ),
            ),
          const Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x6626130D),
                      Color(0x9926130D),
                      Color(0xE626130D),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: title == null
                ? null
                : AppBar(
                    title: title,
                    centerTitle: centerTitle,
                    leading: leading,
                    actions: actions,
                    bottom: appBarBottom,
                  ),
            body: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) => Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxWidth),
                          child: SizedBox(
                            width: double.infinity,
                            child: bodyBuilder?.call(context) ?? body!,
                          ),
                        ),
                      ),
                    ),
                    if (footer != null)
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: constraints.maxHeight * .6,
                        ),
                        child: SingleChildScrollView(
                          child: Center(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: maxWidth),
                              child: footer,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Content-sized opaque paper. Framed PNGs must never sit behind live text.
class CourtPaper extends StatelessWidget {
  const CourtPaper({
    required this.child,
    this.padding = const EdgeInsets.all(24),
    super.key,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Theme(
    data: courtPaperTheme(),
    child: DefaultTextStyle(
      style: courtPaperTheme().textTheme.bodyLarge!.copyWith(
        color: CourtTokens.ink,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: CourtSceneTokens.parchment,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: CourtSceneTokens.gold),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Padding(padding: padding, child: child),
      ),
    ),
  );
}

class CourtActionBar extends StatelessWidget {
  const CourtActionBar({required this.primary, this.secondary, super.key});
  final Widget primary;
  final Widget? secondary;
  @override
  Widget build(BuildContext context) => Theme(
    data: courtSceneTheme(),
    child: ColoredBox(
      color: const Color(0xF226130D),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide =
                constraints.maxWidth >= 600 &&
                MediaQuery.textScalerOf(context).scale(16) <= 24;
            if (wide) {
              return Row(
                children: [
                  if (secondary != null) ...[
                    Expanded(child: secondary!),
                    const SizedBox(width: 12),
                  ],
                  Expanded(child: primary),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (secondary != null) ...[
                  secondary!,
                  const SizedBox(height: 8),
                ],
                primary,
              ],
            );
          },
        ),
      ),
    ),
  );
}

class CourtPrimaryButton extends StatelessWidget {
  const CourtPrimaryButton({
    required this.onPressed,
    required this.child,
    super.key,
  });
  final VoidCallback? onPressed;
  final Widget child;
  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      backgroundColor: CourtSceneTokens.crimson,
      foregroundColor: CourtSceneTokens.cream,
      minimumSize: const Size(48, 52),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    ),
    child: child,
  );
}

class CourtSecondaryButton extends StatelessWidget {
  const CourtSecondaryButton({
    required this.onPressed,
    required this.child,
    super.key,
  });
  final VoidCallback? onPressed;
  final Widget child;
  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      foregroundColor: Theme.of(context).brightness == Brightness.dark
          ? CourtSceneTokens.cream
          : CourtTokens.ink,
      side: BorderSide(
        color: Theme.of(context).brightness == Brightness.dark
            ? CourtSceneTokens.gold
            : CourtSceneTokens.crimson,
      ),
      minimumSize: const Size(48, 52),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    ),
    child: child,
  );
}
