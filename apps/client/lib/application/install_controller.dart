import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/install_platform.dart' as platform;

typedef InstallAction = Future<Map<String, dynamic>> Function(
  String action, [
  String argument,
]);

final installControllerProvider = Provider<InstallController>((ref) {
  final controller = InstallController();
  ref.onDispose(controller.dispose);
  return controller;
});

class InstallController extends ChangeNotifier {
  InstallController({InstallAction? action, bool listen = true})
    : _action = action ?? platform.installAction {
    if (listen) {
      _cancel = platform.listenInstallChanges(() => unawaited(refresh()));
    }
    ready = refresh();
  }
  final InstallAction _action;
  VoidCallback? _cancel;
  bool _disposed = false;
  late final Future<void> ready;
  Map<String, dynamic> _state = {};
  bool get web => _state['web'] == true;
  bool get android => _state['android'] == true;
  bool get ios => _state['ios'] == true;
  bool get installedContext => !web || _state['standalone'] == true;
  bool get pwaInstalled => _state['pwaInstalled'] == true;
  bool get apkInstalled => _state['apkInstalled'] == true;
  bool get canPrompt => _state['canPrompt'] == true;
  bool get downloaded => _state['downloaded'] == true;
  bool get showPromotion => web && _state['showPromotion'] == true;
  String? get pendingCode => _state['pending'] as String?;
  Future<void> refresh() async {
    await act('status');
  }

  Future<String?> act(String action, [String argument = '']) async {
    final result = await _action(action, argument);
    if (!_disposed) {
      _state = result;
      notifyListeners();
    }
    return result['result'] as String?;
  }

  @override
  void dispose() {
    _disposed = true;
    _cancel?.call();
    super.dispose();
  }
}
