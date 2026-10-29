import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import 'court_scene.dart';
import 'court_assets.dart';

/// Shared local/online presentation; hidden values never enter text or semantics.
class PrivateNumber extends StatefulWidget {
  const PrivateNumber({
    required this.number,
    required this.onReveal,
    required this.onHide,
    this.onConfirm,
    this.confirmKey = 'phoneHideNext',
    this.compact = false,
    super.key,
  });
  final int? number;
  final VoidCallback onReveal, onHide;
  final VoidCallback? onConfirm;
  final String confirmKey;
  final bool compact;
  @override
  State<PrivateNumber> createState() => _PrivateNumberState();
}

/// A shared-device value is visible only during an active pointer/key hold.
/// Online PrivateNumber intentionally keeps its separate tap interaction.
class HeldPrivateNumber extends StatefulWidget {
  const HeldPrivateNumber({
    required this.number,
    required this.onReveal,
    required this.onHide,
    required this.onDone,
    this.fullScreen = false,
    super.key,
  });
  final int? number;
  final bool fullScreen;
  final VoidCallback onReveal, onHide, onDone;
  @override
  State<HeldPrivateNumber> createState() => _HeldPrivateNumberState();
}

class _HeldPrivateNumberState extends State<HeldPrivateNumber>
    with WidgetsBindingObserver {
  final _focus = FocusNode(debugLabel: 'hold-private-number');
  final _holdSurface = GlobalKey();
  bool _seen = false;
  int? _pointer;
  LogicalKeyboardKey? _key;
  bool get _held => _pointer != null || _key != null;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(HeldPrivateNumber oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_held && widget.number != null) _seen = true;
  }

  void _stop() {
    if (!_held) return;
    _pointer = null;
    _key = null;
    if (mounted) setState(() {});
    widget.onHide();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _stop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controls = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          label: context.tr('phoneHoldNumber'),
          hint: context.tr('phoneHoldHelp'),
          child: Focus(
            focusNode: _focus,
            onFocusChange: (focused) {
              if (!focused) _stop();
              if (mounted) setState(() {});
            },
            onKeyEvent: (_, event) {
              final key = event.logicalKey;
              if (key != LogicalKeyboardKey.space &&
                  key != LogicalKeyboardKey.enter) {
                return KeyEventResult.ignored;
              }
              if (event is KeyDownEvent && !_held) {
                setState(() {
                  _key = key;
                  _seen = _seen || widget.number != null;
                });
                widget.onReveal();
              }
              if (event is KeyUpEvent && _key == key) _stop();
              return KeyEventResult.handled;
            },
            child: LayoutBuilder(
              builder: (context, constraints) => Listener(
                onPointerDown: (event) {
                  if (_held || event.buttons != 1) return;
                  setState(() {
                    _pointer = event.pointer;
                    _seen = _seen || widget.number != null;
                  });
                  _focus.requestFocus();
                  widget.onReveal();
                },
                onPointerUp: (event) {
                  if (_pointer == event.pointer) _stop();
                },
                onPointerCancel: (event) {
                  if (_pointer == event.pointer) _stop();
                },
                onPointerMove: (event) {
                  if (_pointer == event.pointer &&
                      (event.localPosition.dx < 0 ||
                          event.localPosition.dy < 0 ||
                          event.localPosition.dx > constraints.maxWidth ||
                          event.localPosition.dy >
                              (_holdSurface.currentContext!.findRenderObject()
                                      as RenderBox)
                                  .size
                                  .height)) {
                    _stop();
                  }
                },
                child: Container(
                  key: _holdSurface,
                  constraints: const BoxConstraints(minHeight: 56),
                  padding: const EdgeInsets.all(12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: widget.fullScreen
                        ? Colors.transparent
                        : Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(
                      widget.fullScreen ? 28 : 12,
                    ),
                    border: Border.all(
                      color: widget.fullScreen
                          ? CourtSceneTokens.gold
                          : _focus.hasFocus
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: ExcludeSemantics(
                    child: widget.fullScreen
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.visibility_outlined,
                                color: CourtSceneTokens.cream,
                              ),
                              SizedBox(width: 10),
                              Flexible(child: TText('phoneHoldNumber')),
                            ],
                          )
                        : const TText('phoneHoldNumber'),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _seen
              ? () {
                  _stop();
                  widget.onDone();
                }
              : null,
          child: const TText('phoneDoneNext'),
        ),
      ],
    );
    final visible = _held ? widget.number : null;
    if (widget.fullScreen) {
      return CourtScaffold(
        title: const TText('yourNumber'),
        leading: const SizedBox.shrink(),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: _SecretPaper(number: visible),
        ),
        footer: CourtActionBar(primary: controls),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _NumberFace(number: visible),
        const SizedBox(height: 12),
        controls,
      ],
    );
  }
}

