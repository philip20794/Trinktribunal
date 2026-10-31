import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

@JS('trinktribunalInstall')
external JSPromise<JSString> _action(JSString action, JSString argument);

Future<Map<String, dynamic>> installAction(
  String action, [
  String argument = '',
]) async {
  try {
    return jsonDecode((await _action(action.toJS, argument.toJS).toDart).toDart)
        as Map<String, dynamic>;
  } catch (_) {
    return {'web': true, 'showPromotion': false, 'result': 'failed'};
  }
}

VoidCallback listenInstallChanges(VoidCallback callback) {
  final listener = ((web.Event event) => callback()).toJS;
  web.window.addEventListener('trinktribunal-install-change', listener);
  return () =>
      web.window.removeEventListener('trinktribunal-install-change', listener);
}
