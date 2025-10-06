import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  AuthService({FirebaseAuth? firebaseAuth})
    : _firebaseAuth = firebaseAuth ?? _firebaseAuthProvider();

  static FirebaseAuth Function() _firebaseAuthProvider = () =>
      FirebaseAuth.instance;

  @visibleForTesting
  static void overrideFirebaseAuth(FirebaseAuth Function() provider) {
    _firebaseAuthProvider = provider;
  }

  final FirebaseAuth _firebaseAuth;

  Stream<User?> authStateChanges() => _firebaseAuth.authStateChanges();

  Future<UserCredential?> signInWithApple() async {
    try {
      final AuthorizationCredentialAppleID appleCredential =
          await SignInWithApple.getAppleIDCredential(
            scopes: const <AppleIDAuthorizationScopes>[
              AppleIDAuthorizationScopes.email,
              AppleIDAuthorizationScopes.fullName,
            ],
          );

      final OAuthCredential oauthCredential = OAuthProvider('apple.com')
          .credential(
            idToken: appleCredential.identityToken,
            accessToken: appleCredential.authorizationCode,
          );

      final UserCredential credential =
          await _firebaseAuth.signInWithCredential(oauthCredential);
      await credential.user?.reload();
      return credential;
    } catch (e, stackTrace) {
      debugPrint('signInWithApple failed: $e');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  Future<void> signOut() => _firebaseAuth.signOut();

  String getUserEmail() => _firebaseAuth.currentUser?.email ?? 'User';

  String? getUserPhotoUrl() => _firebaseAuth.currentUser?.photoURL;

  User? get currentUser => _firebaseAuth.currentUser;
}
