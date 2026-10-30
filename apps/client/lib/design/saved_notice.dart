import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import 'court_scene.dart';

/// Small root-overlay notice which survives returning from the profile route.
void showSavedNotice(BuildContext context) {
  final label = context.tr('savedNotice');
  final overlay = Overlay.of(context, rootOverlay: true);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _SavedNotice(
      label: label,
      onExpired: () {
        entry.remove();
        entry.dispose();
      },
    ),
  );
  overlay.insert(entry);
}

class _SavedNotice extends StatefulWidget {
  const _SavedNotice({required this.label, required this.onExpired});
  final String label;
  final VoidCallback onExpired;
  @override
  State<_SavedNotice> createState() => _SavedNoticeState();
}

class _SavedNoticeState extends State<_SavedNotice> {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 2), widget.onExpired);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Positioned(
    right: 16,
    bottom: 20 + MediaQuery.paddingOf(context).bottom,
    child: IgnorePointer(
      child: Semantics(
        liveRegion: true,
        label: widget.label,
        child: Material(
          color: Colors.transparent,
          child: Text(
            widget.label,
            style: const TextStyle(
              fontFamily: 'CourtRoboto',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: CourtSceneTokens.cream,
              shadows: [Shadow(color: Colors.black, blurRadius: 5)],
            ),
          ),
        ),
      ),
    ),
  );
}
