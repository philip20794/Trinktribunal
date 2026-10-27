import 'package:flutter_test/flutter_test.dart';
import 'package:trinktribunal/domain/event_schedule.dart';

import 'selection_support.dart';

void main() {
  test(
    'bounded stratified schedules for all F/R combinations and tie extremes',
    () {
      for (final last in [false, true]) {
        for (var f = 1; f <= 491; f++) {
          for (var r = 0; r <= 25; r++) {
            final slots = EventSchedule.plan(
              targetCases: f,
              requestedRuleEvents: r,
              random: TestRandom(last: last),
            ).slots;
            final count = r < f ? r : f - 1;
            expect(slots.length, count);
            var start = 1;
            for (var i = 0; i < count; i++) {
              final size = (f - 1) ~/ count + (i < (f - 1) % count ? 1 : 0);
              expect(slots[i], inInclusiveRange(start, start + size - 1));
              if (i > 0) {
                expect(
                  slots[i] - slots[i - 1],
                  greaterThanOrEqualTo(f - 1 >= 2 * count - 1 ? 2 : 1),
                );
              }
              start += size;
            }
          }
        }
      }
    },
  );
  test('fixture F=6 chooses 2 and 5; dense F=3 permits adjacency', () {
    final plan = EventSchedule.plan(
      targetCases: 6,
      requestedRuleEvents: 2,
      random: TestRandom(indices: [1, 1]),
    );
    expect(plan.slots, [2, 5]);
    expect(
      EventSchedule.plan(
        targetCases: 3,
        requestedRuleEvents: 2,
        random: TestRandom(),
      ).slots,
      [1, 2],
    );
    expect(
      EventSchedule.plan(
        targetCases: 1,
        requestedRuleEvents: 7,
        random: TestRandom(),
      ).slots,
      isEmpty,
    );
    expect(() => plan.slots.clear(), throwsUnsupportedError);
  });
}
