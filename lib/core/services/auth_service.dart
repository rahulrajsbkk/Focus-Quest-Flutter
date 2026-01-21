import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:focus_quest/core/services/preference_storage_service.dart';
import 'package:focus_quest/models/app_user.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final PreferenceStorageService _prefs = PreferenceStorageService();

  static const String _kGuestUserKey = 'guest_user';

  // Track if GoogleSignIn has been initialized
  bool _isGoogleSignInInitialized = false;

  /// Initialize Google Sign-In (must be called before using Google auth)
  Future<void> initializeGoogleSignIn() async {
    if (!_isGoogleSignInInitialized) {
      await GoogleSignIn.instance.initialize();
      _isGoogleSignInInitialized = true;
    }
  }

  Stream<AppUser?> get authStateChanges async* {
    // Combine Firebase auth changes with local guest checks
    // This simple implementation checks firebase stream.
    // Handling guest + firebase stream is tricky.
    // Instead, we will rely on the provider to rebuild when notify is called.
    // But we can yield the current state initially.

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
      // Ensure Google Sign-In is initialized
      await initializeGoogleSignIn();

      // Trigger the authentication flow
      final googleUser = await GoogleSignIn.instance.authenticate();

      // Get authentication details from the GoogleSignInAccount
      final googleAuth = googleUser.authentication;

      // Create a new credential for Firebase
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user!;

      // Clear guest user if exists
      await _prefs.remove(_kGuestUserKey);

      return _firebaseToAppUser(user);
    } on GoogleSignInException catch (e) {
      throw Exception(
        'Google Sign-In error: ${e.code} - ${e.description}',
      );
    } on FirebaseAuthException catch (e) {
      throw Exception('Firebase Auth error: ${e.message}');
    } catch (e) {
      rethrow;
    }
  }

  Future<AppUser> createGuestSession(String name, String avatarUrl) async {
    final guest = AppUser.guest(name: name, avatarUrl: avatarUrl);
    await _prefs.setString(_kGuestUserKey, jsonEncode(guest.toJson()));
    return guest;
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await GoogleSignIn.instance.disconnect();
    await _prefs.remove(_kGuestUserKey);
  }

  Future<void> updateLocalUser(AppUser user) async {
    // Used for updating settings like sync/gamification locally for caching
    // For guest, this is the primary storage.
    if (user.isGuest) {
      await _prefs.setString(_kGuestUserKey, jsonEncode(user.toJson()));
    } else {
      // For signed in users, ideally we save these prefs to
      // Firestore or separate local prefs. For now, we can piggyback
      // existing PreferenceStorageService logic for "settings".
      // But the user object itself won't be updated in Firebase Auth
      // (except display name/photo). Here we just acknowledge the update.
    }
  }

  AppUser _firebaseToAppUser(User user) {
    return AppUser(
      id: user.uid,
      displayName: user.displayName ?? 'User',
      photoUrl: user.photoURL ?? '',
      email: user.email,
      isGuest: false,
      isSyncEnabled: true,
    );
  }
}
