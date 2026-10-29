import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app/trinktribunal_app.dart';
import 'app/url_strategy.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  configureAppUrls();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'CourtRoboto',
    ], await rootBundle.loadString('assets/fonts/roboto_license.txt'));
    yield LicenseEntryWithLineBreaks([
      'Adventurer – DiceBear Avatar',
    ],
        'Originalillustrationen: Lisa Wischofsky.\\n'
        'Quelle: https://www.figma.com/community/file/1184595184137881796\\n'
        'Lizenz: Creative Commons Attribution 4.0 International (CC BY 4.0).\\n'
        'https://creativecommons.org/licenses/by/4.0/\\n'
        'Anpassungen durch Trinktribunal: Oberkörper, Messwand, Schild und Hände.');
  });
  runApp(const ProviderScope(child: TrinktribunalApp()));
}
