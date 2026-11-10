import 'package:flutter/material.dart';

/// Koyu lacivert, oyun ekranı havasında tema: parlak kartlar, renkli
/// kabartma butonlar, üstte sayaç hapları.
class Renk {
  // Açık tema: turkuaz zemin, beyaz kartlar, koyu yazı.
  static const kurumsal = Color(0xFF0E5E58); // koyu petrol yeşili (logo)
  static const zemin = Color(0xFFCBEBE6); // açık turkuaz
  static const zeminAlt = Color(0xFFF1F8F7);
  static const kart = Color(0xFFFFFFFF);
  static const kartAcik = Color(0xFFEEF2F6);
  static const cizgi = Color(0xFFDCE2E8);
  static const yazi = Color(0xFF1A2230);
  static const soluk = Color(0xFF465366);

  // Vurgu renkleri beyaz üstünde okunacak koyulukta.
  static const altin = Color(0xFFB7800C);
  static const yesil = Color(0xFF3E9B35);
  static const yesilKoyu = Color(0xFF2E7A27);
  static const mavi = Color(0xFF3F6FCC);
  static const maviKoyu = Color(0xFF2C55A8);
  static const mor = Color(0xFF6E4FD6);
  static const morKoyu = Color(0xFF5235B5);
  static const kirmizi = Color(0xFFD6453D);
  static const turuncu = Color(0xFFDD7F22);
  static const turkuaz = Color(0xFF1E9C92);
  static const gri = Color(0xFF8A94A6);
}

ThemeData temaOlustur() {
  final cs = const ColorScheme.light().copyWith(
    primary: Renk.mavi,
    onPrimary: Colors.white,
    secondary: Renk.yesil,
    surface: Renk.kart,
    onSurface: Renk.yazi,
    onSurfaceVariant: Renk.soluk,
    outline: Renk.cizgi,
    outlineVariant: Renk.cizgi,
    error: Renk.kirmizi,
    primaryContainer: Renk.kartAcik,
    onPrimaryContainer: Renk.yazi,
    secondaryContainer: Renk.kartAcik,
    onSecondaryContainer: Renk.yazi,
  );
  final kenar = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: Renk.cizgi),
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: cs,
    scaffoldBackgroundColor: Renk.zemin,
    dividerColor: Renk.cizgi,
    dividerTheme: const DividerThemeData(color: Renk.cizgi, space: 1, thickness: 1),
    appBarTheme: const AppBarTheme(
      backgroundColor: Renk.zemin,
      foregroundColor: Renk.yazi,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
          fontSize: 21, fontWeight: FontWeight.w800, color: Renk.yazi),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Renk.zeminAlt,
      labelStyle: const TextStyle(color: Renk.soluk),
      hintStyle: const TextStyle(color: Renk.gri),
      border: kenar,
      enabledBorder: kenar,
      focusedBorder:
          kenar.copyWith(borderSide: const BorderSide(color: Renk.mavi, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Renk.mavi,
        foregroundColor: Colors.white,
        minimumSize: const Size(64, 46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: Renk.altin),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Renk.kart,
      selectedColor: Renk.mavi,
      side: const BorderSide(color: Renk.cizgi),
      labelStyle: const TextStyle(color: Renk.yazi, fontSize: 14),
      secondaryLabelStyle: const TextStyle(
          color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      showCheckmark: false,
    ),
    dialogTheme: const DialogThemeData(backgroundColor: Renk.kart),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Renk.kart),
    popupMenuTheme: const PopupMenuThemeData(color: Renk.kartAcik),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Renk.kartAcik,
      contentTextStyle: const TextStyle(color: Renk.yazi, fontSize: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: Renk.altin),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : Renk.soluk),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Renk.yesil : Renk.kartAcik),
    ),
  );
}

void bildir(BuildContext context, String mesaj) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(mesaj)));
}

