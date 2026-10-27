import 'package:flutter/material.dart';

import '../features/home/home_screen.dart';
import '../design/court_theme.dart';

class TrinktribunalApp extends StatelessWidget {
  const TrinktribunalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trinktribunal',
      debugShowCheckedModeBanner: false,
      theme: courtTheme(),
      home: const HomeScreen(),
    );
  }
}
