import 'package:flutter/material.dart';

import '../features/home/home_screen.dart';
import '../features/multiplayer/join.dart';
import '../features/multiplayer/invitation.dart';

Route<void> generateAppRoute(RouteSettings settings) {
  final name = settings.name ?? '/';
  if (name == '/') {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => const HomeScreen(),
    );
  }
  final code = codeFromJoinRoute(name);
  return MaterialPageRoute<void>(
    settings: settings,
    builder: (_) =>
        JoinRoomScreen(initialCode: code ?? '', invalidInvite: code == null),
  );
}