const yaziKalin = TextStyle(
    color: Renk.yazi, fontSize: 16, fontWeight: FontWeight.w700);
const yaziSoluk = TextStyle(color: Renk.soluk, fontSize: 13.5);

/// Lacivert, ince kenarlı yuvarlak kart.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    this.baslik,
    required this.child,
    this.eylem,
    this.padding,
    this.margin,
    this.onTap,
    this.kenarRengi,
  });

  final String? baslik;
  final Widget child;
  final Widget? eylem;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? kenarRengi;

  @override
  Widget build(BuildContext context) {
    final ic = Padding(
      padding: padding ?? const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (baslik != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(baslik!,
                      style: const TextStyle(
                          color: Renk.yazi,
                          fontSize: 19,
                          fontWeight: FontWeight.w800)),
                ),
                if (eylem != null) eylem!,
              ],
            ),
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 12),
              height: 2,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [Renk.cizgi, Colors.transparent]),
              ),
            ),
          ],
          child,
        ],
      ),
    );
    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Renk.kart,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kenarRengi ?? Renk.cizgi, width: 1.2),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: onTap == null
          ? ic
          : Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onTap,
                child: ic,
              ),
            ),
    );
  }
}

enum ButonRenk { yesil, mavi, mor, gri, kirmizi, turuncu }

(Color, Color) _butonRenkleri(ButonRenk r) => switch (r) {
      ButonRenk.yesil => (Renk.yesil, Renk.yesilKoyu),
      ButonRenk.mavi => (Renk.mavi, Renk.maviKoyu),
      ButonRenk.mor => (Renk.mor, Renk.morKoyu),
      ButonRenk.gri => (const Color(0xFF8C93A6), const Color(0xFF6A7186)),
      ButonRenk.kirmizi => (Renk.kirmizi, const Color(0xFFB23A33)),
      ButonRenk.turuncu => (Renk.turuncu, const Color(0xFFC0742A)),
    };

/// Altı gölgeli, kabartma oyun butonu.
class Buton extends StatelessWidget {
  const Buton({
    super.key,
    required this.yazi,
    required this.onTap,
    this.renk = ButonRenk.mavi,
    this.ikon,
    this.mesgul = false,
    this.yukseklik = 50,
  });

  final String yazi;
  final VoidCallback? onTap;
  final ButonRenk renk;
  final IconData? ikon;
  final bool mesgul;
  final double yukseklik;

  @override
  Widget build(BuildContext context) {
    final (acik, koyu) = _butonRenkleri(onTap == null ? ButonRenk.gri : renk);
    return Container(
      height: yukseklik,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [acik, koyu],
        ),
        boxShadow: [
          BoxShadow(color: koyu.withValues(alpha: 0.9), offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: mesgul ? null : onTap,
          child: Center(
            child: mesgul
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white))
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (ikon != null) ...[
                        Icon(ikon, color: Colors.white, size: 21),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(yazi,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                shadows: [
                                  Shadow(color: Colors.black38, offset: Offset(0, 1.5))
                                ])),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Üst çubuktaki sayaç hapı: solda emoji, içinde değer.
class SayacHapi extends StatelessWidget {
  const SayacHapi({
    super.key,
    required this.simge,
    required this.deger,
    required this.renk,
    this.etiket,
    this.onTap,
  });

  final String simge;
  final String deger;
  final Color renk;
  final String? etiket;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 84,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
          color: Renk.kart,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: renk, width: 2),
          boxShadow: const [
            BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(simge, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(deger,
                  style: const TextStyle(
                      color: Renk.yazi, fontSize: 17, fontWeight: FontWeight.w900)),
            ),
            if (etiket != null)
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(etiket!.toUpperCase(),
                    maxLines: 1,
                    style: TextStyle(
                        color: renk, fontSize: 11.5, letterSpacing: 0.5, fontWeight: FontWeight.w900)),
              ),
          ],
        ),
      ),
    );
  }
}

