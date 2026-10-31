import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/install_controller.dart';
import '../design/court_dialog.dart';
import '../features/home/home_screen.dart';
import '../features/multiplayer/direct_join.dart';
import '../l10n/app_strings.dart';
import 'install_options.dart';

/// Browser invitations start on Home; installed app links join immediately.
class AppEntryScreen extends ConsumerStatefulWidget {
  const AppEntryScreen({this.code, super.key});
  final String? code;
  @override
  ConsumerState<AppEntryScreen> createState() => _AppEntryScreenState();
}

class _AppEntryScreenState extends ConsumerState<AppEntryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_start());
    });
  }

  Future<void> _start() async {
    final install = ref.read(installControllerProvider);
    await install.ready;
    if (!mounted) return;
    // Flutter can construct Home below an initial /join route. Only the visible
    // entry may restore an invitation or present installation UI.
    if (ModalRoute.of(context)?.isCurrent != true) return;
    final code =
        widget.code ?? (install.installedContext ? install.pendingCode : null);
    if (widget.code != null) await install.act('remember', widget.code!);
    if (!mounted) return;
    if (install.installedContext && code != null) {
      _join(code);
      return;
    }
    if (code == null && !install.showPromotion) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;
    final join = await showDialog<bool>(
      context: context,
      builder: (context) => CourtDialog(
        scrollable: true,
        title: TText(code == null ? 'installTitle' : 'installInviteTitle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TText(code == null ? 'installBody' : 'installInviteBody'),
            const SizedBox(height: 12),
            InstallOptions(roomCode: code),
          ],
        ),
        actions: [
          FilledButton(
            key: const ValueKey('install-continue-browser'),
            onPressed: () => Navigator.pop(context, true),
            child: const TText('installContinueBrowser'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    await install.act('dismiss');
    if (mounted && join == true && code != null) _join(code);
  }

  void _join(String code) => Navigator.of(context).pushReplacement(
    MaterialPageRoute<void>(builder: (_) => DirectJoinRoomScreen(code: code)),
  );
  @override
  Widget build(BuildContext context) => const HomeScreen();
}
