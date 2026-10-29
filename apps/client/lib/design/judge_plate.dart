import 'package:flutter/material.dart';

import '../domain/user_profile.dart';
import '../l10n/app_strings.dart';
import 'avatar_view.dart';
import 'court_assets.dart';
import 'court_scene.dart';

/// Coordinates follow the supplied 2172 x 724 artwork.
class JudgePlate extends StatelessWidget {
  const JudgePlate({required this.profile, super.key});
  final UserProfile profile;
  @override
  Widget build(BuildContext context) => Semantics(
    label: context.tr('caseGuide', {'name': profile.player.name}),
    child: ExcludeSemantics(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: AspectRatio(
            aspectRatio: 2172 / 600,
            child: LayoutBuilder(
              builder: (context, bounds) {
                final width = bounds.maxWidth;
                // The transparent lower edge is outside the useful plate area.
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      child: CourtArt(
                        CourtAssets.judgePlate,
                        width: width,
                        height: width * 724 / 2172,
                      ),
                    ),
                    Positioned(
                      left: width * .215,
                      top: width * .071,
                      width: width * .185,
                      height: width * .185,
                      child: AvatarHeadView(
                        config: profile.avatar,
                        size: width * .185,
                        label: profile.player.name,
                      ),
                    ),
                    Positioned(
                      left: width * .47,
                      right: width * .09,
                      top: width * .106,
                      height: width * .085,
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            profile.player.name,
                            style: const TextStyle(
                              color: CourtSceneTokens.cream,
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}
