import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../data/string_store.dart';

@immutable
class AppSettings {
  const AppSettings({
    this.language = 'de',
    this.reducedMotion = false,
    this.audioEnabled = false,
  });

  final String language;
  final bool reducedMotion;
  final bool audioEnabled;

  AppSettings copyWith({String? language, bool? reducedMotion, bool? audioEnabled}) =>
      AppSettings(
        language: language ?? this.language,
        reducedMotion: reducedMotion ?? this.reducedMotion,
        audioEnabled: audioEnabled ?? this.audioEnabled,
      );

  Map<String, Object> toJson() => {
    'version': 1,
    'language': language,
    'reducedMotion': reducedMotion,
    'audioEnabled': audioEnabled,
  };

  static AppSettings fromJson(Object? value) {
    if (value is! Map<String, dynamic> || value['version'] != 1 ||
        !['de', 'en'].contains(value['language']) ||
        value['reducedMotion'] is! bool || value['audioEnabled'] is! bool) {
      throw const FormatException('Invalid app settings');
    }
    return AppSettings(
      language: value['language'] as String,
      reducedMotion: value['reducedMotion'] as bool,
      audioEnabled: value['audioEnabled'] as bool,
    );
  }
}

/// UI preferences have a separate key and never alter persisted games or history.
class SettingsController extends ChangeNotifier {
  SettingsController(this._store);
  static const storageKey = 'trinktribunal.settings.v1';
  final StringStore _store;
  AppSettings value = const AppSettings();
  String? error;
  Future<void> _pending = Future.value();

  Future<void> load() async {
    try {
      final raw = await _store.read(storageKey);
      value = raw == null ? const AppSettings() : AppSettings.fromJson(jsonDecode(raw));
      error = null;
    } on FormatException {
      value = const AppSettings();
      error = 'settingsInvalid';
    } on Object {
      value = const AppSettings();
      error = 'settingsUnavailable';
    }
    notifyListeners();
  }

  Future<void> update({String? language, bool? reducedMotion, bool? audioEnabled}) {
    if (language != null && language != 'de' && language != 'en') {
      throw ArgumentError.value(language, 'language');
    }
    value = value.copyWith(
      language: language, reducedMotion: reducedMotion, audioEnabled: audioEnabled,
    );
    error = null;
    notifyListeners();
    final snapshot = jsonEncode(value.toJson());
    final write = _pending.then((_) async {
      try {
        await _store.write(storageKey, snapshot);
      } on Object {
        error = 'settingsSaveFailed';
        notifyListeners();
      }
    });
    _pending = write;
    return write;
  }
}
