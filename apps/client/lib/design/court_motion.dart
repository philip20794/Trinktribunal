import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'court_theme.dart';

enum CourtMotionStyle { file, stamp }

/// Coordinates card and footer input without moving surrounding elements.
class CourtMotionBoundary extends StatefulWidget {
  const CourtMotionBoundary({required this.child, super.key});
  final Widget child;
  static bool run(BuildContext context, VoidCallback action) {
    final gate = context
        .getInheritedWidgetOfExactType<_MotionScope>()
        ?.notifier;
    if (gate != null) return gate.run(action);
    action();
    return true;
  }

  @override
  State<CourtMotionBoundary> createState() => _CourtMotionBoundaryState();
}

class _CourtMotionBoundaryState extends State<CourtMotionBoundary> {
  final _gate = _MotionGate();
  @override
  void dispose() {
    _gate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _MotionScope(notifier: _gate, child: widget.child);
}

class _MotionScope extends InheritedNotifier<_MotionGate> {
  const _MotionScope({required super.notifier, required super.child});
}

class _MotionGate extends ChangeNotifier {
  final _animations = <Object>{};
  bool _requested = false, _disposed = false, _scheduled = false;
  bool get busy => _requested || _animations.isNotEmpty;
  bool run(VoidCallback action) {
    if (busy) return false;
    // Close the same-frame gap before a refresh rebuild starts the animation.
    _requested = true;
    notifyListeners();
    try {
      action();
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_disposed) return;
        _requested = false;
        notifyListeners();
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    }
    return true;
  }

  void begin(Object owner) {
    if (_disposed) return;
    _animations.add(owner);
    _notifyAfterBuild();
  }

  void end(Object owner) {
    if (_disposed || !_animations.remove(owner)) return;
    _notifyAfterBuild();
  }

  void _notifyAfterBuild() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed) return;
      _scheduled = false;
      notifyListeners();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class CourtMotionGuard extends StatelessWidget {
  const CourtMotionGuard({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final busy =
        context
            .dependOnInheritedWidgetOfExactType<_MotionScope>()
            ?.notifier
            ?.busy ??
        false;
    return IgnorePointer(
      ignoring: busy,
      child: ExcludeFocus(
        excluding: busy,
        child: ExcludeSemantics(excluding: busy, child: child),
      ),
    );
  }
}

/// Exchanges the whole illustrated stack, or stamps a verdict.
class CourtMotion extends StatelessWidget {
  const CourtMotion({
    required this.child,
    required this.style,
    this.replayKey,
    super.key,
  });
  final Widget child;
  final CourtMotionStyle style;
  final Object? replayKey;
  static const exchangeDuration = Duration(milliseconds: 480);
  @override
  Widget build(BuildContext context) {
    if (style == CourtMotionStyle.file) {
      return _FileStackExchange(replayKey: replayKey, child: child);
    }
    if (MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context)) {
      return child;
    }
    return TweenAnimationBuilder<double>(
      key: ValueKey(replayKey),
      duration: CourtTokens.motionDuration(false),
      tween: Tween(begin: 0, end: 1),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, content) => Transform.rotate(
        angle: (1 - value) * -0.035,
        child: Transform.scale(scale: 1 + (1 - value) * 0.08, child: content),
      ),
    );
  }
}

class _FileStackExchange extends StatefulWidget {
  const _FileStackExchange({required this.child, this.replayKey});
  final Widget child;
  final Object? replayKey;
  @override
  State<_FileStackExchange> createState() => _FileStackExchangeState();
}

class _FileStackExchangeState extends State<_FileStackExchange>
    with SingleTickerProviderStateMixin {
  late final _time = AnimationController(
    vsync: this,
    duration: CourtMotion.exchangeDuration,
    value: 1,
  )..addStatusListener(_status);
  late Widget _current;
  Object? _key;
  Widget? _outgoing;
  _FileStackExchange? _latest;
  _MotionGate? _gate;
  bool _reduced = false;
  @override
  void initState() {
    super.initState();
    _current = widget.child;
    _key = widget.replayKey;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _gate = context.getInheritedWidgetOfExactType<_MotionScope>()?.notifier;
    _reduced =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    if (_reduced && _outgoing != null) {
      _time.stop();
      _settle();
    }
  }

  @override
  void didUpdateWidget(_FileStackExchange oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_reduced) {
      _current = widget.child;
      _key = widget.replayKey;
      return;
    }
    if (widget.replayKey == _key) {
      _current = widget.child;
      _latest = null;
    } else if (_outgoing != null) {
      // External snapshots can advance while inputs are locked. Retain only the
      // latest state, never another outgoing layer or a second running tween.
      _latest = widget;
    } else {
      _outgoing = _current;
      _current = widget.child;
      _key = widget.replayKey;
      _gate?.begin(this);
      _time.forward(from: 0);
    }
  }

  void _settle() {
    if (_latest case final latest?) {
      _current = latest.child;
      _key = latest.replayKey;
    }
    _latest = null;
    _outgoing = null;
    _gate?.end(this);
  }

  void _status(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) setState(_settle);
  }

  @override
  void dispose() {
    _gate?.end(this);
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _time,
    builder: (context, _) {
      final busy = _outgoing != null;
      final progress = busy
          ? Curves.easeInOutCubic.transform(_time.value)
          : 1.0;
      Widget layer(
        Widget paper, {
        required bool outgoing,
      }) => FractionalTranslation(
        key: ValueKey(outgoing ? 'case-stack-outgoing' : 'case-stack-incoming'),
        translation: outgoing
            ? Offset(1.1 * progress, .065 * progress)
            : Offset(-.16 * (1 - progress), .018 * (1 - progress)),
        child: Transform.rotate(
          angle: outgoing ? (math.pi / 90) * progress : -.012 * (1 - progress),
          child: Opacity(
            opacity: outgoing ? 1 - .35 * progress : .85 + .15 * progress,
            child: RepaintBoundary(child: paper),
          ),
        ),
      );
      return AbsorbPointer(
        absorbing: busy,
        child: ExcludeFocus(
          excluding: busy,
          child: ExcludeSemantics(
            excluding: busy,
            child: ClipRect(
              child: Stack(
                key: const ValueKey('case-stack-layers'),
                alignment: Alignment.topCenter,
                children: [
                  layer(_current, outgoing: false),
                  if (_outgoing case final outgoing?)
                    layer(outgoing, outgoing: true),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
