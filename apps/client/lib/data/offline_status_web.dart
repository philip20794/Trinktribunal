import 'dart:convert';
import 'dart:js_interop';

@JS('trinktribunalOffline')
external JSPromise<JSString> _offlineAction(JSString action);

Future<Map<String, dynamic>> offlineAction(String action) async {
  try {
    return jsonDecode((await _offlineAction(action.toJS).toDart).toDart)
        as Map<String, dynamic>;
  } catch (_) {
    return {'state': 'unavailable'};
  }
}
