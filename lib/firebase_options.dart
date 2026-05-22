import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    return android;
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyD_gmlLb6VGbuA8m93H6VjunMvbB-6fTHk',
    appId: '1:145848279394:web:cd71be4d80a373cf9cc3b',
    messagingSenderId: '145848279394',
    projectId: 'uvds-c316e',
    storageBucket: 'uvds-c316e.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD_gmlLb6VGbuA8m93H6VjunMvbB-6fTHk',
    appId: '1:145848279394:android:8717ec68d67e2a72f9cc3b',
    messagingSenderId: '145848279394',
    projectId: 'uvds-c316e',
    storageBucket: 'uvds-c316e.firebasestorage.app',
  );
}
