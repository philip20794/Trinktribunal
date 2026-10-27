import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app/trinktribunal_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'CourtRoboto',
    ], await rootBundle.loadString('assets/fonts/roboto_license.txt'));
  });
  runApp(const ProviderScope(child: TrinktribunalApp()));
}
