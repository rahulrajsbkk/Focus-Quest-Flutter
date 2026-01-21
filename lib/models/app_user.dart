import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_user.freezed.dart';

part 'app_user.g.dart';

@freezed
abstract class AppUser with _$AppUser {
  const factory AppUser({
    required String id,
    required String displayName,
    required String photoUrl,
    required bool isGuest,
    @Default(false) bool isSyncEnabled,
    @Default(true) bool isGamificationEnabled,
    String? email,
  }) = _AppUser;

  const AppUser._();

  factory AppUser.fromJson(Map<String, dynamic> json) =>
      _$AppUserFromJson(json);

  factory AppUser.guest({
    required String name,
    required String avatarUrl,
  }) {
    return AppUser(
      id: 'guest_${DateTime.now().millisecondsSinceEpoch}',
      displayName: name,
      photoUrl: avatarUrl,
      isGuest: true,
      // isSyncEnabled defaults to false
      // isGamificationEnabled defaults to true
    );
  }
}