class Kare extends StatelessWidget {
  const Kare({
    super.key,
    required this.simge,
    required this.baslik,
    required this.ust,
    required this.renk,
    required this.onTap,
    this.rozet = false,
  });

  final String simge;
  final String baslik;
  final String ust;
  final Color renk;
  final VoidCallback onTap;
  final bool rozet;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: renk.withValues(alpha: 0.7), width: 1.6),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Renk.kart, renk.withValues(alpha: 0.35)],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                child: Column(
                  children: [
                    Text(ust,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Renk.yazi,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    const Divider(height: 8, indent: 10, endIndent: 10),
                    Expanded(
                      child: Center(
                          child: FittedBox(
                              child: Text(simge,
                                  style: const TextStyle(fontSize: 40)))),
                    ),
                    Text(baslik,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Renk.yazi,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (rozet)
          Positioned(
            right: -3,
            top: -3,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: Renk.kirmizi,
                shape: BoxShape.circle,
                border: Border.all(color: Renk.zemin, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

/// Ana sayfadaki büyük işlem kartı: koyu zemin, renkli kenar ve simge.
class BuyukKart extends StatelessWidget {
  const BuyukKart({
    super.key,
    required this.simge,
    required this.baslik,
    required this.renk1,
    required this.renk2,
    required this.onTap,
    this.alt,
    this.rozet,
  });

  final String simge;
  final String baslik;
  final Color renk1, renk2;
  final VoidCallback onTap;
  final String? alt;
  final String? rozet;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 108,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: renk1.withValues(alpha: 0.85), width: 1.6),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [renk1.withValues(alpha: 0.22), Renk.kart],
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(simge, style: const TextStyle(fontSize: 30)),
                        const SizedBox(height: 4),
                        Text(baslik,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Renk.yazi,
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800)),
                        if (alt != null)
                          Text(alt!,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Renk.soluk, fontSize: 12.5)),
                      ],
                    ),
                  ),
                ),
                if (rozet != null)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Renk.kirmizi,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(rozet!,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Küçük renkli etiket ("Hasat edildi", "Münavebeye uygun"...).
class Etiket extends StatelessWidget {
  const Etiket(this.yazi, {super.key, this.renk = Renk.yesil, this.simge});

  final String yazi;
  final Color renk;
  final String? simge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text('${simge == null ? '' : '$simge '}$yazi',
          style: TextStyle(
              color: renk.computeLuminance() > 0.55 ? Renk.yazi : Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700)),
    );
  }
}

/// "Boştaki Araziler / 8" gibi bilgi kutusu.
class BilgiKutu extends StatelessWidget {
  const BilgiKutu({
    super.key,
    required this.baslik,
    required this.deger,
    this.renk,
    this.onTap,
  });

  final String baslik;
  final String deger;
  final Color? renk;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Renk.zeminAlt,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Renk.cizgi, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(baslik,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Renk.soluk, fontSize: 13.5)),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(deger,
                    style: TextStyle(
                        color: renk ?? Renk.yazi,
                        fontSize: 18,
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sol başlık, sağ değer satırı.
class Satir extends StatelessWidget {
  const Satir(this.sol, this.sag, {super.key, this.renk, this.kalin = false});

  final String sol;
  final String sag;
  final Color? renk;
  final bool kalin;

  @override
  Widget build(BuildContext context) {
    final st = TextStyle(
      color: renk ?? Renk.yazi,
      fontSize: kalin ? 16 : 14.5,
      fontWeight: kalin ? FontWeight.w800 : FontWeight.w500,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
              child: Text(sol,
                  style: kalin
                      ? st.copyWith(color: Renk.yazi)
                      : const TextStyle(color: Renk.soluk, fontSize: 14.5))),
          Text(sag, style: st),
        ],
      ),
    );
  }
}

