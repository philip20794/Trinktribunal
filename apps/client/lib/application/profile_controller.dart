import '../data/profile_store.dart';
import '../domain/avatar_config.dart';
import '../domain/models/domain_error.dart';
import '../domain/models/ids.dart';
import '../domain/models/player.dart';
import '../domain/selection/random_source.dart';
import '../domain/user_profile.dart';

final class ProfileController {
  ProfileController(this.store, {String Function()? newId})
    : _newId = newId ?? _id;
  final ProfileStore store;
  final String Function() _newId;
  UserProfile? profile;
  String? error;
  bool saving = false;
  Future<void> load() async {
    try {
      final loaded = await store.load();
      profile = loaded.profile;
      error = loaded.recovered
          ? 'Das gespeicherte Profil war beschädigt. Bitte prüfen und erneut speichern.'
          : null;
    } on Object {
      error = 'Das Profil konnte nicht geladen werden. Du kannst es erneut versuchen oder neu anlegen.';
    }
  }

  Future<bool> save({
    required String name,
    required AvatarConfig avatar,
  }) async {
    if (saving) return false;
    saving = true;
    try {
      final next = UserProfile(
        player: Player(
          id: profile?.player.id ?? PlayerId(_newId()),
          name: name,
        ),
        avatar: avatar,
      );
      await store.save(next);
      profile = next;
      error = null;
      return true;
    } on DomainException catch (failure) {
      error = failure.message;
      return false;
    } on Object {
      error = 'Das Profil konnte nicht gespeichert werden. Deine Änderungen bleiben im Editor erhalten.';
      return false;
    } finally {
      saving = false;
    }
  }

  static String _id() {
    final random = SecureRandomSource();
    return List.generate(
      32,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
  }
}
