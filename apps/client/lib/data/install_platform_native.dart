import 'package:flutter/foundation.dart';

Future<Map<String, dynamic>> installAction(
  String action, [
  String argument = '',
]) async => {
  'web': false,
  'android': defaultTargetPlatform == TargetPlatform.android,
  'standalone': true,
  'apkInstalled': defaultTargetPlatform == TargetPlatform.android,
};

VoidCallback listenInstallChanges(VoidCallback callback) => () {};
