import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../l10n/app_strings.dart';
import '../../design/court_scene.dart';
import '../../design/court_theme.dart';
import '../help/help_screen.dart';

const rulesAssetRoot = 'assets/ui/trinktribunal_spielregeln_assets';
const rulesStepIcons = ['hash', 'message-circle', 'arrow-down-up', 'wine'];
const rulesIconNames = [
  ...rulesStepIcons,
  'scale',
  'users',
  'book-open',
  'arrow-left',
  'circle-help',
  'check',
  'x',
];
const rulesCorrectOrder = [2, 7, 11];
const rulesJudgeOrder = [7, 2, 11];
const _accent = Color(0xFF981735);
const _sand = Color(0xFFE8CDA0);
const _wrong = Color(0xFFA62B2B);
const _right = Color(0xFF245F3C);

Future<void> showGameRules(BuildContext context) =>
    Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => const GameRulesScreen()));

class GameRulesButton extends StatelessWidget {
  const GameRulesButton({this.beforeOpen, super.key});
  final VoidCallback? beforeOpen;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: context.tr('gameRules'),
    icon: const Icon(Icons.help_outline),
    onPressed: () {
      beforeOpen?.call();
      showGameRules(context);
    },
  );
}

/// All glyphs are the supplied local SVGs; adjacent text carries their meaning.
class RulesIcon extends StatelessWidget {
  const RulesIcon(this.name, {this.color = _accent, this.size = 20, super.key});
  final String name;
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    '$rulesAssetRoot/icons/svg/$name.svg',
    width: size,
    height: size,
    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    excludeFromSemantics: true,
  );
}

class GameRulesScreen extends StatelessWidget {
  const GameRulesScreen({super.key});
  @override
  Widget build(BuildContext context) => CourtScaffold(
    background: null,
    maxWidth: 680,
    title: const TText('gameRules'),
    leading: IconButton(
      key: const ValueKey('rules-back'),
      tooltip: context.tr('back'),
      icon: const RulesIcon('arrow-left', color: CourtSceneTokens.cream),
      onPressed: () => Navigator.of(context).maybePop(),
    ),
    actions: [
      IconButton(
        key: const ValueKey('rules-help'),
        tooltip: context.tr('rulesHelp'),
        icon: const RulesIcon('circle-help', color: CourtSceneTokens.cream),
        onPressed: () => Navigator.push<void>(
          context,
          MaterialPageRoute(builder: (_) => const HelpScreen()),
        ),
      ),
    ],
    body: ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
      children: [
        _RulesPanel(
          child: Builder(
            builder: (context) => Column(
              children: [
                Semantics(
                  header: true,
                  child: TText(
                    'rulesIntroTitle',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 6),
                const TText('rulesIntroSubtitle', textAlign: TextAlign.center),
                const SizedBox(height: 20),
                for (var index = 0; index < rulesStepIcons.length; index++)
                  _Step(index + 1),
              ],
            ),
          ),
        ),
        const _RulesPanel(child: _ScoringExample()),
        const _RulesPanel(
          child: _ExtraRule(
            icon: 'users',
            title: 'gameRulesAllJudgesTitle',
            body: 'gameRulesAllJudgesBody',
          ),
        ),
        const _RulesPanel(
          child: _ExtraRule(
            icon: 'book-open',
            title: 'gameRulesExtraRulesTitle',
            body: 'gameRulesExtraRulesBody',
          ),
        ),
      ],
    ),
  );
}

class _RulesPanel extends StatelessWidget {
  const _RulesPanel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: CourtPaper(
      padding: const EdgeInsets.all(16),
      child: DefaultTextStyle.merge(
        style: const TextStyle(
          fontSize: 14,
          height: 1.45,
          color: CourtTokens.ink,
        ),
        child: child,
      ),
    ),
  );
}

