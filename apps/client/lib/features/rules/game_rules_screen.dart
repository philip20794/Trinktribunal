import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../l10n/app_strings.dart';
import '../../design/court_scene.dart';
import '../../design/court_theme.dart';
import '../../design/court_assets.dart';
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
    background: CourtAssets.home,
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
    body: SingleChildScrollView(
      key: const ValueKey('rules-scroll'),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RulesPanel(
            child: Column(
              children: [
                const SemanticsHeader(text: 'rulesIntroTitle'),
                const SizedBox(height: 2),
                const TText(
                  'rulesIntroSubtitle',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 3),
                for (var n = 1; n <= 4; n++) _Step(n),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const _RulesPanel(child: _ScoringExample()),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, bounds) {
              const all = _ExtraRule(
                icon: 'users',
                title: 'gameRulesAllJudgesTitle',
                summary: 'rulesAllJudgesSummary',
                body: 'gameRulesAllJudgesBody',
              );
              const extra = _ExtraRule(
                icon: 'book-open',
                title: 'gameRulesExtraRulesTitle',
                summary: 'rulesExtraSummary',
                body: 'gameRulesExtraRulesBody',
              );
              if (bounds.maxWidth < 280) {
                return const Column(
                  children: [all, SizedBox(height: 6), extra],
                );
              }
              return const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: all),
                  SizedBox(width: 8),
                  Expanded(child: extra),
                ],
              );
            },
          ),
        ],
      ),
    ),
  );
}

class SemanticsHeader extends StatelessWidget {
  const SemanticsHeader({required this.text, super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: TText(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 18,
        height: 1.1,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _RulesPanel extends StatelessWidget {
  const _RulesPanel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => CourtPaper(
    padding: const EdgeInsets.all(8),
    child: DefaultTextStyle.merge(
      style: const TextStyle(
        fontSize: 13,
        height: 1.15,
        color: CourtTokens.ink,
      ),
      child: child,
    ),
  );
}

class _Step extends StatelessWidget {
  const _Step(this.number);
  final int number;
  @override
  Widget build(BuildContext context) => Container(
    key: ValueKey('rules-step-$number'),
    padding: const EdgeInsets.symmetric(vertical: 5),
    decoration: BoxDecoration(
      border: number == 1
          ? null
          : const Border(top: BorderSide(color: Color(0xFFDABB83), width: .6)),
    ),
    child: Row(
      children: [
        ExcludeSemantics(
          child: Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: _accent,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                color: CourtSceneTokens.cream,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 5),
        CourtArt(
          [
            CourtAssets.ruleNumber,
            CourtAssets.ruleQuestion,
            CourtAssets.ruleSort,
            CourtAssets.ruleDrink,
          ][number - 1],
          width: 40,
          height: 44,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TText(
                'rulesStep${number}Title',
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              TText('rulesStep${number}Body'),
            ],
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
        Row(
          children: [
            const CourtArt(
              CourtAssets.ruleExample,
              width: 32,
              height: 28,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 6),
            const Expanded(child: SemanticsHeader(text: 'rulesScoringTitle')),
          ],
        ),
        const SizedBox(height: 4),
        LayoutBuilder(
          builder: (context, bounds) {
            final scale = MediaQuery.textScalerOf(context).scale(13) / 13;
            if (bounds.maxWidth < 270 || scale > 1.5 && bounds.maxWidth < 480) {
              return const Column(
                children: [
                  _OrderRow(judged: false),
                  SizedBox(height: 6),
                  _OrderRow(judged: true),
                ],
              );
            }
            return const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _OrderRow(judged: false)),
                SizedBox(width: 10),
                Expanded(child: _OrderRow(judged: true)),
              ],
            );
          },
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: _sand,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.tr('rulesScoringResult', {'count': errors}),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              const _PenaltyRow('rulesJudgeRole', 'rulesTwoSips'),
              const _PenaltyRow('rulesWrongPeople', 'rulesTwoSipsEach'),
              const _PenaltyRow('rulesCorrectPerson', 'rulesNoSips'),
            ],
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
        TText(
          judged ? 'rulesJudgeOrderTitle' : 'rulesCorrectOrderTitle',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            for (var i = 0; i < values.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: _NumberCell(
                  number: values[i],
                  position: i + 1,
                  judged: judged,
                  correct: !judged || values[i] == rulesCorrectOrder[i],
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
  Widget build(BuildContext context) => Semantics(
    label: context.tr('rulesExampleCell', {
      'position': position,
      'number': number,
      'status': context.tr(
        correct ? 'rulesCorrectLabel' : 'rulesIncorrectLabel',
      ),
    }),
    excludeSemantics: true,
    child: Container(
      key: ValueKey('${judged ? 'judge' : 'correct'}-$position'),
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
      decoration: BoxDecoration(
        color: !judged
            ? _sand
            : correct
            ? const Color(0xFFDCEAD5)
            : const Color(0xFFF0D0C8),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              '$number',
              style: const TextStyle(
                fontSize: 16,
                height: 1.1,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 3),
          RulesIcon(
            correct ? 'check' : 'x',
            size: 12,
            color: correct ? _right : _wrong,
          ),
        ],
      ),
    ),
  );
}

class _PenaltyRow extends StatelessWidget {
  const _PenaltyRow(this.role, this.amount);
  final String role, amount;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 1),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: TText(role)),
        const SizedBox(width: 6),
        Expanded(child: TText(amount, textAlign: TextAlign.right)),
      ],
    ),
  );
}

class _ExtraRule extends StatelessWidget {
  const _ExtraRule({
    required this.icon,
    required this.title,
    required this.summary,
    required this.body,
  });
  final String icon, title, summary, body;
  Future<void> _show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: CourtSceneTokens.parchment,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * .7,
    ),
    builder: (context) => Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TText(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: CourtTokens.ink,
            ),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: SingleChildScrollView(
              child: TText(
                body,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.4,
                  color: CourtTokens.ink,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const ValueKey('rules-extra-close'),
            onPressed: () => Navigator.pop(context),
            child: Text(MaterialLocalizations.of(context).closeButtonTooltip),
          ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Material(
      color: CourtSceneTokens.parchment,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: ValueKey('rules-extra-$icon'),
        onTap: () => _show(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            border: Border.all(color: CourtSceneTokens.gold),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  RulesIcon(icon, size: 18),
                  const SizedBox(width: 5),
                  Expanded(
                    child: TText(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                        color: CourtTokens.ink,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 16, color: _accent),
                ],
              ),
              const SizedBox(height: 4),
              TText(
                summary,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.15,
                  color: CourtTokens.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