/// Yuvarlak istatistik (profil ekranındaki dörtlü).
class Yuvarlak extends StatelessWidget {
  const Yuvarlak({
    super.key,
    required this.simge,
    required this.deger,
    required this.alt,
    this.renk = Renk.mavi,
  });

  final String simge;
  final String deger;
  final String alt;
  final Color renk;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(colors: [Renk.kartAcik, Renk.zemin]),
            border: Border.all(color: renk, width: 2.5),
          ),
          alignment: Alignment.center,
          child: Text(simge, style: const TextStyle(fontSize: 28)),
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(deger,
              style: TextStyle(
                  color: renk, fontSize: 15, fontWeight: FontWeight.w800)),
        ),
        Text(alt,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Renk.soluk, fontSize: 12)),
      ],
    );
  }
}

/// Boş liste gösterimi.
class BosDurum extends StatelessWidget {
  const BosDurum({
    super.key,
    required this.simge,
    required this.yazi,
    this.butonYazi,
    this.onTap,
  });

  final String simge;
  final String yazi;
  final String? butonYazi;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(simge, style: const TextStyle(fontSize: 52)),
          const SizedBox(height: 10),
          Text(yazi,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Renk.soluk, fontSize: 15)),
          if (butonYazi != null && onTap != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: 240,
              child: Buton(yazi: butonYazi!, onTap: onTap, renk: ButonRenk.yesil),
            ),
          ],
        ],
      ),
    );
  }
}

/// İnce ilerleme çubuğu (sezon ilerlemesi gibi).
class Cubuk extends StatelessWidget {
  const Cubuk({super.key, required this.oran, required this.yazi});

  final double oran;
  final String yazi;

  @override
  Widget build(BuildContext context) {
    final o = oran.isNaN ? 0.0 : oran.clamp(0.0, 1.0).toDouble();
    return Container(
      height: 30,
      decoration: BoxDecoration(
        color: Renk.kartAcik,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Renk.cizgi, width: 2),
      ),
      child: Stack(
        children: [
          FractionallySizedBox(
            widthFactor: o,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                gradient: const LinearGradient(colors: [Renk.mavi, Color(0xFF7FA6F0)]),
              ),
            ),
          ),
          Center(
            child: Text(yazi,
                style: const TextStyle(
                    color: Renk.yazi,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

/// Seçim çipleri satırı (Hepsi / Ben / Babam...).
class SecimSatiri extends StatelessWidget {
  const SecimSatiri({
    super.key,
    required this.secenekler,
    required this.secili,
    required this.onSec,
    this.etiket,
  });

  final List<String> secenekler;
  final String secili;
  final ValueChanged<String> onSec;

  /// Seçenekler ekrana sığmazsa açılır listenin başlığı.
  final String? etiket;

  @override
  Widget build(BuildContext context) {
    // Az ve kısa seçenek: yan yana düğmeler. Sığmayacaksa yana kaydırma
    // yerine tek açılır liste (karışık görünmesin).
    final uzunluk = secenekler.fold(0, (a, s) => a + s.length + 4);
    if (secenekler.length > 4 || uzunluk > 34) {
      final s = secenekler.contains(secili) ? secili : (secenekler.isEmpty ? null : secenekler.first);
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: DropdownButtonFormField<String>(
          key: ValueKey('secim:${etiket ?? ''}:$s'),
          initialValue: s,
          isExpanded: true,
          dropdownColor: Renk.kartAcik,
          decoration: InputDecoration(labelText: etiket ?? 'Göster'),
          items: [for (final x in secenekler) DropdownMenuItem(value: x, child: Text(x))],
          onChanged: (x) {
            if (x != null) onSec(x);
          },
        ),
      );
    }
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final s in secenekler)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(s),
                selected: s == secili,
                onSelected: (_) => onSec(s),
              ),
            ),
        ],
      ),
    );
  }
}

/// Liste halinde menü satırı: simge, başlık, kısa bilgi, sağda ok.
class MenuOge {
  const MenuOge(this.simge, this.baslik, this.alt, this.onTap, {this.rozet, this.renk});
  final String simge, baslik, alt;
  final VoidCallback onTap;

