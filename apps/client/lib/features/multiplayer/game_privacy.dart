import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/online_game_controller.dart';
import '../../application/room_providers.dart';

class RoomGamePrivacy extends ConsumerStatefulWidget {
  const RoomGamePrivacy({required this.child, super.key});
  final Widget child;
  @override
  ConsumerState<RoomGamePrivacy> createState() => _RoomGamePrivacyState();
}

class _RoomGamePrivacyState extends ConsumerState<RoomGamePrivacy>
    with WidgetsBindingObserver {
  late final OnlineGameController _game;
  Animation<double>? _tabs;
  @override
  void initState() {
    super.initState();
    _game = ref.read(onlineGameProvider);
    _game.hideSecret();
    WidgetsBinding.instance.addObserver(this);
  }

  void _hide() => _game.hideSecret();
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tabs?.removeListener(_hide);
    _tabs = DefaultTabController.maybeOf(context)?.animation;
    _tabs?.addListener(_hide);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _hide();
  }

  @override
  void dispose() {
    _tabs?.removeListener(_hide);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      PopScope(onPopInvokedWithResult: (_, _) => _hide(), child: widget.child);
}
