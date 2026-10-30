import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Dialog buttons show short labels while retaining the full action name for
/// accessibility. Exercise that same name without coupling flows to copy length.
Finder actionText(String label) => find.byWidgetPredicate(
  (widget) =>
      widget is Text &&
      (widget.data == label || widget.semanticsLabel == label),
  description: 'visible or accessible text "$label"',
);

Finder widgetWithActionText(Type type, String label) =>
    find.ancestor(of: actionText(label), matching: find.byType(type));
