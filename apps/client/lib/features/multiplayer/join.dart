import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../design/court_scene.dart';
import 'entry_profile.dart';

class JoinRoomScreen extends StatelessWidget {
  const JoinRoomScreen({
    this.initialCode = '',
    this.invalidInvite = false,
    super.key,
  });
  final String initialCode;
  final bool invalidInvite;
  @override
  Widget build(BuildContext context) => CourtScaffold(
    title: const TText('roomJoin'),
    bodyBuilder: (context) => Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: RoomProfileForm(
          create: false,
          initialCode: initialCode,
          invalidInvite: invalidInvite,
        ),
      ),
    ),
  );
}
