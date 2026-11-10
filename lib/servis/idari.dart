import 'dart:convert';

import 'package:flutter/services.dart';

/// Türkiye il → ilçe → mahalle/köy listesi (assets/idari.json, PTT posta kodu
/// listesinden). Tapu parsel sorgusundaki gibi sırayla seçim için.
class Idari {
  Idari._();

  static Map<String, Map<String, List<String>>>? _v;

  /// Listeyi bir kez yükler; okunamazsa formlar serbest yazıma döner.
  static Future<void> yukle() async {
    if (_v != null) return;
    try {
      final j = jsonDecode(await rootBundle.loadString('assets/idari.json')) as Map;
      _v = {
        for (final il in j.entries)
          il.key.toString(): {
            for (final ilce in (il.value as Map).entries)
              ilce.key.toString(): [for (final m in ilce.value as List) m.toString()],
          },
      };
    } catch (_) {
      _v = const {};
    }
  }

  static bool get hazir => _v != null && _v!.isNotEmpty;

  static List<String> iller() => _v?.keys.toList() ?? const [];

  static List<String> ilceler(String il) => _v?[il]?.keys.toList() ?? const [];

  static List<String> mahalleler(String il, String ilce) => _v?[il]?[ilce] ?? const [];
}
