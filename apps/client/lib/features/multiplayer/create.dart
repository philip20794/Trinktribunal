import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../design/court_scene.dart';
import 'entry_profile.dart';
import 'join.dart';
import 'saved_rooms.dart';

class MultiplayerEntryScreen extends StatelessWidget {
  const MultiplayerEntryScreen({super.key});
  @override
  Widget build(BuildContext context) => CourtScaffold(
    title: const TText('modeMulti'),
    bodyBuilder: (context) => Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const TText('roomEntryIntro'),
            const SizedBox(height: 20),
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const TText('roomCreate'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CreateRoomScreen(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.login),
              label: const TText('roomJoin'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const JoinRoomScreen()),
              ),
            ),
            const SizedBox(height: 20),
            const SavedRooms(),
          ],
        ),
      ),
    ),
  );
}

class CreateRoomScreen extends StatelessWidget {
  const CreateRoomScreen({super.key});
  @override
  Widget build(BuildContext context) => CourtScaffold(
    title: const TText('roomCreate'),
    bodyBuilder: (context) => Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: const RoomProfileForm(create: true),
      ),
    ),
  );
}
