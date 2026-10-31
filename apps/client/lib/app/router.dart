import 'package:flutter/material.dart';

import 'entry_screen.dart';
import '../features/multiplayer/join.dart';
import '../features/multiplayer/invitation.dart';

Route<void> generateAppRoute(RouteSettings settings) {
  final name = settings.name ?? '/';
  if (name == '/') {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => const AppEntryScreen(),
    );
  }
  final code = codeFromJoinRoute(name);
  return MaterialPageRoute<void>(
    settings: settings,
    builder: (_) => code == null
        ? const JoinRoomScreen(invalidInvite: true)
        : AppEntryScreen(code: code),
  );
}
