import 'models/domain_error.dart';
import 'models/ids.dart';

final class Verdict {
  Verdict._(
    List<PlayerId> truth,
    Set<PlayerId> incorrect,
    Map<PlayerId, int> sips,
  ) : truth = List.unmodifiable(truth),
      incorrect = Set.unmodifiable(incorrect),
      sips = Map.unmodifiable(sips);
  final List<PlayerId> truth;
  final Set<PlayerId> incorrect;
  final Map<PlayerId, int> sips;
  int get errors => incorrect.length;
}

void validateOrder(List<PlayerId> order, Iterable<PlayerId> recipients) {
  final expected = recipients.toSet();
  if (order.length != expected.length ||
      order.toSet().length != order.length ||
      !order.toSet().containsAll(expected)) {
    throw const DomainException(
      DomainErrorCode.invalidState,
      'Die Ordnung muss jede beteiligte ID genau einmal enthalten.',
    );
  }
}

List<PlayerId> _truth(Map<PlayerId, int> numbers) {
  if (numbers.values.any((n) => n < 1 || n > 60) ||
      numbers.values.toSet().length != numbers.length) {
    throw const DomainException(
      DomainErrorCode.invalidState,
      'Geheimzahlen müssen eindeutig im gültigen Bereich liegen.',
    );
  }
  return numbers.keys.toList()
    ..sort((a, b) => numbers[a]!.compareTo(numbers[b]!));
}

Verdict normalVerdict({
  required PlayerId judge,
  required Map<PlayerId, int> numbers,
  required List<PlayerId> proposed,
}) {
  validateOrder(proposed, numbers.keys);
  if (numbers.containsKey(judge)) {
    throw const DomainException(
      DomainErrorCode.invalidState,
      'Der Richter erhält im Normalmodus keine Zahl.',
    );
  }
  final truth = _truth(numbers);
  final incorrect = {
    for (var i = 0; i < proposed.length; i++)
      if (proposed[i] != truth[i]) proposed[i],
  };
  final sips = {
    judge: incorrect.length,
    for (final id in proposed)
      id: incorrect.contains(id) ? incorrect.length : 0,
  };
  return Verdict._(truth, incorrect, sips);
}

Map<PlayerId, int> allJudgesVerdict({
  required Map<PlayerId, int> numbers,
  required Map<PlayerId, List<PlayerId>> orders,
}) {
  if (orders.length != numbers.length ||
      !orders.keys.toSet().containsAll(numbers.keys)) {
    throw const DomainException(
      DomainErrorCode.invalidState,
      'Jede Person benötigt genau ein eigenes Urteil.',
    );
  }
  final truth = _truth(numbers);
  return Map.unmodifiable({
    for (final entry in orders.entries)
      entry.key: _personalErrors(entry.value, truth),
  });
}

int _personalErrors(List<PlayerId> proposed, List<PlayerId> truth) {
  validateOrder(proposed, truth);
  return [
    for (var i = 0; i < truth.length; i++)
      if (proposed[i] != truth[i]) i,
  ].length;
}
