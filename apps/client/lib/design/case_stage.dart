import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import 'illustrated_paper.dart';
import 'court_scene.dart';
import 'court_assets.dart';
import 'private_number.dart';
import '../domain/avatar_config.dart';

/// A fixed viewport for the judge, paper and floating active-rules control.
class CaseStage extends StatelessWidget {
  const CaseStage({
    required this.child,
    required this.onRules,
    required this.rules,
    this.judge,
    this.notice,
    this.number,
    super.key,
  });
  final Widget child;
  final Widget? judge, notice;
  final VoidCallback onRules;
  final int rules;
  final int? number;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(
        child: Column(
          children: [
            ?notice,
            if (judge != null)
              SizedBox(
                height: 72,
                child: Padding(
                  padding: EdgeInsets.only(left: 2, right: 42),
                  child: judge,
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: LayoutBuilder(
                  builder: (context, bounds) => FlipCase(
                    number: number,
                    front: CasePaperScope(
                      maxHeight: bounds.maxHeight,
                      child: SizedBox(
                        width: bounds.maxWidth,
                        height: bounds.maxHeight,
                        child: child,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      Positioned(
        top: 0,
        right: 2,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: context.tr('activeRules'),
              onPressed: onRules,
              icon: Badge(
                isLabelVisible: rules > 0,
                label: Text('$rules'),
                child: const Icon(Icons.menu_book_outlined),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

/// Secret text is removed immediately on release, including during the flip back.
class FlipCase extends StatefulWidget {
  const FlipCase({
    required this.front,
    required this.number,
    this.ownerName,
    this.ownerAvatar,
    super.key,
  });
  final Widget front;
  final int? number;
  final String? ownerName;
  final AvatarConfig? ownerAvatar;
  @override
  State<FlipCase> createState() => _FlipCaseState();
}

class _FlipCaseState extends State<FlipCase>
    with SingleTickerProviderStateMixin {
  late final _turn = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    value: widget.number == null ? 0 : 1,
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _turn.duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 280);
    if (MediaQuery.disableAnimationsOf(context)) {
      _turn.value = widget.number == null ? 0 : 1;
    }
  }

  @override
  void didUpdateWidget(FlipCase oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.number == widget.number) return;
    if (widget.number == null) {
      _turn.reverse();
    } else {
      _turn.forward();
    }
  }

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _turn,
    builder: (context, _) {
      final back = _turn.value >= .5;
      final visual = Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, .001)
          ..rotateY(math.pi * Curves.easeInOut.transform(_turn.value)),
        child: back
            ? Transform(
                alignment: Alignment.center,
                transform: Matrix4.rotationY(math.pi),
                child: widget.number == null
                    ? const CourtArt(
                        CourtAssets.secretPaper,
                        fit: BoxFit.contain,
                      )
                    : SecretNumberFace(
                        number: widget.number,
                        ownerName: widget.ownerName,
                        ownerAvatar: widget.ownerAvatar,
                      ),
              )
            : widget.front,
      );
      return back
          ? Semantics(
              container: true,
              liveRegion: true,
              label: widget.number == null
                  ? context.tr('yourNumber')
                  : context.tr('secretNumber', {'number': widget.number}),
              child: ExcludeSemantics(child: visual),
            )
          : visual;
    },
  );
}
