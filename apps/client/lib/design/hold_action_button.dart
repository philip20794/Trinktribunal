import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import 'court_scene.dart';

/// One continuous hold charges the button, fires once, and ends on release.
class HoldActionButton extends StatefulWidget {
  const HoldActionButton({
    required this.icon,
    required this.label,
    required this.onCompleted,
    this.onReleased,
    this.duration = const Duration(milliseconds: 1200),
    this.focusNode,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onCompleted, onReleased;
  final Duration duration;
  final FocusNode? focusNode;

  @override
  State<HoldActionButton> createState() => _HoldActionButtonState();
}

class _HoldActionButtonState extends State<HoldActionButton>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _charge =
      AnimationController(
          vsync: this,
          duration: widget.duration,
          // The hold duration is an interaction gate, even with reduced motion.
          animationBehavior: AnimationBehavior.preserve,
        )
        ..addListener(() {
          if ((_charge.lastElapsedDuration ?? Duration.zero) >=
              widget.duration) {
            _complete();
          }
        })
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed) _complete();
        });

  void _complete() {
    if (_disposed || !_active || _fired) return;
    _fired = true;
    widget.onCompleted?.call();
  }

  final _localFocus = FocusNode();
  int? _pointer;
  LogicalKeyboardKey? _key;
  bool _fired = false, _disposed = false;
  bool get _active => _pointer != null || _key != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void _start() {
    _fired = false;
    _charge.forward(from: 0);
  }

  void _release() {
    if (_disposed || !_active) return;
    _pointer = null;
    _key = null;
    _charge.reset();
    widget.onReleased?.call();
  }

  @override
  void didUpdateWidget(HoldActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _charge.duration = widget.duration;
    if (_active && widget.onCompleted == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.onCompleted == null) _release();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _release();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposed = true;
    if (_active) {
      final release = widget.onReleased;
      WidgetsBinding.instance.addPostFrameCallback((_) => release?.call());
    }
    _pointer = null;
    _key = null;
    _charge.dispose();
    _localFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onCompleted != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      hint: context.tr('holdActionHint', {
        'seconds': (widget.duration.inMilliseconds / 1000)
            .toString()
            .replaceAll(
              '.',
              AppLanguageScope.of(context).language == 'de' ? ',' : '.',
            ),
      }),
      child: Focus(
        focusNode: widget.focusNode ?? _localFocus,
        canRequestFocus: enabled,
        onFocusChange: (focused) {
          if (!focused) _release();
        },
        onKeyEvent: (_, event) {
          final key = event.logicalKey;
          if (key != LogicalKeyboardKey.space &&
              key != LogicalKeyboardKey.enter) {
            return KeyEventResult.ignored;
          }
          if (event is KeyDownEvent && enabled && !_active) {
            _key = key;
            _start();
          } else if (event is KeyUpEvent && _key == key) {
            _release();
          }
          return KeyEventResult.handled;
        },
        child: MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (event) {
              if (!enabled || _active || event.buttons != 1) return;
              _pointer = event.pointer;
              (widget.focusNode ?? _localFocus).requestFocus();
              _start();
            },
            onPointerUp: (event) {
              if (event.pointer == _pointer) _release();
            },
            onPointerCancel: (event) {
              if (event.pointer == _pointer) _release();
            },
            child: AnimatedBuilder(
              animation: _charge,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 32),
                  child: ExcludeSemantics(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          widget.icon,
                          size: 21,
                          color: enabled
                              ? CourtSceneTokens.cream
                              : Colors.white38,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            widget.label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: enabled
                                  ? CourtSceneTokens.cream
                                  : Colors.white38,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              builder: (context, child) => Material(
                color: enabled
                    ? CourtSceneTokens.crimson
                    : CourtSceneTokens.panel,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                  side: BorderSide(
                    color: CourtSceneTokens.gold.withValues(
                      alpha: enabled ? .8 : .25,
                    ),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: _charge.value,
                        child: const ColoredBox(color: Color(0x885EAB8D)),
                      ),
                    ),
                    child!,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
