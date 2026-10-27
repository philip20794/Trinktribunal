import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../application/local_data_providers.dart';
import '../application/settings_controller.dart';
import '../features/home/home_screen.dart';
import '../design/court_theme.dart';
import '../l10n/app_strings.dart';

class TrinktribunalApp extends ConsumerWidget {
  const TrinktribunalApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(settingsControllerProvider);
    ref.watch(settingsProvider);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => _buildApp(controller.value),
    );
  }

  Widget _buildApp(AppSettings settings) => MaterialApp(
    title: 'Trinktribunal',
    debugShowCheckedModeBanner: false,
    locale: Locale(settings.language),
    supportedLocales: const [Locale('de'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: courtTheme(),
    builder: (context, child) => AppLanguageScope(
      language: settings.language,
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations:
              MediaQuery.disableAnimationsOf(context) || settings.reducedMotion,
        ),
        child: child ?? const SizedBox.shrink(),
      ),
    ),
    home: const HomeScreen(),
  );
}
