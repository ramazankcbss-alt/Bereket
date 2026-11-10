import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';

/// Keleş Satış'taki satışları okur. Keleş Satış kendi Firebase projesindedir
/// (keles-satis); Bereket ona ikinci bir Firebase uygulaması olarak bağlanır
/// ve Keleş Satış hesabıyla giriş yapar. Bereket bu verileri yalnızca okur.
class KelesSiparis {
  const KelesSiparis({
    required this.id,
    required this.no,
    required this.musteri,
    required this.urun,
    required this.miktar,
    required this.birim,
    required this.fiyat,
    required this.tahsil,
    required this.teslim,
    required this.tarih,
  });

  final String id;
  final int no;
  final String musteri, urun, birim;
  final double miktar, fiyat, tahsil;
  final bool teslim;
  final int tarih;

  double get tutar => miktar * fiyat;

  /// Miktar kg cinsinden (ton yazıldıysa çevrilir).
  double get kg {
    final b = birim.toLowerCase();
    if (b.startsWith('ton')) return miktar * 1000;
    return miktar;
  }

  /// Kg başı fiyat.
  double get kgFiyat {
    final b = birim.toLowerCase();
    if (b.startsWith('ton')) return fiyat / 1000;
    return fiyat;
  }
}

/// Keleş Satış'a giriş yapılmamışsa fırlatılır; ekran giriş penceresi açar.
class KelesGirisGerekli implements Exception {
  const KelesGirisGerekli();
  @override
  String toString() =>
      'Keleş Satış siparişlerini görmek için Keleş Satış e-posta ve şifrenizle bir kez giriş yapın.';
}

class Keles {
  Keles._();

  static FirebaseApp? _app;

  static Future<FirebaseApp> _uygulama() async {
    if (_app != null) return _app!;
    try {
      _app = Firebase.app('keles');
    } catch (_) {
      _app = await Firebase.initializeApp(name: 'keles', options: DefaultFirebaseOptions.keles);
    }
    return _app!;
  }

  static Future<FirebaseAuth> _auth() async => FirebaseAuth.instanceFor(app: await _uygulama());
  static Future<FirebaseFirestore> _db() async =>
      FirebaseFirestore.instanceFor(app: await _uygulama());

  /// Keleş Satış hesabına giriş.
  static Future<void> girisYap(String eposta, String sifre) async {
    await (await _auth()).signInWithEmailAndPassword(email: eposta.trim(), password: sifre);
  }

  /// Bereket'e girerken aynı e-posta ve şifreyle Keleş Satış'a da girmeyi dener;
  /// olmazsa sessizce geçer.
  static Future<void> sessizGiris(String eposta, String sifre) async {
    try {
      await girisYap(eposta, sifre);
    } catch (_) {}
  }

  static Future<void> cikis() async {
    try {
      await (await _auth()).signOut();
    } catch (_) {}
  }

  /// Kullanıcının Keleş Satış'taki firma kimliği; yoksa boş.
  static Future<String> firmaId(String uid) async {
    final d = await (await _db()).collection('satis_kullanicilar').doc(uid).get();
    return (d.data()?['firmaId'] as String?) ?? '';
  }

  /// [uid] eski sürümle uyum için duruyor; Keleş Satış'taki oturum kullanılır.
  static Future<List<KelesSiparis>> siparisler(String uid) async {
    final kullanici = (await _auth()).currentUser;
    if (kullanici == null) throw const KelesGirisGerekli();
    final fid = await firmaId(kullanici.uid);
    if (fid.isEmpty) {
      throw 'Bu hesap Keleş Satış\'ta bir firmaya bağlı değil. '
          'Keleş Satış\'a hangi e-postayla giriyorsanız onunla giriş yapın.';
    }
    final s = await (await _db())
        .collection('satis_firmalar')
        .doc(fid)
        .collection('siparisler')
        .orderBy('olusturma', descending: true)
        .limit(500)
        .get();
    double n(Object? v) => v is num ? v.toDouble() : 0;
    return [
      for (final d in s.docs)
        KelesSiparis(
          id: d.id,
          no: (d.data()['no'] as num?)?.toInt() ?? 0,
          musteri: (d.data()['musteri'] ?? '').toString(),
          urun: (d.data()['urun'] ?? '').toString(),
          miktar: n(d.data()['miktar']),
          birim: (d.data()['birim'] ?? 'kg').toString(),
          fiyat: n(d.data()['fiyat']),
          tahsil: (d.data()['tahsilatlar'] is List)
              ? (d.data()['tahsilatlar'] as List)
                  .fold(0.0, (a, t) => a + (t is Map ? n(t['tutar']) : 0.0))
              : 0.0,
          teslim: d.data()['teslim'] == true,
          tarih: (d.data()['olusturma'] as num?)?.toInt() ?? 0,
        )
    ];
  }
}
