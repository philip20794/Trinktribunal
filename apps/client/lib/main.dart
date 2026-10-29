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
    yield LicenseEntryWithLineBreaks(
      ['Spielregeln icons (Lucide/Feather)'],
      await rootBundle.loadString(
        'assets/ui/trinktribunal_spielregeln_assets/LIZENZ-HINWEIS.txt',
      ),
    );
    yield LicenseEntryWithLineBreaks([
      'Adventurer – DiceBear Avatar',
    ], await rootBundle.loadString('assets/avatars/NOTICE.md'));
  });
  runApp(const ProviderScope(child: TrinktribunalApp()));
}
