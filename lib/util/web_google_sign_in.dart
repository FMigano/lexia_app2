// This is a stub implementation that matches the GoogleSignIn API structure but uses Firebase directly
// It's only imported on web

// Class to match the mobile GoogleSignIn API
class GoogleSignIn {
  Future<GoogleSignInAccount?> signIn() async {
    // This is a stub - we use a different approach for web in the AuthProvider
    return null;
  }
}

// Stub classes to match mobile API
class GoogleSignInAccount {
  Future<GoogleSignInAuthentication> get authentication async =>
      GoogleSignInAuthentication();
}

class GoogleSignInAuthentication {
  String? get accessToken => null;
  String? get idToken => null;
}
