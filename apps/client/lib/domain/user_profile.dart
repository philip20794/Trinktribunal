import 'avatar_config.dart';
import 'models/ids.dart';
import 'models/player.dart';

final class UserProfile {
  const UserProfile({required this.player, required this.avatar});
  final Player player;
  final AvatarConfig avatar;

  Map<String, Object> toJson() => {
    'version': 1,
    'id': player.id.value,
    'name': player.name,
    'avatar': avatar.toJson(),
  };
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    if (json['version'] is! int || json['version'] != 1) {
      throw const FormatException('Unbekannte Profilversion');
    }
    return UserProfile(
      player: Player(
        id: PlayerId(json['id'] as String),
        name: json['name'] as String,
      ),
      avatar: AvatarConfig.fromJson(json['avatar']),
    );
  }
}
