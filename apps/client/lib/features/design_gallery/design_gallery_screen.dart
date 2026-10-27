import 'package:flutter/material.dart';
import '../../l10n/app_strings.dart';

import '../../design/case_file.dart';
import '../../design/court_theme.dart';
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const TText('galleryTitle')),
    body: MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: _largeText
            ? const TextScaler.linear(2)
            : MediaQuery.textScalerOf(context),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: CourtTokens.contentWidth),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const TText('galleryScale'),
                value: _largeText,
                onChanged: (value) => setState(() => _largeText = value),
              ),
              const SizedBox(height: 16),
              TText('galleryCase',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              const CaseFile(
                label: 'Fallakte 07 / 50',
                child: TText('galleryPrompt',
                ),
              ),
              const SizedBox(height: 16),
              const CourtSeal(label: 'Vertraulich', icon: Icons.lock_outline),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  AvatarView(config: AvatarConfig.masculine(), size: 64),
                  AvatarView(config: AvatarConfig.feminine(), size: 160),
                  AvatarView(config: AvatarConfig.fallback(), size: 64),
                ],
              ),
              const NamePlate(name: 'Alex · A', position: 1),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {},
                child: const TText('confirmVerdict'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {},
                child: const TText('backToCase'),
              ),
              const SizedBox(height: 16),
              const TText('galleryHelp',
              ),
              const SizedBox(height: 16),
              const Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _Swatch('Papier', CourtTokens.paper),
                  _Swatch('Tinte', CourtTokens.ink),
                  _Swatch('Holz', CourtTokens.wood),
                  _Swatch('Siegel', CourtTokens.red),
                  _Swatch('Graublau', CourtTokens.blue),
                ],
              ),
            ],
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
      Text(label),
    ],
  );
}
