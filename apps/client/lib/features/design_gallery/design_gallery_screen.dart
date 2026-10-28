import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';

import '../../design/case_file.dart';
import '../../design/court_theme.dart';
import '../../design/court_scene.dart';
import '../../design/court_assets.dart';
import '../../design/avatar_view.dart';
import '../../domain/avatar_config.dart';

class DesignGalleryScreen extends StatefulWidget {
  const DesignGalleryScreen({super.key});
  @override
  State<DesignGalleryScreen> createState() => _DesignGalleryScreenState();
}

class _DesignGalleryScreenState extends State<DesignGalleryScreen> {
  bool _largeText = false;
  @override
  Widget build(BuildContext context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: _largeText
          ? const TextScaler.linear(2)
          : MediaQuery.textScalerOf(context),
    ),
    child: CourtScaffold(
      title: const TText('galleryTitle'),
      footer: CourtActionBar(
        primary: CourtPrimaryButton(
          onPressed: () {},
          child: const TText('confirmVerdict'),
        ),
        secondary: CourtSecondaryButton(
          onPressed: () {},
          child: const TText('backToCase'),
        ),
      ),
      bodyBuilder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: _largeText
              ? const TextScaler.linear(2)
              : MediaQuery.textScalerOf(context),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: CourtTokens.contentWidth,
            ),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Center(child: CourtBrandMark()),
                const SizedBox(height: 16),
                const Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    CourtArt(CourtAssets.cards, width: 40, height: 40),
                    CourtArt(CourtAssets.phone, width: 40, height: 40),
                    CourtArt(CourtAssets.people, width: 40, height: 40),
                    CourtArt(CourtAssets.gavel, width: 40, height: 40),
                    CourtArt(CourtAssets.dice, width: 40, height: 40),
                    CourtArt(CourtAssets.beer, width: 40, height: 40),
                    CourtArt(CourtAssets.scales, width: 40, height: 40),
                    CourtArt(CourtAssets.refresh, width: 40, height: 40),
                    CourtArt(CourtAssets.eye, width: 40, height: 40),
                  ],
                ),
                const SizedBox(height: 16),
                const CourtArt(CourtAssets.handover, height: 150),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const TText('galleryScale'),
                  value: _largeText,
                  onChanged: (value) => setState(() => _largeText = value),
                ),
                const SizedBox(height: 16),
                TText(
                  'galleryCase',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                CaseFile(
                  label: context.tr('cardCaseLabel'),
                  child: TText('galleryPrompt'),
                ),
                const SizedBox(height: 16),
                CourtSeal(
                  label: context.tr('galleryConfidential'),
                  icon: Icons.lock_outline,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    AvatarView(config: AvatarConfig.masculine(), size: 64),
                    AvatarView(config: AvatarConfig.feminine(), size: 160),
                    AvatarView(
                      config: AvatarConfig(
                        selections: const {
                          'hat': 'tricorn',
                          'top': 'waistcoat',
                          'extra': 'badge',
                          'glasses': 'rectangular',
                          'hairColor': 'copper',
                        },
                      ),
                      size: 96,
                    ),
                    AvatarView(config: AvatarConfig.fallback(), size: 64),
                  ],
                ),
                const NamePlate(name: 'Alex · A', position: 1),
                const SizedBox(height: 16),
                const TText('galleryHelp'),
                const SizedBox(height: 16),
                const Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _Swatch('galleryPaper', CourtTokens.paper),
                    _Swatch('galleryInk', CourtTokens.ink),
                    _Swatch('galleryWood', CourtTokens.wood),
                    _Swatch('gallerySeal', CourtTokens.red),
                    _Swatch('galleryBlue', CourtTokens.blue),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.label, this.color);
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: CourtTokens.border),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      TText(label),
    ],
  );
}
