import 'court_dialog.dart';

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';

class SettingLabel extends StatelessWidget {
  const SettingLabel({required this.title, required this.helpKey, super.key});
  final Widget title;
  final String helpKey;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: title),
      IconButton(
        icon: const Icon(Icons.info_outline, size: 20),
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
