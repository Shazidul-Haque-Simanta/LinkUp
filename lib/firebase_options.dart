import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyB6O7gSu2AfyxJuxrBFjc_Pdpqw3gflAz8',
    appId: '1:1014569507613:web:b35b4882455f0dd23c1ff4',
    messagingSenderId: '1014569507613',
    projectId: 'linkup-academic-app',
    authDomain: 'linkup-academic-app.firebaseapp.com',
    databaseURL: 'https://linkup-academic-app-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'linkup-academic-app.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB6O7gSu2AfyxJuxrBFjc_Pdpqw3gflAz8', // Sharing same API Key for simplicity if not available in JSON
    appId: '1:1014569507613:android:9d4f6a7d9b8c7e6f5a4b3c', // Placeholder, usually from google-services.json
    messagingSenderId: '1014569507613',
    projectId: 'linkup-academic-app',
    databaseURL: 'https://linkup-academic-app-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'linkup-academic-app.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyB6O7gSu2AfyxJuxrBFjc_Pdpqw3gflAz8',
    appId: '1:1014569507613:ios:8c7d6f5e4d3c2b1a0f9e8d', // Placeholder
    messagingSenderId: '1014569507613',
    projectId: 'linkup-academic-app',
    databaseURL: 'https://linkup-academic-app-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'linkup-academic-app.firebasestorage.app',
    iosBundleId: 'com.example.projectV2',
  );
}
