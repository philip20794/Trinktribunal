import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';

class PendingOrderAvatar extends StatefulWidget {
  const PendingOrderAvatar({
    required this.pending,
    required this.child,
    super.key,
  });
  final bool pending;
  final Widget child;
  @override
  State<PendingOrderAvatar> createState() => _PendingOrderAvatarState();
}

class _PendingOrderAvatarState extends State<PendingOrderAvatar>
    with SingleTickerProviderStateMixin {
  late final _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  void _sync() {
    final animate =
        widget.pending &&
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context);
    if (animate && !_spin.isAnimating) _spin.repeat();
    if (!animate) _spin.stop();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(PendingOrderAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      widget.child,
      if (widget.pending)
        Positioned(
          top: 0,
          right: 0,
          child: Semantics(
            label: context.tr('orderStillPending'),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: Color(0xFF503C2D),
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: RotationTransition(
                  turns: _spin,
                  child: const Icon(
                    Icons.sync,
                    size: 20,
                    color: Color(0xFFE7C98B),
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}
