import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/install_controller.dart';
import '../design/status_notice.dart';
import '../l10n/app_strings.dart';

/// Shared installation actions for settings and the invitation dialog.
class InstallOptions extends ConsumerStatefulWidget {
  const InstallOptions({this.roomCode, super.key});
  final String? roomCode;
  @override
  ConsumerState<InstallOptions> createState() => _InstallOptionsState();
}

class _InstallOptionsState extends ConsumerState<InstallOptions> {
  String? _notice;
  bool _busy = false;
  Future<void> _action(String action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final controller = ref.read(installControllerProvider);
      final result = await controller.act(action);
      if (!mounted) return;
      setState(
        () => _notice = switch (result) {
          'failed' => 'installFailed',
          'expired' => 'installInviteExpired',
          'accepted' => 'installLaunchPwa',
          'unavailable' => 'installBrowserHelp',
          _ => action == 'download' ? 'installApkHelp' : null,
        },
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(installControllerProvider);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!controller.web) ...[
            const TText('installAlreadyInstalled'),
            if (controller.android)
              const OutlinedButton(
                key: ValueKey('install-apk'),
                onPressed: null,
                child: TText('installApkInstalled'),
              ),
          ] else ...[
            OutlinedButton.icon(
              key: const ValueKey('install-pwa'),
              onPressed: _busy || controller.pwaInstalled
                  ? null
                  : () {
                      if (controller.ios) {
                        setState(() => _notice = 'installIosHelp');
                      } else if (controller.canPrompt) {
                        _action('prompt');
                      } else {
                        setState(() => _notice = 'installBrowserHelp');
                      }
                    },
              icon: const Icon(Icons.add_to_home_screen),
              label: TText(
                controller.pwaInstalled ? 'installPwaInstalled' : 'installPwa',
              ),
            ),
            if (controller.android)
              OutlinedButton.icon(
                key: const ValueKey('install-apk'),
                onPressed: _busy || controller.apkInstalled
                    ? null
                    : () => _action('download'),
                icon: const Icon(Icons.android),
                label: TText(
                  controller.apkInstalled
                      ? 'installApkInstalled'
                      : 'installApk',
                ),
              ),
            if (controller.android &&
                widget.roomCode != null &&
                (controller.downloaded || controller.apkInstalled))
              OutlinedButton.icon(
                key: const ValueKey('install-open-game'),
                onPressed: _busy ? null : () => _action('open'),
                icon: const Icon(Icons.open_in_new),
                label: const TText('installOpenGame'),
              ),
          ],
          if (_notice != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: StatusNotice(context.tr(_notice!)),
            ),
          if (controller.ios && widget.roomCode != null) ...[
            Text(
              context.tr('installIosInviteHelp', {'code': widget.roomCode!}),
            ),
            TextButton.icon(
              onPressed: () =>
                  Clipboard.setData(ClipboardData(text: widget.roomCode!)),
              icon: const Icon(Icons.copy),
              label: Text(
                context.tr('installCopyCode', {'code': widget.roomCode!}),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
