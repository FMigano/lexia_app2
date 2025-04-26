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

  // Web configuration with values from your project
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBoVgYeTEpEkqrH0OA_UMbl1oZLvTuWMA0',
    appId:
        '1:746497205021:web:c30258fe80a8deb922b7f4', // Web app ID might be different
    messagingSenderId: '746497205021',
    projectId: 'teamlexia-46228',
    authDomain: 'teamlexia-46228.firebaseapp.com',
    storageBucket: 'teamlexia-46228.firebasestorage.app',
    databaseURL:
        'https://teamlexia-46228-default-rtdb.asia-southeast1.firebasedatabase.app',
  );

  // Android configuration with values from your google-services.json
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBoVgYeTEpEkqrH0OA_UMbl1oZLvTuWMA0',
    appId: '1:746497205021:android:c30258fe80a8deb922b7f4',
    messagingSenderId: '746497205021',
    projectId: 'teamlexia-46228',
    storageBucket: 'teamlexia-46228.firebasestorage.app',
    databaseURL:
        'https://teamlexia-46228-default-rtdb.asia-southeast1.firebasedatabase.app',
  );

  // iOS configuration - using similar values but might need adjustment with actual iOS config
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey:
        'AIzaSyD3JBZLHUinaVr3aIsJ6B7K4v9lmUeV5rY', // Using the second API key from the file
    appId:
        '1:746497205021:ios:c30258fe80a8deb922b7f4', // This needs actual iOS app ID
    messagingSenderId: '746497205021',
    projectId: 'teamlexia-46228',
    storageBucket: 'teamlexia-46228.firebasestorage.app',
    iosBundleId: 'com.vaultech.lexia',
    databaseURL:
        'https://teamlexia-46228-default-rtdb.asia-southeast1.firebasedatabase.app',
  );

  // macOS configuration
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyD3JBZLHUinaVr3aIsJ6B7K4v9lmUeV5rY',
    appId:
        '1:746497205021:ios:c30258fe80a8deb922b7f4', // This needs actual macOS app ID
    messagingSenderId: '746497205021',
    projectId: 'teamlexia-46228',
    storageBucket: 'teamlexia-46228.firebasestorage.app',
    iosBundleId: 'com.vaultech.lexia',
    databaseURL:
        'https://teamlexia-46228-default-rtdb.asia-southeast1.firebasedatabase.app',
  );
}
