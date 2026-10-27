import 'dart:math' as math;

import 'models/domain_error.dart';
import 'selection/random_source.dart';

/// Immutable slots after completed cases; no rule is reserved or drawn here.
final class EventSchedule {
  EventSchedule._(List<int> slots) : slots = List.unmodifiable(slots);

  factory EventSchedule.plan({
    required int targetCases,
    required int requestedRuleEvents,
    required RandomSource random,
  }) {
    if (targetCases < 1 ||
        targetCases > 491 ||
        requestedRuleEvents < 0 ||
        requestedRuleEvents > 25) {
      throw const DomainException(
        DomainErrorCode.invalidConfig,
        'Ungültige Ereignisplanung.',
      );
    }
    final gaps = targetCases - 1;
    final count = math.min(requestedRuleEvents, gaps);
    if (count == 0) return EventSchedule._([]);
    final segments = <List<int>>[];
    var start = 1;
    for (var i = 0; i < count; i++) {
      final size = gaps ~/ count + (i < gaps % count ? 1 : 0);
      segments.add(List.generate(size, (index) => start + index));
      start += size;
    }
    final spacing = gaps >= 2 * count - 1 ? 2 : 1;
    // For interval segments the earliest valid tail proves feasibility. This
    // bounds the work and avoids random rejection loops near dense schedules.
    bool canComplete(int segment, int previous) {
      for (var i = segment; i < segments.length; i++) {
        final earliest = math.max(segments[i].first, previous + spacing);
        if (earliest > segments[i].last) return false;
        previous = earliest;
      }
      return true;
    }

    final slots = <int>[];
    for (var i = 0; i < count; i++) {
      final valid = segments[i]
          .where(
            (slot) =>
                (slots.isEmpty || slot - slots.last >= spacing) &&
                canComplete(i + 1, slot),
          )
          .toList();
      slots.add(choose(valid, random));
    }
    return EventSchedule._(slots);
  }

  final List<int> slots;
}
