// GENERATED PLACEHOLDER - replace with flutterfire generated options for dev
// To generate: flutterfire configure --project=<your-dev-project>
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return ios;
      default:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'REPLACEME',
    appId: '1:000000000000:android:REPLACEME',
    messagingSenderId: '000000000000',
    projectId: 'puffpoint-dev',
    storageBucket: 'puffpoint-dev.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REPLACEME',
    appId: '1:000000000000:ios:REPLACEME',
    messagingSenderId: '000000000000',
    projectId: 'puffpoint-dev',
    storageBucket: 'puffpoint-dev.appspot.com',
    iosBundleId: 'com.puffpoint.app',
  );
}