  /// Kare menüde kartın rengi.
  final Color? renk;

  /// Kırmızı küçük uyarı yazısı (ör. "Gecikmiş", "Maaş").
  final String? rozet;
}

/// Alt alta menü satırları; isteğe bağlı başlıklı panel içinde.
class ListeMenu extends StatelessWidget {
  const ListeMenu({super.key, required this.ogeler, this.baslik});
  final List<MenuOge> ogeler;
  final String? baslik;

  @override
  Widget build(BuildContext context) {
    return Panel(
      baslik: baslik,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < ogeler.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: Text(ogeler[i].simge, style: const TextStyle(fontSize: 26)),
              title: Text(ogeler[i].baslik, style: yaziKalin),
              subtitle: Text(ogeler[i].alt, style: yaziSoluk),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (ogeler[i].rozet != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: Renk.kirmizi, borderRadius: BorderRadius.circular(10)),
                      child: Text(ogeler[i].rozet!,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  const Icon(Icons.chevron_right, color: Renk.soluk),
                ],
              ),
              onTap: ogeler[i].onTap,
            ),
          ],
        ],
      ),
    );
  }
}

/// Kişi seçimi: yana kayan düğmeler yerine tek açılır liste.
class KisiSecici extends StatelessWidget {
  const KisiSecici(
      {super.key, required this.kisiler, required this.secili, required this.onSec});
  final List<String> kisiler;
  final String secili;
  final ValueChanged<String> onSec;

  @override
  Widget build(BuildContext context) {
    if (kisiler.length <= 2) return const SizedBox.shrink();
    final s = kisiler.contains(secili) ? secili : kisiler.first;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        key: ValueKey('kisi:$s'),
        initialValue: s,
        isExpanded: true,
        dropdownColor: Renk.kartAcik,
        decoration: const InputDecoration(labelText: 'Kişi'),
        items: [for (final k in kisiler) DropdownMenuItem(value: k, child: Text(k))],
        onChanged: (k) => onSec(k ?? kisiler.first),
      ),
    );
  }
}

/// Başlıklı bölüm + üçlü kare menü: her kare kendi renginde, simge, ad,
/// kısa bilgi ve gerekirse köşede kırmızı uyarı.
class KareMenu extends StatelessWidget {
  const KareMenu({super.key, required this.baslik, required this.ogeler});
  final String baslik;
  final List<MenuOge> ogeler;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(baslik.toUpperCase(),
                style: const TextStyle(
                    color: Renk.soluk,
                    fontSize: 12.5,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w800)),
          ),
          LayoutBuilder(builder: (context, c) {
            const ara = 10.0;
            final w = (c.maxWidth - ara * 2) / 3;
            return Wrap(
              spacing: ara,
              runSpacing: ara,
              children: [for (final o in ogeler) SizedBox(width: w, height: w * 1.12, child: _kare(o))],
            );
          }),
        ],
      ),
    );
  }

  Widget _kare(MenuOge o) {
    final r = o.renk ?? Renk.mavi;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: o.onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [r, Color.lerp(r, Colors.black, 0.28)!],
            ),
            boxShadow: [
              BoxShadow(color: r.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 3)),
            ],
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Text(o.simge, style: const TextStyle(fontSize: 24)),
                    ),
                    const Spacer(),
                    Text(o.baslik,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            height: 1.15,
                            fontWeight: FontWeight.w900,
                            shadows: [Shadow(color: Color(0x55000000), offset: Offset(0, 1), blurRadius: 2)])),
                    const SizedBox(height: 3),
                    Text(o.alt,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Color(0xF2FFFFFF), fontSize: 12, height: 1.2, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              if (o.rozet != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 70),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: Renk.kirmizi,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 1.5)),
                    child: Text(o.rozet!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
