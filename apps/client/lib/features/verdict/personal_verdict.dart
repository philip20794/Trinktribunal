import 'package:flutter/material.dart';

import '../../data/protocol/room_message.dart';
import '../../design/case_file.dart';
import '../../l10n/app_strings.dart';

/// A display of this authenticated recipient's committed result, with no local scoring.
class PersonalVerdict extends StatelessWidget {
  const PersonalVerdict({required this.snapshot, super.key});
  final SnapshotMessage snapshot;
  @override
  Widget build(BuildContext context) {
    final result = snapshot.private.ownResult;
    if (!snapshot.public.config.allJudges ||
        snapshot.public.phase != 'judged' ||
        result == null) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CourtSeal(
          label: context.tr('onlinePersonalErrors', {'count': result.errors}),
        ),
        Text(context.tr('onlinePersonalSips', {'count': result.sips})),
        const TText('onlinePersonalHelp'),
      ],
    );
  }
}
