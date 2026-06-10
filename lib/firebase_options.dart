import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase options — مُولَّدة من google-services.json و GoogleService-Info.plist
class DefaultFirebaseOptions {
  static const String _placeholder = 'REPLACE_ME';

  static bool get isConfigured {
    if (kIsWeb) return false;
    return currentPlatform.projectId != _placeholder &&
        currentPlatform.apiKey != _placeholder &&
        currentPlatform.appId != _placeholder;
  }

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web push is not configured for this app.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD343P0c3e8yTFfbapgDYKjwjnrSsf7DE8',
    appId: '1:1058536503582:android:1dc4319eda01ddd6def10f',
    messagingSenderId: '1058536503582',
    projectId: 'algaithapp',
    storageBucket: 'algaithapp.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBADwgcdPVuQDdbFvpOh7UWo6kt7ie0Jeg',
    appId: '1:1058536503582:ios:7115ca6956a8f276def10f',
    messagingSenderId: '1058536503582',
    projectId: 'algaithapp',
    storageBucket: 'algaithapp.firebasestorage.app',
    iosBundleId: 'com.alghaith.app',
  );
}
