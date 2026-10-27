import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/local_data_providers.dart';
import '../../data/offline_status.dart';
import '../../data/offline_policy.dart';
import '../../l10n/app_strings.dart';

class OfflineSettings extends ConsumerStatefulWidget {
  const OfflineSettings({super.key});
  @override
  ConsumerState<OfflineSettings> createState() => _OfflineSettingsState();
}

class _OfflineSettingsState extends ConsumerState<OfflineSettings> {
  String state = 'loading';
  bool busy = false;
  int? bytes;
  @override
  void initState() {
    super.initState();
    _run('status');
  }

  bool get hasGame =>
      !ref.read(localResumeProvider).hasValue ||
      !canReplaceOfflineVersion(
        ref.read(localSessionProvider).state?.phase,
        ref.read(sharedPhoneControllerProvider).view?.phase,
      );

  Future<void> _run(String action) async {
    if (busy) return;
    if ((action == 'apply' || action == 'clear') && hasGame) return;
    setState(() => busy = true);
    final result = await offlineAction(action);
    if (!mounted) return;
    setState(() {
      state = result['state'] as String? ?? 'failed';
      bytes = result['bytes'] as int?;
      busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localResumeProvider);
    if (state == 'unavailable') return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          context.tr('offlineTitle'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(context.tr('offlineHelp')),
        const SizedBox(height: 8),
        Text(context.tr('offline_$state')),
        if (bytes != null) Text('${(bytes! / 1048576).toStringAsFixed(1)} MiB'),
        if (busy) const LinearProgressIndicator(),
        if (hasGame) Text(context.tr('offlineGame')),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton(
              onPressed: busy ? null : () => _run('prepare'),
              child: Text(context.tr('offlinePrepare')),
            ),
            if (state == 'update' || state == 'reload')
              OutlinedButton(
                onPressed: busy || hasGame ? null : () => _run('apply'),
                child: Text(context.tr('offlineApply')),
              ),
            TextButton(
              onPressed: busy ? null : () => _run('status'),
              child: Text(context.tr('offlineCheck')),
            ),
            TextButton(
              onPressed: busy || hasGame ? null : () => _run('clear'),
              child: Text(context.tr('offlineClear')),
            ),
          ],
        ),
      ],
    );
  }
}