class _Step extends StatelessWidget {
  const _Step(this.number);
  final int number;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: number == 4 ? 0 : 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Container(
            width: MediaQuery.textScalerOf(context).scale(16) + 14,
            height: MediaQuery.textScalerOf(context).scale(16) + 14,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: _accent,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                color: CourtSceneTokens.cream,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Heading(
                icon: rulesStepIcons[number - 1],
                text: 'rulesStep${number}Title',
              ),
              const SizedBox(height: 6),
              TText('rulesStep${number}Body'),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Heading extends StatelessWidget {
  const _Heading({required this.icon, required this.text});
  final String icon, text;
  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: RulesIcon(icon, size: 18),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TText(
            text,
            style: const TextStyle(
              fontSize: 16,
              height: 1.3,
              fontWeight: FontWeight.w600,
              color: CourtTokens.ink,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ScoringExample extends StatelessWidget {
  const _ScoringExample();
  @override
  Widget build(BuildContext context) {
    final errors = List.generate(
      rulesCorrectOrder.length,
      (i) => rulesCorrectOrder[i] != rulesJudgeOrder[i],
    ).where((wrong) => wrong).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Heading(icon: 'scale', text: 'rulesScoringTitle'),
        const SizedBox(height: 14),
        const TText('rulesScoringIntro'),
        const SizedBox(height: 12),
        const _OrderRow(judged: false),
        const SizedBox(height: 16),
        const _OrderRow(judged: true),
        const SizedBox(height: 12),
        DecoratedBox(
          decoration: BoxDecoration(
            color: _sand,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.tr('rulesScoringResult', {'count': errors}),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const _PenaltyRow('rulesJudgeRole', 'rulesTwoSips'),
                const Divider(color: CourtTokens.border),
                const _PenaltyRow('rulesWrongPeople', 'rulesTwoSipsEach'),
                const Divider(color: CourtTokens.border),
                const _PenaltyRow('rulesCorrectPerson', 'rulesNoSips'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.judged});
  final bool judged;
  @override
  Widget build(BuildContext context) {
    final values = judged ? rulesJudgeOrder : rulesCorrectOrder;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context
              .tr(judged ? 'rulesJudgeOrderTitle' : 'rulesCorrectOrderTitle')
              .toUpperCase(),
          style: const TextStyle(fontSize: 11, height: 1.4, letterSpacing: .4),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < values.length; index++) ...[
              if (index > 0) const SizedBox(width: 8),
              Expanded(
                child: _NumberCell(
                  number: values[index],
                  position: index + 1,
                  judged: judged,
                  correct: values[index] == rulesCorrectOrder[index],
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _NumberCell extends StatelessWidget {
  const _NumberCell({
    required this.number,
    required this.position,
    required this.judged,
    required this.correct,
  });
  final int number, position;
  final bool judged, correct;
  @override
  Widget build(BuildContext context) {
    final label = context.tr(
      correct ? 'rulesCorrectLabel' : 'rulesIncorrectLabel',
    );
    final color = correct ? _right : _wrong;
    return Semantics(
      label: context.tr('rulesExampleCell', {
        'position': position,
        'number': number,
        'status': label,
      }),
      excludeSemantics: true,
      child: DecoratedBox(
        key: ValueKey('${judged ? 'judge' : 'correct'}-$position'),
        decoration: BoxDecoration(
          color: !judged
              ? _sand
              : correct
              ? const Color(0xFFDCEAD5)
              : const Color(0xFFF0D0C8),
          borderRadius: BorderRadius.circular(8),
          border: judged
              ? Border.all(
                  color: correct
                      ? const Color(0xFF6B9D6B)
                      : const Color(0xFFD65B56),
                )
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Column(
            children: [
              Text(
                '$number',
                style: const TextStyle(
                  fontSize: 20,
                  height: 1.2,
                  color: CourtTokens.ink,
                ),
              ),
              const SizedBox(height: 6),
              if (!judged)
                RulesIcon('check', size: 14, color: color)
              else
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 3,
                  children: [
                    RulesIcon(correct ? 'check' : 'x', size: 14, color: color),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: color, fontSize: 11),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PenaltyRow extends StatelessWidget {
  const _PenaltyRow(this.role, this.amount);
  final String role, amount;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: TText(role)),
      const SizedBox(width: 16),
      Expanded(child: TText(amount, textAlign: TextAlign.right)),
    ],
  );
}

class _ExtraRule extends StatelessWidget {
  const _ExtraRule({
    required this.icon,
    required this.title,
    required this.body,
  });
  final String icon, title, body;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _Heading(icon: icon, text: title),
      const SizedBox(height: 10),
      TText(body),
    ],
  );
}
