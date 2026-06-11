import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:focus_quest/core/services/firestore_service.dart';
import 'package:focus_quest/core/services/preference_storage_service.dart';
import 'package:focus_quest/models/app_user.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final PreferenceStorageService _prefs = PreferenceStorageService();
  final FirestoreService _firestore = FirestoreService();

  static const String _kGuestUserKey = 'guest_user';

  // GoogleSignIn v7 doesn't require explicit initialization
  // The instance is ready to use immediately

  Stream<AppUser?> get authStateChanges async* {
    // Yields the current user once, then forwards Firebase auth changes
    // mapped to AppUser. Guest sessions live in SharedPreferences and are
    // observed via _getGuestUser() on Firebase emissions.
    yield await getCurrentUser();

    await for (final user in _auth.authStateChanges()) {
      if (user != null) {
        yield _firebaseToAppUser(user);
      } else {
        // If firebase user is null, check for guest
        final guest = await _getGuestUser();
        yield guest;
      }
    }
  }

  /// Stream that fires only when Firebase auth state changes (token expiry,
  /// external sign-out from another tab, admin disable). Does NOT yield the
  /// initial value — subscribe to [authStateChanges] for that.
  Stream<AppUser?> get firebaseAuthStateChanges async* {
    await for (final user in _auth.authStateChanges()) {
      if (user != null) {
        yield _firebaseToAppUser(user);
      } else {
        yield await _getGuestUser();
      }
    }
  }

  Future<AppUser?> getCurrentUser() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser != null) {
      return _firebaseToAppUser(firebaseUser);
    }
    return _getGuestUser();
  }

  Future<AppUser?> _getGuestUser() async {
    final guestString = await _prefs.getString(_kGuestUserKey);
    if (guestString != null) {
      try {
        return AppUser.fromJson(
          jsonDecode(guestString) as Map<String, dynamic>,
        );
      } on FormatException {
        return null;
      }
    }
    return null;
  }

  Future<AppUser> signInWithGoogle() async {
    try {
      // Attempt silent sign-in / recovery
      final googleUser = await GoogleSignIn.instance
          .attemptLightweightAuthentication();

      // If silent sign-in failed, check if authenticate is supported
      if (googleUser == null) {
        // Check if authenticate is supported on this platform
        if (GoogleSignIn.instance.supportsAuthenticate()) {
          final authenticatedUser = await GoogleSignIn.instance.authenticate();
          // Process the authenticated user
          final googleAuth = authenticatedUser.authentication;
          final credential = GoogleAuthProvider.credential(
            idToken: googleAuth.idToken,
          );
          final userCredential = await _auth.signInWithCredential(credential);
          final firebaseUser = userCredential.user!;
          await _prefs.remove(_kGuestUserKey);
          return _ensureUserDoc(_firebaseToAppUser(firebaseUser));
        } else {
          // On web, authenticate() is not supported
          // User must use the sign-in button widget or FedCM flow
          throw const GoogleSignInException(
            code: GoogleSignInExceptionCode.canceled,
            description:
                'Sign-in was not completed. '
                'On web, please use the Google Sign-In button widget.',
          );
        }
      }

      final googleAccount = googleUser;

      // Get authentication details
      final googleAuth = googleAccount.authentication;

      // Create a new credential for Firebase
      // Note: In v7, accessToken might be null in authentication tokens
      // if not explicitly authorized.
      // We start with idToken which is standard for OIDC.
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user!;

      // Clear guest user if exists
      await _prefs.remove(_kGuestUserKey);

      return _ensureUserDoc(_firebaseToAppUser(user));
    } on GoogleSignInException catch (e) {
      throw Exception('Google Sign-In error: ${e.code} - ${e.description}');
    } on FirebaseAuthException catch (e) {
      throw Exception('Firebase Auth error: ${e.message}');
    } catch (e) {
      rethrow;
    }
  }

  Future<AppUser> signInWithEmailPassword(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = userCredential.user!;
      await _prefs.remove(_kGuestUserKey);
      return _ensureUserDoc(_firebaseToAppUser(user));
    } on FirebaseAuthException catch (e) {
      throw Exception('Firebase Auth error: ${e.message}');
    }
  }

  Future<AppUser> signUpWithEmailPassword(
    String email,
    String password,
    String name,
  ) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = userCredential.user!;
      await user.updateDisplayName(name);
      await user.reload();
      // Get the updated user object
      final updatedUser = _auth.currentUser ?? user;

      await _prefs.remove(_kGuestUserKey);
      final appUser = _firebaseToAppUser(updatedUser);

      // Create initial user document in Firestore
      await updateLocalUser(appUser);

      return appUser;
    } on FirebaseAuthException catch (e) {
      throw Exception('Firebase Auth error: ${e.message}');
    }
  }

  Future<AppUser> createGuestSession(String name, String avatarUrl) async {
    final guest = AppUser.guest(name: name, avatarUrl: avatarUrl);
    await _prefs.setString(_kGuestUserKey, jsonEncode(guest.toJson()));
    return guest;
  }

  Future<void> signOut() async {
    await _auth.signOut();
    try {
      await GoogleSignIn.instance.disconnect();
    } on Exception catch (_) {
      // Ignore errors during disconnect
    }
    await _prefs.remove(_kGuestUserKey);
  }

  Future<void> updateLocalUser(AppUser user) async {
    // Used for updating settings like sync/gamification locally for caching
    // For guest, this is the primary storage.
    if (user.isGuest) {
      await _prefs.setString(_kGuestUserKey, jsonEncode(user.toJson()));
    } else {
      // For signed in users, save to Firestore
      await _firestore.saveUser(user);
    }
  }

  /// Merges remote-authoritative settings (isSyncEnabled,
  /// isGamificationEnabled) from the Firestore user doc onto [base].
  /// Firebase Auth stays authoritative for identity fields. Returns null for
  /// guests, missing docs, or fetch failures (offline) — callers keep their
  /// local defaults in that case.
  Future<AppUser?> fetchMergedRemoteUser(AppUser base) async {
    if (base.isGuest) return null;
    try {
      final remote = await _firestore
          .getUser(base.id)
          .timeout(const Duration(seconds: 8));
      if (remote == null) return null;
      return base.copyWith(
        isSyncEnabled: remote.isSyncEnabled,
        isGamificationEnabled: remote.isGamificationEnabled,
      );
    } on Object catch (e) {
      debugPrint('fetchMergedRemoteUser failed: $e');
      return null;
    }
  }

  /// Best-effort user-doc round-trip at sign-in: pull remote-authoritative
  /// settings first (so this device can't clobber toggles chosen on another
  /// device), then upsert the doc. Errors are swallowed so a transient
  /// Firestore failure during sign-in does not block the user from entering
  /// the app — the doc will be re-upserted on the next settings change or
  /// sync.
  Future<AppUser> _ensureUserDoc(AppUser user) async {
    final effective = await fetchMergedRemoteUser(user) ?? user;
    try {
      await _firestore.saveUser(effective);
    } on Object {
      // Logged inside FirestoreService.
    }
    return effective;
  }

  AppUser _firebaseToAppUser(User user) {
    return AppUser(
      id: user.uid,
      displayName: user.displayName ?? 'User',
      photoUrl: user.photoURL ?? '',
      email: user.email,
      isGuest: false,
      // Product default for signed-in users. The Firestore user doc is the
      // source of truth for settings; fetchMergedRemoteUser overrides these
      // at sign-in and bootstrap when the doc exists.
      isSyncEnabled: true,
    );
  }
}
