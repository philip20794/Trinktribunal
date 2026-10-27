import 'dart:math';

import '../models/domain_error.dart';

typedef UtcClock = DateTime Function();

abstract interface class RandomSource {
  int nextInt(int upperBound);
}

final class SecureRandomSource implements RandomSource {
  final Random _random = Random.secure();

  @override
  int nextInt(int upperBound) => _random.nextInt(upperBound);
}

T choose<T>(List<T> candidates, RandomSource random) {
  if (candidates.isEmpty) {
    throw const DomainException(
      DomainErrorCode.contentExhausted,
      'Keine geeigneten Inhalte verfügbar.',
    );
  }
  final index = random.nextInt(candidates.length);
  if (index < 0 || index >= candidates.length) {
    throw const DomainException(
      DomainErrorCode.invalidState,
      'Ungültiger injizierter Zufallsindex.',
    );
  }
  return candidates[index];
}
