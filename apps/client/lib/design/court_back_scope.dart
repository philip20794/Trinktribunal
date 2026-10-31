import 'package:flutter/widgets.dart';

/// Gives an in-page overlay priority over the room's route-exit confirmation.
class CourtBackController {
  final _overlays = <Object, VoidCallback>{};
  void register(Object owner, VoidCallback dismiss) =>
      _overlays[owner] = dismiss;
  void unregister(Object owner) => _overlays.remove(owner);
  bool dismissTop() {
    if (_overlays.isEmpty) return false;
    final owner = _overlays.keys.last;
    final dismiss = _overlays.remove(owner)!;
    dismiss();
    return true;
  }

  void clear() => _overlays.clear();
}

class CourtBackScope extends InheritedWidget {
  const CourtBackScope({
    required this.controller,
    required super.child,
    super.key,
  });
  final CourtBackController controller;
  static CourtBackController? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CourtBackScope>()?.controller;
  @override
  bool updateShouldNotify(CourtBackScope oldWidget) =>
      controller != oldWidget.controller;
}
