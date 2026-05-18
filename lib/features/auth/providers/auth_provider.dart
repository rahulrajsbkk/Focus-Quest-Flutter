import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_quest/core/services/auth_service.dart';
import 'package:focus_quest/core/services/sync_service.dart';
import 'package:focus_quest/features/journal/providers/journal_provider.dart';
import 'package:focus_quest/features/profile/providers/activity_stats_provider.dart';
import 'package:focus_quest/features/profile/providers/user_progress_provider.dart';
import 'package:focus_quest/features/tasks/providers/quest_provider.dart';
import 'package:focus_quest/features/timer/providers/focus_session_provider.dart';
import 'package:focus_quest/models/app_user.dart';
import 'package:focus_quest/services/sembast_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

class AuthNotifier extends AsyncNotifier<AppUser?> {
  late final AuthService _authService;
  bool _initialized = false;
  StreamSubscription<AppUser?>? _externalAuthSub;

  @override
  Future<AppUser?> build() async {
    _authService = ref.read(authServiceProvider);

    // Subscribe to Firebase-driven auth state changes (token expiry,
    // external sign-out, etc.). The local guest flow does not flow through
    // this stream — the explicit sign-in/out methods handle that.
    _externalAuthSub = _authService.firebaseAuthStateChanges.listen((user) {
      if (!_initialized) return;
      unawaited(_handleExternalAuthChange(user));
    });
    ref.onDispose(() => _externalAuthSub?.cancel());

    final initial = await _authService.getCurrentUser();
    // Make sure provider reads that happen during this same frame target
    // the correct user's local database.
    await SembastService().setActiveUser(initial?.id);
    _initialized = true;

    // Bootstrap sync (full sync + start streams) for the initial user.
    if (initial != null && initial.isSyncEnabled) {
      // Defer past build() so we don't invalidate providers mid-build.
      unawaited(Future.microtask(() => _bootstrapSync(initial)));
    }
    return initial;
  }

  Future<void> _handleExternalAuthChange(AppUser? user) async {
    final current = state.value;
    if (_sameIdentity(current, user)) return;
    state = AsyncValue.data(user);
    await _handleUserTransition(user);
  }

  bool _sameIdentity(AppUser? a, AppUser? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return a.id == b.id && a.isGuest == b.isGuest;
  }

  /// Performs the work required when the signed-in user changes:
  /// stop streams for the previous user, switch the local DB, drop cached
  /// per-user state, then bootstrap sync for the new user.
  Future<void> _handleUserTransition(AppUser? newUser) async {
    try {
      ref.read(syncServiceProvider).stopRealTimeSync();
    } on Object catch (e) {
      debugPrint('Auth transition: stopRealTimeSync error: $e');
    }
    await SembastService().setActiveUser(newUser?.id);
    _invalidateUserScopedProviders();
    if (newUser != null && newUser.isSyncEnabled) {
      await _bootstrapSync(newUser);
    }
  }

  Future<void> _bootstrapSync(AppUser user) async {
    final sync = ref.read(syncServiceProvider);
    // H1: full sync must complete before real-time streams start so we
    // don't interleave incoming writes with two-way reconciliation.
    await sync.flushOutbox();
    await sync.performFullSync();
    sync.startRealTimeSync();
    _invalidateUserScopedProviders();
  }

  void _invalidateUserScopedProviders() {
    ref
      ..invalidate(questListProvider)
      ..invalidate(focusSessionProvider)
      ..invalidate(journalProvider)
      ..invalidate(userProgressProvider)
      ..invalidate(activityHeatmapProvider);
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _authService.signInWithGoogle());
    if (state.hasValue && state.value != null) {
      await _handleUserTransition(state.value);
    }
  }

  Future<void> signInAsGuest(String name, String avatarUrl) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _authService.createGuestSession(name, avatarUrl),
    );
    if (state.hasValue && state.value != null) {
      await _handleUserTransition(state.value);
    }
  }

  Future<void> signInWithEmailPassword(String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _authService.signInWithEmailPassword(email, password),
    );
    if (state.hasValue && state.value != null) {
      await _handleUserTransition(state.value);
    }
  }

  Future<void> signUpWithEmailPassword(
    String email,
    String password,
    String name,
  ) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _authService.signUpWithEmailPassword(email, password, name),
    );
    if (state.hasValue && state.value != null) {
      await _handleUserTransition(state.value);
    }
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    await _authService.signOut();
    state = const AsyncValue.data(null);
    await _handleUserTransition(null);
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

    // Handle sync-enabled toggle (settings change, not user change).
    if (isSyncEnabled != null && isSyncEnabled != currentUser.isSyncEnabled) {
      if (isSyncEnabled) {
        await _bootstrapSync(updatedUser);
      } else {
        ref.read(syncServiceProvider).stopRealTimeSync();
      }
    }
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, AppUser?>(
  AuthNotifier.new,
);
