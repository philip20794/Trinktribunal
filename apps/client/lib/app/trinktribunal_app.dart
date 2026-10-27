import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/local_data_providers.dart';
import '../application/settings_controller.dart';
import '../features/home/home_screen.dart';
import '../design/court_theme.dart';
import '../l10n/app_strings.dart';

class TrinktribunalApp extends ConsumerWidget {
  const TrinktribunalApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(settingsProvider).asData?.value;
    if (controller == null) return _buildApp(const AppSettings());
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => _buildApp(controller.value),
    );
  }

  Widget _buildApp(AppSettings settings) => MaterialApp(
    title: 'Trinktribunal',
    debugShowCheckedModeBanner: false,
    theme: courtTheme(),
    builder: (context, child) => AppLanguageScope(
      language: settings.language,
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: settings.reducedMotion),
        child: child ?? const SizedBox.shrink(),
      ),
    ),
    home: const HomeScreen(),
  );
}
