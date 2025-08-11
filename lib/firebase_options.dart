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

  // Web configuration for new project
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDJVxveEhUSDb6TwWpNDRB8WwJWB95VVdo',
    appId: '1:77421098859:web:NEED_WEB_APP_ID', // You'll need to create a web app
    messagingSenderId: '77421098859',
    projectId: 'gamedevcapz',
    authDomain: 'gamedevcapz.firebaseapp.com',
    storageBucket: 'gamedevcapz.firebasestorage.app',
  );

  // Android configuration with new project values
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDJVxveEhUSDb6TwWpNDRB8WwJWB95VVdo',
    appId: '1:77421098859:android:92122dc5011fb1777bfe2e',
    messagingSenderId: '77421098859',
    projectId: 'gamedevcapz',
    storageBucket: 'gamedevcapz.firebasestorage.app',
  );

  // iOS configuration - you'll need to add iOS app to Firebase
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDJVxveEhUSDb6TwWpNDRB8WwJWB95VVdo',
    appId: '1:77421098859:ios:NEED_IOS_APP_ID', // You'll need to create an iOS app
    messagingSenderId: '77421098859',
    projectId: 'gamedevcapz',
    storageBucket: 'gamedevcapz.firebasestorage.app',
    iosBundleId: 'com.vaultech.lexia',
  );

  // macOS configuration
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDJVxveEhUSDb6TwWpNDRB8WwJWB95VVdo',
    appId: '1:77421098859:ios:NEED_MACOS_APP_ID', // You'll need to create a macOS app
    messagingSenderId: '77421098859',
    projectId: 'gamedevcapz',
    storageBucket: 'gamedevcapz.firebasestorage.app',
    iosBundleId: 'com.vaultech.lexia',
  );
}
