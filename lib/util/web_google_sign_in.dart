// Stub matching google_sign_in 7.x singleton API for web conditional import.
// Not actually used — web uses Firebase auth directly.
class GoogleSignIn {
  GoogleSignIn._();
  static final GoogleSignIn instance = GoogleSignIn._();

  Future<GoogleSignInAccount> authenticate({List<String> scopeHint = const []}) async {
    throw UnsupportedError('Use GoogleAuthProvider with Firebase auth directly on web');
  }

  Future<void> signOut() async {}
}

class GoogleSignInAccount {
  GoogleSignInAuthentication get authentication => GoogleSignInAuthentication(idToken: null);
}

class GoogleSignInAuthentication {
  const GoogleSignInAuthentication({this.idToken});
  final String? idToken;
}
