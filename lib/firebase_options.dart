// Firebase proje ayarları.
// Bereket kendi projesini (bereket-86ea7) kullanır; Keleş Satış siparişleri
// keles-satis projesinden yalnızca okunur.
// Bu bilgiler gizli değildir; erişim güvenliği firestore.rules ile sağlanır.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (defaultTargetPlatform == TargetPlatform.android) return android;
    throw UnsupportedError('Bu uygulama yalnızca Android için yapılandırıldı.');
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAyMQhaOUdPV1fYnKTErO8--uDRZo9JAMw',
    appId: '1:569687039310:android:6c2feb3c94a28c60dd121f',
    messagingSenderId: '569687039310',
    projectId: 'bereket-86ea7',
    storageBucket: 'bereket-86ea7.firebasestorage.app',
  );

  /// Keleş Satış projesi (siparişleri okumak için ikinci Firebase uygulaması).
  static const FirebaseOptions keles = FirebaseOptions(
    apiKey: 'AIzaSyB1rCK_lUftziSDt7zFTQ6P3ttXrkHJ1ZY',
    appId: '1:23261241650:android:1939b0cc94e89feaeb372b',
    messagingSenderId: '23261241650',
    projectId: 'keles-satis',
    storageBucket: 'keles-satis.firebasestorage.app',
  );
}
