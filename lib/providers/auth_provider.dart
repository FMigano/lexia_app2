import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
// Keep the import but implement a conditional approach
import 'package:google_sign_in/google_sign_in.dart'
    if (dart.library.html) 'package:lexia_app/util/web_google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

enum UserRole { parent, professional }

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _user;
  UserRole? _userRole;
  bool _isLoading = false;
  String? _errorMessage;

  User? get user => _user;
  UserRole? get userRole => _userRole;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      if (user != null) {
        _loadUserRole();
      } else {
        _userRole = null;
      }
      notifyListeners();
    });
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<void> _loadUserRole() async {
    if (_user != null) {
      try {
        debugPrint('Loading role for user: ${_user!.uid}');
        final doc = await _firestore.collection('users').doc(_user!.uid).get();
        final data = doc.data();

        // Add this debug print to see what's actually in Firestore
        debugPrint('User data from Firestore: $data');

        if (data != null && data.containsKey('role')) {
          final roleString = data['role'] as String;
          debugPrint('Role string from Firestore: "$roleString"');

          // Make case-insensitive comparison to be safer
          _userRole = roleString.toLowerCase() == 'professional'
              ? UserRole.professional
              : UserRole.parent;

          debugPrint(
              'Set user role to: ${_userRole == UserRole.professional ? "professional" : "parent"}');
        } else {
          debugPrint('No role field found in user data');
        }
        notifyListeners();
      } catch (e) {
        debugPrint('Error loading user role: $e');
      }
    }
  }

  Future<bool> signInWithEmail(String email, String password) async {
    try {
      _setLoading(true);
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _user = userCredential.user;
      await _loadUserRole();
      return true;
    } catch (e) {
      debugPrint('Error signing in: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signInWithGoogle() async {
    try {
      _setLoading(true);
      UserCredential? userCredential;

      if (kIsWeb) {
        // Web implementation
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        userCredential = await _auth.signInWithPopup(googleProvider);
      } else {
        // Mobile implementation
        final GoogleSignIn googleSignIn = GoogleSignIn();
        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

        if (googleUser == null) return false;

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        userCredential = await _auth.signInWithCredential(credential);
      }

      _user = userCredential.user;

      // Check if this is a first-time sign-in
      final doc = await _firestore.collection('users').doc(_user!.uid).get();
      if (!doc.exists) {
        // Create new user document for first-time Google sign-in
        await _firestore.collection('users').doc(_user!.uid).set({
          'name': _user!.displayName ?? '',
          'email': _user!.email ?? '',
          'photoUrl': _user!.photoURL ?? '',
          'role': 'parent', // Default role
          'createdAt': FieldValue.serverTimestamp(),
        });
        _userRole = UserRole.parent;
      } else {
        await _loadUserRole();
      }

      return true;
    } catch (e) {
      debugPrint('Error signing in with Google: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> register(
      String email, String password, String name, UserRole role) async {
    try {
      _setLoading(true);

      // Create the user in Firebase Authentication
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      _user = userCredential.user;

      // Update the user's display name
      await _user!.updateDisplayName(name);

      // Create a new user document in Firestore
      await _firestore.collection('users').doc(_user!.uid).set({
        'name': name,
        'email': email,
        'photoUrl': '',
        'role': role == UserRole.professional ? 'professional' : 'parent',
        'createdAt': FieldValue.serverTimestamp(),
        'bio': '',
        'location': '',
        'isVerified': false,
      });

      // Set the user role locally
      _userRole = role;

      // Add these debug prints to verify the role is correctly set
      debugPrint(
          'User registered with role: ${role == UserRole.professional ? "professional" : "parent"}');

      // Send email verification
      await _user!.sendEmailVerification();

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Registration error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> addChildAccount(String name, int age, String? photoUrl,
      Map<String, dynamic> additionalInfo) async {
    try {
      if (_user == null || !_user!.emailVerified) {
        debugPrint('Parent email must be verified to add a child account');
        return false;
      }

      _setLoading(true);

      // Generate a unique ID for the child
      final String childId = const Uuid().v4();

      // Create child document
      await _firestore.collection('children').doc(childId).set({
        'name': name,
        'age': age,
        'parentId': _user!.uid,
        'photoUrl': photoUrl ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'additionalInfo': additionalInfo,
      });

      return true;
    } catch (e) {
      debugPrint('Error adding child account: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    try {
      _setLoading(true);
      await _auth.signOut();
      _user = null;
      _userRole = null;
    } catch (e) {
      debugPrint('Error signing out: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Add this method to check authentication status
  Future<bool> isUserAuthenticated() async {
    User? user = _auth.currentUser;

    // If no user is cached, wait a moment to see if auth state resolves
    if (user == null) {
      // Wait for potential auth state to resolve
      await Future.delayed(const Duration(milliseconds: 500));
      user = _auth.currentUser;
    }

    // Force a token refresh if the user exists
    if (user != null) {
      try {
        await user.getIdToken(true);
        return true;
      } catch (e) {
        debugPrint('Error refreshing token: $e');
        return false;
      }
    }

    return false;
  }

  Future<bool> resetPassword(String email) async {
    try {
      _setLoading(true);
      await _auth.sendPasswordResetEmail(email: email);
      _setLoading(false);
      return true;
    } catch (e) {
      _setLoading(false);
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  String? get errorMessage => _errorMessage;
}
