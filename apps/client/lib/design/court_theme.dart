import 'package:flutter/material.dart';

abstract final class CourtTokens {
  static const paper = Color(0xFFF7F0E6);
  static const file = Color(0xFFFFFBF5);
  static const ink = Color(0xFF38251E);
  static const wood = Color(0xFF563B2F);
  static const red = Color(0xFF874B49);
  static const blue = Color(0xFF425F72);
  static const green = Color(0xFF276044);
  static const border = Color(0xFFB5A18E);
  static const double touchTarget = 48;
  static const double contentWidth = 760;
  static const double desktopBreakpoint = 840;
  static const List<double> spacing = [4, 8, 12, 16, 24, 32, 48];

  static int bankColumns(double availableWidth, double textScale) =>
      availableWidth >= 600 && textScale <= 1.5 ? 3 : 2;
  static Duration motionDuration(bool reducedMotion) =>
      reducedMotion ? Duration.zero : const Duration(milliseconds: 140);
}

ThemeData courtTheme() => ThemeData(
  useMaterial3: true,
  fontFamily: 'CourtRoboto',
  scaffoldBackgroundColor: CourtTokens.paper,
  colorScheme: ColorScheme.fromSeed(
    seedColor: CourtTokens.red,
    brightness: Brightness.light,
    surface: CourtTokens.paper,
    onSurface: CourtTokens.ink,
    primary: CourtTokens.red,
    secondary: CourtTokens.blue,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: CourtTokens.paper,
    foregroundColor: CourtTokens.ink,
    centerTitle: false,
  ),
  cardTheme: CardThemeData(
    color: CourtTokens.file,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: CourtTokens.border),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
  ),
  inputDecorationTheme: const InputDecorationTheme(
    border: OutlineInputBorder(),
    filled: true,
    fillColor: CourtTokens.file,
  ),
);
