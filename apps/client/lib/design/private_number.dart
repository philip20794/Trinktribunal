import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import 'court_scene.dart';
import 'court_assets.dart';
import 'hold_action_button.dart';

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
/// The same charged hold control is used for online and shared-device reveals.
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

class _HeldPrivateNumberState extends State<HeldPrivateNumber> {
  final _focus = FocusNode(debugLabel: 'hold-private-number');
  bool _seen = false, _revealed = false;
  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controls = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        HoldActionButton(
          duration: const Duration(milliseconds: 800),
          key: const ValueKey('hold-private-number'),
          focusNode: _focus,
          icon: Icons.visibility_outlined,
          label: context.tr('showNumber'),
          onCompleted: () {
            setState(() {
              _seen = true;
              _revealed = true;
            });
            widget.onReveal();
          },
          onReleased: () {
            if (!mounted) return;
            setState(() => _revealed = false);
            widget.onHide();
          },
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _seen && !_revealed ? widget.onDone : null,
          child: const TText('phoneDoneNext'),
        ),
      ],
    );
    if (widget.fullScreen) {
      return CourtScaffold(
        title: const TText('yourNumber'),
        leading: const SizedBox.shrink(),
        body: Padding(
          padding: const EdgeInsets.all(4),
          child: SecretNumberFace(number: _revealed ? widget.number : null),
        ),
        footer: CourtActionBar(primary: controls),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _NumberFace(number: _revealed ? widget.number : null),
        const SizedBox(height: 12),
        controls,
      ],
    );
  }
}

class SecretNumberFace extends StatelessWidget {
  const SecretNumberFace({required this.number, super.key});
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
