import 'package:flutter/material.dart';

/// Announce changed feedback without moving focus or exposing technical details.
class StatusNotice extends StatelessWidget {
  const StatusNotice(this.message, {super.key});
  final String message;
  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: true,
    child: Text(
      message,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    ),
  );
}
