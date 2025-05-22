import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class GoogleAuthResult {
  final User? user;
  final bool isNewUser;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final String? errorMessage;

  GoogleAuthResult({
    this.user,
    this.isNewUser = false,
    this.email,
    this.displayName,
    this.photoUrl,
    this.errorMessage,
  });
}

class GoogleAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Sign in with Google and check if user exists
  Future<GoogleAuthResult> signInWithGoogle() async {
    try {
      // Start the Google sign-in process
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // User canceled the sign-in
        return GoogleAuthResult(
          isNewUser: false,
          errorMessage: 'Google sign-in was canceled',
        );
      }

      // Get authentication details
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with Google credential
      final UserCredential authResult =
          await _auth.signInWithCredential(credential);
      final User? user = authResult.user;

      if (user == null) {
        return GoogleAuthResult(
          isNewUser: false,
          errorMessage: 'Failed to sign in with Google',
        );
      }

      // Check if this Google user exists in our Firestore database
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final bool isNewUser = !userDoc.exists;

      return GoogleAuthResult(
        user: user,
        isNewUser: isNewUser,
        email: user.email,
        displayName: user.displayName,
        photoUrl: user.photoURL,
      );
    } catch (e) {
      debugPrint('Error signing in with Google: $e');
      return GoogleAuthResult(
        isNewUser: false,
        errorMessage: 'Error signing in with Google: $e',
      );
    }
  }

  // Complete the registration process for a new Google user
  Future<bool> completeGoogleUserRegistration({
    required String uid,
    required String fullName,
    required String role,
    String? photoUrl,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      // Update the user's display name in Firebase Auth if it changed
      final currentUser = _auth.currentUser;
      if (currentUser != null && currentUser.displayName != fullName) {
        await currentUser.updateDisplayName(fullName);
      }

      // Create the user document in Firestore
      final userData = {
        'email': currentUser?.email,
        'name': fullName,
        'role': role,
        'profile_picture': photoUrl ?? currentUser?.photoURL ?? '',
        'created_at': FieldValue.serverTimestamp(),
        'isGoogleAccount': true,
        ...?additionalData,
      };

      await _firestore.collection('users').doc(uid).set(userData);
      return true;
    } catch (e) {
      debugPrint('Error completing Google user registration: $e');
      return false;
    }
  }

  // Sign out from both Firebase and Google
  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
  }
}
