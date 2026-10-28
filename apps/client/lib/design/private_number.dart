import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';

/// Shared local/online presentation; hidden values never enter text or semantics.
class PrivateNumber extends StatefulWidget {
  const PrivateNumber({
    required this.number,
    required this.onReveal,
    required this.onHide,
    this.onConfirm,
    this.confirmKey = 'phoneHideNext',
    super.key,
  });
  final int? number;
  final VoidCallback onReveal, onHide;
  final VoidCallback? onConfirm;
  final String confirmKey;
  @override
  State<PrivateNumber> createState() => _PrivateNumberState();
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
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (widget.number == null)
        FilledButton(
          focusNode: _reveal,
          onPressed: widget.onReveal,
          child: const TText('phoneReveal'),
        )
      else ...[
        Text(
          '${widget.number}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.displayLarge,
          semanticsLabel: context.tr('secretNumber', {'number': widget.number}),
        ),
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
