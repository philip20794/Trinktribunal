import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../data/room_transport.dart';
import '../../data/qr_scanner_platform.dart';
import '../../design/court_scene.dart';
import '../../l10n/app_strings.dart';
import 'direct_join.dart';
import 'invitation.dart';
import 'invite.dart';
import 'saved_rooms.dart';

class JoinRoomScreen extends ConsumerStatefulWidget {
  const JoinRoomScreen({
    this.initialCode = '',
    this.invalidInvite = false,
    super.key,
  });
  final String initialCode;
  final bool invalidInvite;
  @override
  ConsumerState<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends ConsumerState<JoinRoomScreen> {
  late final _code = TextEditingController(text: widget.initialCode);
  bool _entering = false;
  String? _scanError;
  String? get _validCode {
    try {
      return normalizedRoomCode(_code.text);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _enter(String code) {
    if (_entering) return;
    setState(() {
      _entering = true;
    });
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => DirectJoinRoomScreen(code: code)),
    );
  }

  void _scanned(String raw) {
    final code = codeFromScannedInvite(raw, ref.read(publicClientBaseProvider));
    if (code == null) {
      setState(() => _scanError = 'roomScanInvalid');
      return;
    }
    _enter(code);
  }

  @override
  Widget build(BuildContext context) => CourtScaffold(
    title: const TText('roomJoin'),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const CurrentRoomResumeButtons(),
            if (widget.invalidInvite) const TText('roomInviteInvalid'),
            TextField(
              key: const ValueKey('room-code'),
              controller: _code,
              enabled: !_entering,
              maxLength: 16,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.go,
              decoration: InputDecoration(labelText: context.tr('roomCode')),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) {
                if (_validCode case final String code) _enter(code);
              },
            ),
            const SizedBox(height: 12),
            _RoomScanner(onValue: _scanned),
            const SizedBox(height: 8),
            const TText('roomScanHint'),
            if (_scanError != null) TText(_scanError!),
          ],
        ),
      ),
    ),
    footer: _validCode == null
        ? null
        : CourtActionBar(
            primary: FilledButton(
              key: const ValueKey('room-submit'),
              onPressed: _entering ? null : () => _enter(_validCode!),
              child: const TText('roomJoinNew'),
            ),
          ),
  );
}

class _RoomScanner extends StatefulWidget {
  const _RoomScanner({required this.onValue});
  final ValueChanged<String> onValue;
  @override
  State<_RoomScanner> createState() => _RoomScannerState();
}

class _RoomScannerState extends State<_RoomScanner>
    with WidgetsBindingObserver {
  final _camera = MobileScannerController(
    autoStart: false,
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _starting = false;
  @override
  void initState() {
    super.initState();
    configureQrScanner();
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> _start() async {
    if (!mounted || _starting) return;
    FocusScope.of(context).unfocus();
    setState(() => _starting = true);
    try {
      await _camera.start();
    } on MobileScannerException catch (_) {
      /* The view renders camera errors. */
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_camera.value.hasCameraPermission) return;
    if (state == AppLifecycleState.resumed) {
      unawaited(_start());
    } else {
      unawaited(_camera.stop());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_camera.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<MobileScannerState>(
        valueListenable: _camera,
        builder: (context, state, _) {
          final showingCamera =
              state.isInitialized && state.isRunning && state.error == null;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      MobileScanner(
                        controller: _camera,
                        useAppLifecycleState: false,
                        placeholderBuilder: (_) => const SizedBox.expand(),
                        errorBuilder: (_, _) => const SizedBox.expand(),
                        onDetect: (capture) {
                          for (final barcode in capture.barcodes) {
                            final raw = barcode.rawValue;
                            if (raw != null) {
                              widget.onValue(raw);
                              return;
                            }
                          }
                        },
                      ),
                      if (!showingCamera)
                        ColoredBox(
                          key: const ValueKey('room-camera-placeholder'),
                          color: CourtSceneTokens.panel,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.qr_code_scanner, size: 64),
                                    const SizedBox(height: 16),
                                    TText(
                                      state.error == null
                                          ? 'roomCameraPlaceholder'
                                          : state.error!.errorCode ==
                                                MobileScannerErrorCode
                                                    .permissionDenied
                                          ? 'roomCameraPermission'
                                          : 'roomCameraUnavailable',
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (!showingCamera) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const ValueKey('open-room-camera'),
                  icon: const Icon(Icons.videocam_outlined),
                  label: const TText('roomOpenCamera'),
                  onPressed: _starting ? null : () => unawaited(_start()),
                ),
              ],
            ],
          );
        },
      );
}
