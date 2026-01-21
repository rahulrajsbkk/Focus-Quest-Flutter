// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AppUser _$AppUserFromJson(Map<String, dynamic> json) => _AppUser(
  id: json['id'] as String,
  displayName: json['displayName'] as String,
  photoUrl: json['photoUrl'] as String,
  isGuest: json['isGuest'] as bool,
  isSyncEnabled: json['isSyncEnabled'] as bool? ?? false,
  isGamificationEnabled: json['isGamificationEnabled'] as bool? ?? true,
  email: json['email'] as String?,
);

Map<String, dynamic> _$AppUserToJson(_AppUser instance) => <String, dynamic>{
  'id': instance.id,
  'displayName': instance.displayName,
  'photoUrl': instance.photoUrl,
  'isGuest': instance.isGuest,
  'isSyncEnabled': instance.isSyncEnabled,
  'isGamificationEnabled': instance.isGamificationEnabled,
  'email': instance.email,
};
