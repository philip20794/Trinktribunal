import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../l10n/app_strings.dart';
import 'invitation.dart';

final publicClientBaseProvider = Provider<Uri?>((ref) {
  const configured = String.fromEnvironment('PUBLIC_CLIENT_BASE_URL');
  final uri = configured.isEmpty ? Uri.base : Uri.tryParse(configured);
  if (uri == null || !['http', 'https'].contains(uri.scheme)) return null;
  if (configured.isNotEmpty) {
    try {
      invitationUri(uri, 'ABCD2345');
    } on Object {
      return null;
    }
  }
  return Uri.parse(uri.origin);
});

class RoomInvite extends ConsumerWidget {
  const RoomInvite({required this.code, super.key});
  final String code;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final base = ref.watch(publicClientBaseProvider);
    Uri? link;
    try {
      if (base != null) link = invitationUri(base, code);
    } on Object {
      /* Code entry remains available. */
    }
    final payload = link?.toString();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (payload != null) ...[
          const SizedBox(height: 12),
          // AlertDialog measures intrinsic sizes. Isolate QrImageView's
          // LayoutBuilder behind known dimensions instead of querying it.
          SizedBox.square(
            dimension: 220,
            child: QrImageView(
              data: payload,
              size: 220,
              backgroundColor: Colors.white,
              semanticsLabel: context.tr('roomInviteQr'),
            ),
          ),
          Text(
            context.tr('roomInviteCode', {'code': code}),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Builder(
            builder: (context) => FilledButton.icon(
              icon: const Icon(Icons.share_outlined),
              label: const TText('roomShareLink'),
              onPressed: () async {
                final box = context.findRenderObject() as RenderBox?;
                try {
                  await SharePlus.instance.share(
                    ShareParams(
                      uri: link,
                      sharePositionOrigin: box == null
                          ? null
                          : box.localToGlobal(Offset.zero) & box.size,
                    ),
                  );
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: TText('roomShareFailed')),
                    );
                  }
                }
              },
            ),
          ),
        ] else ...[
          Text(
            context.tr('roomInviteCode', {'code': code}),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const TText('roomInviteUnavailable'),
        ],
      ],
    );
  }
}
