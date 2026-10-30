import 'package:flutter/material.dart';

import '../../data/protocol/room_message.dart';
import '../../design/illustrated_paper.dart';
import '../../design/court_scene.dart';
import '../../l10n/app_strings.dart';

/// A display of this authenticated recipient's committed result, with no local scoring.
class PersonalVerdict extends StatelessWidget {
  const PersonalVerdict({required this.snapshot, this.onConfirm, super.key});
  final SnapshotMessage snapshot;
  final VoidCallback? onConfirm;
  @override
  Widget build(BuildContext context) {
    final result = snapshot.private.ownResult;
    if (!snapshot.public.config.allJudges ||
        snapshot.public.phase != 'judged' ||
        result == null) {
      return const SizedBox.shrink();
    }
    if (result.sips == 0) return const SizedBox.shrink();
    return Theme(
      data: courtPaperTheme(),
      child: IllustratedPaper(
        rule: true,
        height: 260,
        growToContent: onConfirm != null,
        child: Padding(
          padding: onConfirm != null
              ? const EdgeInsets.fromLTRB(40, 96, 40, 48)
              : const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.tr('drinkPersonalSips', {'count': result.sips}),
                  textAlign: TextAlign.center,
                  style: paperTextStyle(28, weight: FontWeight.w800),
                ),
                if (onConfirm != null) ...[
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: onConfirm,
                    child: const TText('confirm'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
