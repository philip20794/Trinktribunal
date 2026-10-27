enum GameMode {
  physicalCards('physical_cards'),
  sharedPhone('shared_phone'),
  multiplayer('multiplayer');

  const GameMode(this.value);
  final String value;

  bool get hasPlayerRegistry => this != physicalCards;
  int get maximumQuestions => this == physicalCards ? 431 : 491;
  int get maximumRules => this == physicalCards ? 22 : 25;
}

enum GamePhase {
  lobby,
  casePresented,
  numbers,
  answers,
  ordering,
  revealing,
  judged,
  completedWithoutVerdict,
  ruleEvent,
  paused,
  finished,
}
