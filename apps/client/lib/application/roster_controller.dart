import 'dart:convert';

import '../data/string_store.dart';
import '../domain/avatar_config.dart';
import '../domain/models/domain_error.dart';
import '../domain/models/ids.dart';
import '../domain/models/player.dart';
import '../domain/selection/random_source.dart';
import '../domain/user_profile.dart';

final class RosterController {
  RosterController(this.storage, {this.newId, RandomSource? random})
    : _random = random ?? SecureRandomSource();
  static const key = 'trinktribunal.roster.v1';
  final StringStore storage;
  final RandomSource _random;
  final String Function()? newId;
  List<UserProfile> _members = const [];
  List<UserProfile> get members => _members;
  String? error;
  bool busy = false;
  bool get canStart => _members.length >= 3 && _members.length <= 20;

  Future<void> load() async {
    try {
      final raw = await storage.read(key);
      if (raw == null) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['version'] is! int || data['version'] != 1) {
        throw const FormatException('version');
      }
      final loaded = (data['members'] as List)
          .map((m) => UserProfile.fromJson(m as Map<String, dynamic>))
          .toList();
      if (loaded.length > 20 ||
          loaded.map((m) => m.player.id).toSet().length != loaded.length) {
        throw const FormatException('roster');
      }
      _members = List.unmodifiable(loaded);
      error = loaded.any((m) => m.avatar.isFallback)
          ? 'Eine unbekannte Figur wurde durch eine Ersatzfigur dargestellt.'
          : null;
    } on Object {
      error = 'Die Gruppe konnte nicht geladen werden. Bitte erneut versuchen oder neu anlegen.';
    }
  }

  Future<bool> add(String name, {AvatarConfig? avatar}) => _change(() {
    if (_members.length >= 20) {
      _invalid('Die Gruppe ist mit 20 Personen vollständig.');
    }
    final id = PlayerId(
      newId?.call() ??
          List.generate(
            32,
            (_) => _random.nextInt(16).toRadixString(16),
          ).join(),
    );
    if (_members.any((m) => m.player.id == id)) {
      _invalid(
        'Die neue Spieler-ID ist bereits vergeben. Bitte erneut versuchen.',
      );
    }
    return [
      ..._members,
      UserProfile(
        player: Player(id: id, name: name),
        avatar: avatar ?? AvatarConfig.random(_random),
      ),
    ];
  });

  Future<bool> update(PlayerId id, String name, AvatarConfig avatar) =>
      _change(() {
        if (!_members.any((m) => m.player.id == id)) {
          _invalid('Unbekannte Person.');
        }
        return [
          for (final member in _members)
            member.player.id == id
                ? UserProfile(
                    player: Player(id: id, name: name),
                    avatar: avatar,
                  )
                : member,
        ];
      });

  Future<bool> remove(PlayerId id) => _change(() {
    if (!_members.any((m) => m.player.id == id)) _invalid('Unbekannte Person.');
    return _members.where((m) => m.player.id != id).toList();
  });

  Future<bool> restore(UserProfile member, int index) => _change(() {
    if (_members.length >= 20 ||
        _members.any((m) => m.player.id == member.player.id)) {
      _invalid('Die Person kann nicht wiederhergestellt werden.');
    }
    final next = List<UserProfile>.of(_members);
    next.insert(index.clamp(0, next.length), member);
    return next;
  });

  Future<bool> move(int oldIndex, int newIndex) => _change(() {
    if (oldIndex < 0 ||
        newIndex < 0 ||
        oldIndex >= _members.length ||
        newIndex >= _members.length) {
      _invalid('Ungültige Sitzposition.');
    }
    final next = List<UserProfile>.of(_members);
    final member = next.removeAt(oldIndex);
    next.insert(newIndex, member);
    return next;
  });

  String displayName(UserProfile member) =>
      _members.where((m) => m.player.name == member.player.name).length > 1
      ? '${member.player.name} · Platz ${_members.indexOf(member) + 1}'
      : member.player.name;

  Future<bool> _change(List<UserProfile> Function() transform) async {
    if (busy) return false;
    busy = true;
    try {
      final next = transform();
      await storage.write(
        key,
        jsonEncode({
          'version': 1,
          'members': next.map((m) => m.toJson()).toList(),
        }),
      );
      _members = List.unmodifiable(next);
      error = null;
      return true;
    } on DomainException catch (failure) {
      error = failure.message;
      return false;
    } on Object {
      error = 'Die Gruppe konnte nicht gespeichert werden. Die bisherige Gruppe bleibt erhalten.';
      return false;
    } finally {
      busy = false;
    }
  }
}

Never _invalid(String message) =>
    throw DomainException(DomainErrorCode.invalidState, message);
