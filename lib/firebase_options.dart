// Generated file. Do not edit.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // Web configuration for the current Firebase project.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDFRa1b0P64Dwf3bzByu1ygKh4FBUx-k40',
    appId: '1:635282071283:web:NEED_WEB_APP_ID',
    messagingSenderId: '635282071283',
    projectId: 'lexiadyslexia',
    authDomain: 'lexiadyslexia.firebaseapp.com',
    storageBucket: 'lexiadyslexia.firebasestorage.app',
  );

  // Android configuration.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDFRa1b0P64Dwf3bzByu1ygKh4FBUx-k40',
    appId: '1:635282071283:android:9fcc467cd7d768523c2186',
    messagingSenderId: '635282071283',
    projectId: 'lexiadyslexia',
    storageBucket: 'lexiadyslexia.firebasestorage.app',
  );

  // iOS configuration.
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDFRa1b0P64Dwf3bzByu1ygKh4FBUx-k40',
    appId: '1:635282071283:ios:NEED_IOS_APP_ID',
    messagingSenderId: '635282071283',
    projectId: 'lexiadyslexia',
    storageBucket: 'lexiadyslexia.firebasestorage.app',
    iosBundleId: 'com.vaulttech.lexiadyslexia',
  );

  // macOS configuration.
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDFRa1b0P64Dwf3bzByu1ygKh4FBUx-k40',
    appId: '1:635282071283:ios:NEED_MACOS_APP_ID',
    messagingSenderId: '635282071283',
    projectId: 'lexiadyslexia',
    storageBucket: 'lexiadyslexia.firebasestorage.app',
    iosBundleId: 'com.vaulttech.lexiadyslexia',
  );
}
