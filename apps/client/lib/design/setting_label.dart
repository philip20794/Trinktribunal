import 'court_dialog.dart';

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';

class SettingLabel extends StatelessWidget {
  const SettingLabel({
    required this.title,
    required this.helpKey,
    this.controlScale,
    super.key,
  });
  final Widget title;
  final String helpKey;
  final double? controlScale;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: title),
      IconButton(
        constraints: controlScale == null
            ? null
            : BoxConstraints.tightFor(
                width: 32 * controlScale!,
                height: 48 * controlScale!,
              ),
        padding: controlScale == null ? null : EdgeInsets.zero,
        icon: Icon(Icons.info_outline, size: 20 * (controlScale ?? 1)),
        tooltip: context.tr(helpKey),
        onPressed: () => showDialog<void>(
          context: context,
          builder: (context) => CourtDialog(
            content: TText(helpKey),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const TText('roomToolsClose'),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
