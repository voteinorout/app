import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

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

      return _firebaseAuth.signInWithCredential(oauthCredential);
    } catch (e, stackTrace) {
      debugPrint('signInWithApple failed: $e');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  Future<void> signOut() => _firebaseAuth.signOut();

  String getUserEmail() => _firebaseAuth.currentUser?.email ?? 'User';
}
