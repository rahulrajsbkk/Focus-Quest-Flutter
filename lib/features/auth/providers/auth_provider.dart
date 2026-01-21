import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_quest/core/services/auth_service.dart';
import 'package:focus_quest/models/app_user.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authStateProvider = StreamProvider<AppUser?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

class AuthNotifier extends AsyncNotifier<AppUser?> {
  late final AuthService _authService;

  @override
  Future<AppUser?> build() async {
    _authService = ref.read(authServiceProvider);
    return _authService.getCurrentUser();
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return _authService.signInWithGoogle();
    });
  }

  Future<void> signInAsGuest(String name, String avatarUrl) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return _authService.createGuestSession(name, avatarUrl);
    });
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    await _authService.signOut();
    state = const AsyncValue.data(null);
  }

  Future<void> updateSettings({
    bool? isSyncEnabled,
    bool? isGamificationEnabled,
  }) async {
    final currentUser = state.value;
    if (currentUser == null) return;

    final updatedUser = currentUser.copyWith(
      isSyncEnabled: isSyncEnabled ?? currentUser.isSyncEnabled,
      isGamificationEnabled:
          isGamificationEnabled ?? currentUser.isGamificationEnabled,
    );

    await _authService.updateLocalUser(updatedUser);
    state = AsyncValue.data(updatedUser);
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, AppUser?>(
  AuthNotifier.new,
);