class _SecretPaper extends StatelessWidget {
  const _SecretPaper({required this.number});
  final int? number;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Stack(
      fit: StackFit.expand,
      children: [
        const CourtArt(CourtAssets.secretPaper, fit: BoxFit.contain),
        Center(
          child: number == null
              ? const ExcludeSemantics(
                  child: Icon(
                    Icons.lock_outline,
                    size: 64,
                    color: CourtSceneTokens.crimson,
                  ),
                )
              : SizedBox(
                  width: constraints.maxWidth * .55,
                  height: constraints.maxHeight * .5,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '$number',
                      style: const TextStyle(
                        fontFamily: 'CourtRoboto',
                        fontSize: 150,
                        fontWeight: FontWeight.w700,
                        color: CourtSceneTokens.crimson,
                      ),
                      semanticsLabel: context.tr('secretNumber', {
                        'number': number,
                      }),
                    ),
                  ),
                ),
        ),
      ],
    ),
  );
}

class _PrivateNumberState extends State<PrivateNumber> {
  final _reveal = FocusNode(debugLabel: 'reveal-private-number');
  final _hide = FocusNode(debugLabel: 'hide-private-number');
  final _confirm = FocusNode(debugLabel: 'confirm-private-number');
  @override
  void didUpdateWidget(PrivateNumber oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.number == null) == (widget.number == null)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final next = widget.number == null
          ? _reveal
          : widget.onConfirm == null
          ? _hide
          : _confirm;
      if (next.canRequestFocus) next.requestFocus();
    });
  }

  @override
  void dispose() {
    _reveal.dispose();
    _hide.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.compact
      ? Wrap(
          spacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(context.tr('yourNumber')),
            OutlinedButton.icon(
              key: const ValueKey('compact-private-number'),
              focusNode: widget.number == null ? _reveal : _hide,
              onPressed: widget.number == null
                  ? widget.onReveal
                  : widget.onHide,
              icon: Icon(
                widget.number == null
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 18,
              ),
              label: Text(
                widget.number == null ? '••' : '${widget.number}',
                semanticsLabel: widget.number == null
                    ? context.tr('phoneReveal')
                    : context.tr('secretNumber', {'number': widget.number}),
              ),
            ),
            if (widget.number != null && widget.onConfirm != null)
              TextButton(
                focusNode: _confirm,
                onPressed: widget.onConfirm,
                child: TText(widget.confirmKey),
              ),
          ],
        )
      : Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _NumberFace(number: widget.number),
            const SizedBox(height: 12),
            if (widget.number == null)
              FilledButton(
                focusNode: _reveal,
                onPressed: widget.onReveal,
                child: const TText('phoneReveal'),
              )
            else ...[
              if (widget.onConfirm != null)
                FilledButton(
                  focusNode: _confirm,
                  onPressed: widget.onConfirm,
                  child: TText(widget.confirmKey),
                ),
              TextButton(
                focusNode: _hide,
                onPressed: widget.onHide,
                child: const TText('phoneHide'),
              ),
            ],
          ],
        );
}

class _NumberFace extends StatelessWidget {
  const _NumberFace({required this.number});
  final int? number;
  @override
  Widget build(BuildContext context) => CourtPaper(
    padding: const EdgeInsets.all(16),
    child: Builder(
      builder: (context) => SizedBox(
        height: 140,
        width: double.infinity,
        child: Center(
          child: number == null
              ? const ExcludeSemantics(
                  child: Icon(Icons.lock_outline, size: 48),
                )
              : Text(
                  '$number',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayLarge,
                  semanticsLabel: context.tr('secretNumber', {
                    'number': number,
                  }),
                ),
        ),
      ),
    ),
  );
}
