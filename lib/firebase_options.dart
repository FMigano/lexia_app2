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
        return windows;
      case TargetPlatform.linux:
        return linux;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // Web configuration for the current Firebase project.
  // NOTE: Get web app ID from Firebase Console > Project Settings > General > Your apps
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDFRa1b0P64Dwf3bzByu1ygKh4FBUx-k40',
    appId: '1:635282071283:web:YOUR_WEB_APP_ID',  // TODO: Replace with actual Web App ID
    messagingSenderId: '635282071283',
    projectId: 'lexiadyslexia',
    authDomain: 'lexiadyslexia.firebaseapp.com',
    storageBucket: 'lexiadyslexia.firebasestorage.app',
  );

  // Android configuration (from google-services.json).
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDFRa1b0P64Dwf3bzByu1ygKh4FBUx-k40',
    appId: '1:635282071283:android:4efe845d654c739f3c2186',
    messagingSenderId: '635282071283',
    projectId: 'lexiadyslexia',
    storageBucket: 'lexiadyslexia.firebasestorage.app',
  );

  // iOS configuration.
  // NOTE: Get iOS app ID from Firebase Console > Project Settings > General > Your apps
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDFRa1b0P64Dwf3bzByu1ygKh4FBUx-k40',
    appId: '1:635282071283:ios:YOUR_IOS_APP_ID',  // TODO: Replace with actual iOS App ID
    messagingSenderId: '635282071283',
    projectId: 'lexiadyslexia',
    storageBucket: 'lexiadyslexia.firebasestorage.app',
    iosBundleId: 'com.vaulttech.lexiadyslexia',
  );

  // macOS configuration.
  // NOTE: Get macOS app ID from Firebase Console > Project Settings > General > Your apps
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDFRa1b0P64Dwf3bzByu1ygKh4FBUx-k40',
    appId: '1:635282071283:ios:YOUR_MACOS_APP_ID',  // TODO: Replace with actual macOS App ID
    messagingSenderId: '635282071283',
    projectId: 'lexiadyslexia',
    storageBucket: 'lexiadyslexia.firebasestorage.app',
    iosBundleId: 'com.vaulttech.lexiadyslexia',
  );

  // Windows configuration.
  // NOTE: Register a Windows app in the Firebase Console first, then fill in the app ID.
  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDFRa1b0P64Dwf3bzByu1ygKh4FBUx-k40',
    appId: '1:635282071283:windows:YOUR_WINDOWS_APP_ID',  // TODO: Register Windows app in Firebase Console
    messagingSenderId: '635282071283',
    projectId: 'lexiadyslexia',
    storageBucket: 'lexiadyslexia.firebasestorage.app',
  );

  // Linux configuration.
  // NOTE: Register a Linux app in the Firebase Console first, then fill in the app ID.
  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'AIzaSyDFRa1b0P64Dwf3bzByu1ygKh4FBUx-k40',
    appId: '1:635282071283:linux:YOUR_LINUX_APP_ID',  // TODO: Register Linux app in Firebase Console
    messagingSenderId: '635282071283',
    projectId: 'lexiadyslexia',
    storageBucket: 'lexiadyslexia.firebasestorage.app',
  );
}
