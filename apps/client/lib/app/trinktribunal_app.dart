import 'package:flutter/material.dart';

import '../features/home/home_screen.dart';

class TrinktribunalApp extends StatelessWidget {
  const TrinktribunalApp({super.key});

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF38251E);
    const accent = Color(0xFF874B49);
    const paper = Color(0xFFF7F0E6);

    return MaterialApp(
      title: 'Trinktribunal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: paper,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.light,
          surface: paper,
          onSurface: ink,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: paper,
          foregroundColor: ink,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFFFFFBF5),
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFFE1D5C6)),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
