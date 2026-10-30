import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../domain/avatar_config.dart';
import 'avatar_view.dart';

/// A brief demonstration overlay; it never modifies the real seat order.
class CourtDragHint extends StatefulWidget {
  const CourtDragHint({
    required this.onFinished,
    required this.avatar,
    required this.name,
    super.key,
  });
  final VoidCallback onFinished;
  final AvatarConfig avatar;
  final String name;
  @override
  State<CourtDragHint> createState() => _CourtDragHintState();
}

class _CourtDragHintState extends State<CourtDragHint>
    with SingleTickerProviderStateMixin {
  late final _animation =
      AnimationController(vsync: this, duration: const Duration(seconds: 6))
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed) widget.onFinished();
        });
  Timer? _dismiss;
  bool _started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _dismiss = Timer(const Duration(seconds: 6), widget.onFinished);
    } else {
      _animation.forward();
    }
  }

  @override
  void dispose() {
    _dismiss?.cancel();
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Material(
      color: const Color(0xED3D2C23),
      borderRadius: BorderRadius.circular(16),
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const TText('placePlayersHelp', textAlign: TextAlign.center),
            SizedBox(
              width: double.infinity,
              height: 120,
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, _) {
                  final t = MediaQuery.disableAnimationsOf(context)
                      ? 1.0
                      : Curves.easeInOut.transform(
                          ((_animation.value * 2) % 1).clamp(0, 1),
                        );
                  return LayoutBuilder(
                    builder: (context, bounds) => Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          top: 0,
                          left: bounds.maxWidth / 2 + 24,
                          child: const SizedBox(
                            width: 62,
                            height: 58,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Color(0x555D4939),
                                borderRadius: BorderRadius.all(
                                  Radius.circular(8),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '1',
                                  style: TextStyle(fontSize: 24),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Transform.translate(
                          offset: Offset(-55 + t * 110, 20 - t * 50),
                          child: Transform.rotate(
                            angle: math.sin(t * math.pi) * .1,
                            child: AvatarView(
                              showBackdrop: false,
                              config: widget.avatar,
                              label: widget.name,
                              size: 46,
                            ),
                          ),
                        ),
                        Transform.translate(
                          offset: Offset(-40 + t * 110, 38 - t * 50),
                          child: const Icon(
                            Icons.touch_app,
                            size: 30,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
