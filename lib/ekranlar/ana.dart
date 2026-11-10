import 'package:flutter/material.dart';

import '../bicim.dart';
import '../hesap.dart';
import '../servis/veri.dart';
import '../tema.dart';
import 'aile.dart';
import 'arge.dart';
import 'belge_okut.dart';
import 'depo.dart';
import 'ekisler.dart';
import 'hesaplar.dart';
import 'isler.dart';
import 'kabuk.dart';
import 'pancar.dart';
import 'piyasa.dart';
import 'satislar.dart';
import 'tarlalar.dart';
import 'uretim.dart';
import 'defter.dart';
import 'ekipman.dart';
import 'finans.dart';
import 'varliklar.dart';

/// Üst sayaç çubuğu: bu yıl kâr, alacak, borç, depo değeri.
class UstSayaclar extends StatelessWidget {
  const UstSayaclar({super.key, required this.durum, required this.v});
  final Durum durum;
  final Veriler v;

  @override
  Widget build(BuildContext context) {
    final yil = DateTime.now().year;
    final o = v.yilOzet(yil);
    final depo = v.depo().fold(0.0, (a, d) => a + d.deger);
    return Row(
      children: [
        Expanded(
          child: SayacHapi(
            simge: '🌾',
            deger: kisaTl(o.tarimKar),
            etiket: '$yil KÂR',
            renk: Renk.altin,
            onTap: () => git(context, UretimSayfasi(durum: durum)),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: SayacHapi(
            simge: '📥',
            deger: kisaTl(v.toplamAlacak()),
            etiket: 'ALACAK',
            renk: Renk.mor,
            onTap: () => git(context, HesaplarSayfasi(durum: durum, yon: 'alacak')),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: SayacHapi(
            simge: '📤',
            deger: kisaTl(v.toplamBorc()),
            etiket: 'BORÇ',
            renk: Renk.kirmizi,
            onTap: () => git(context, HesaplarSayfasi(durum: durum, yon: 'borc')),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: SayacHapi(
            simge: '🏪',
            deger: kisaTl(depo),
            etiket: 'DEPO',
            renk: Renk.yesil,
            onTap: () => git(context, DepoSayfasi(durum: durum)),
          ),
        ),
      ],
    );
  }
}

class AnaSayfa extends StatelessWidget {
  const AnaSayfa({super.key, required this.durum});
  final Durum durum;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Canli(
          durum: durum,
          builder: (context, v) {
            if (!durum.yuklendi) {
              return const Center(child: CircularProgressIndicator());
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              children: [
                _baslik(context),
                const SizedBox(height: 10),
                UstSayaclar(durum: durum, v: v),
                const SizedBox(height: 12),
                _profilKarti(context, v),
                _odemeler(context, v),
                ..._menuler(context, v),
                if (durum.hata != null)
                  Panel(
                    kenarRengi: Renk.kirmizi,
                    child: Text(
                      'Bazı veriler okunamadı: ${hataYazisi(durum.hata!)}',
                      style: const TextStyle(color: Renk.kirmizi),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _baslik(BuildContext context) {
    return Row(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => git(context, BelgeOkut(durum: durum)),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Renk.kart,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Renk.yesil, width: 1.6),
            ),
            alignment: Alignment.center,
            child: const Text('📷', style: TextStyle(fontSize: 24)),
          ),
        ),
        const Spacer(),
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('BEREKET',
                style: TextStyle(
                    color: Renk.kurumsal,
                    fontSize: 28,
                    letterSpacing: 6,
                    fontWeight: FontWeight.w900)),
            Text('TARIM · FİNANS · AİLE',
                style: TextStyle(
                    color: Renk.soluk,
                    fontSize: 10.5,
                    letterSpacing: 2.5,
                    fontWeight: FontWeight.w700)),
          ],
        ),
        const Spacer(),
        const SizedBox(
          width: 48,
          height: 48,
          child: Center(child: Text('🚜', style: TextStyle(fontSize: 30))),
        ),
      ],
    );
  }

  /// İşletme kartı; altında cebimdeki para ve bu ayın gelir-gideri.
  Widget _profilKarti(BuildContext context, Veriler v) {
    final i = durum.isletme!;
    final simdi = DateTime.now();
    final cep = v.cebimdeki();
    final ay = v.ayOzeti(simdi.year, simdi.month);
    final fark = ay.gelir - ay.gider;
    final girilmedi = !v.varliklar.any((x) => x.s('tur') == 'Nakit' || x.s('tur') == 'Mevduat');
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text('👨‍🌾', style: TextStyle(fontSize: 34)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(i.ad, maxLines: 1, overflow: TextOverflow.ellipsis, style: yaziKalin),
                    Text(
                        '${durum.isim(durum.uid)} · ${durum.yonetici ? 'Sahip' : 'Üye'} · '
                        '${v.tarlalar.length} parsel, ${sayi(v.toplamDekar)} da',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: yaziSoluk),
                  ],
                ),
              ),
            ],
          ),
          ...[
          const Divider(height: 22),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => git(context, VarliklarSayfasi(durum: durum)),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('👛  CEBİMDEKİ PARA',
                          style: TextStyle(
                              color: Renk.soluk,
                              fontSize: 13,
                              letterSpacing: 1.1,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(girilmedi ? 'Nakit / banka gir' : tl0(cep),
                          style: TextStyle(
                              color: girilmedi ? Renk.soluk : Renk.kurumsal,
                              fontSize: girilmedi ? 18 : 30,
                              fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Renk.soluk),
              ],
            ),
          ),
          if (girilmedi)
            const Text('Varlıklarım\'a elindeki parayı "Nakit", bankadakini "Mevduat" olarak yaz.',
                style: yaziSoluk),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: BilgiKutu(
                      baslik: '${ayAdi(simdi.month)} gelir', deger: tl0(ay.gelir), renk: Renk.yesil)),
              const SizedBox(width: 8),
              Expanded(
                  child: BilgiKutu(
                      baslik: '${ayAdi(simdi.month)} gider', deger: tl0(ay.gider), renk: Renk.kirmizi)),
            ],
          ),
          const SizedBox(height: 6),
          Text(fark >= 0 ? 'Bu ay ${tl0(fark)} artıdasın.' : 'Bu ay ${tl0(-fark)} eksidesin.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: fark >= 0 ? Renk.yesilKoyu : Renk.kirmizi, fontWeight: FontWeight.w800)),
          ],
        ],
      ),
    );
  }

  /// Ödemelerim: vadesi geçmiş, bugün ve yaklaşan (15 gün) borç ödemeleri.
  Widget _odemeler(BuildContext context, Veriler v) {
    final l = v.odemeTakvimi(DateTime.now());
    final gecikmis = l.where((o) => o.kalanGun < 0).toList();
    final bugun = l.where((o) => o.kalanGun == 0).toList();
    final yaklasan = l.where((o) => o.kalanGun > 0).toList();
    Widget satir(OdemeGunu o) {
      final (yazi, renk) = o.kalanGun < 0
          ? ('${-o.kalanGun} gün gecikti', Renk.kirmizi)
          : o.kalanGun == 0
              ? ('Bugün', Renk.turuncu)
              : ('${o.kalanGun} gün kaldı', Renk.mavi);
      return InkWell(
        onTap: () => git(context, HesapDetay(durum: durum, hesapId: o.hesap.id)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            children: [
              Container(width: 4, height: 34, color: renk),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(o.hesap.s('ad'), maxLines: 1, overflow: TextOverflow.ellipsis, style: yaziKalin),
                    Text('${tarih(o.tarih.millisecondsSinceEpoch)} · $yazi',
                        style: TextStyle(color: renk, fontSize: 13, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              Text(tl0(o.tutar),
                  style: const TextStyle(color: Renk.yazi, fontSize: 16, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      );
    }

    Widget grup(String baslik, List<OdemeGunu> x) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 2),
              child: Text(baslik,
                  style: const TextStyle(
                      color: Renk.soluk, fontSize: 12.5, letterSpacing: 1, fontWeight: FontWeight.w800)),
            ),
            for (final o in x) satir(o),
          ],
        );
    return Panel(
      baslik: '📅 Ödemelerim',
      kenarRengi: gecikmis.isNotEmpty ? Renk.kirmizi : (bugun.isNotEmpty ? Renk.turuncu : null),
      eylem: TextButton(
        onPressed: () => git(context, HesaplarSayfasi(durum: durum, yon: 'borc')),
        child: const Text('Tümü'),
      ),
      child: l.isEmpty
          ? const Text('Önümüzdeki 15 günde ödeme yok. Borçlarım\'da vade ya da ödeme günü '
              'girilen borçlar burada görünür.',
              style: yaziSoluk)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (gecikmis.isNotEmpty) grup('GECİKMİŞ', gecikmis),
                if (bugun.isNotEmpty) grup('BUGÜN', bugun),
                if (yaklasan.isNotEmpty) grup('YAKLAŞAN (15 GÜN)', yaklasan.take(6).toList()),
              ],
            ),
    );
  }

  List<Widget> _menuler(BuildContext context, Veriler v) {
    final yil = DateTime.now().year;
    final simdi = DateTime.now();
    final depoTon = v.depo().fold(0.0, (a, d) => a + d.kalan) / 1000;
    final bekleyen = v.satislar.where((s) => v.satisHesap(s).kalan(tahsilToplam(s)) > 1).length;
    final borcSayisi = v.hesaplar.where((h) => h.s('yon') != 'alacak' && v.bakiye(h) > 0).length;
    final alacakSayisi = v.hesaplar.where((h) => h.s('yon') == 'alacak' && v.bakiye(h) > 0).length;
    final gecikme = v.gecikmisBorc(simdi.millisecondsSinceEpoch) > 0;
    final maasBekleyen = v.isyerleri.any((i) => v.maasDurum(i, simdi) != MaasDurum.yatti);
    final acikIs = v.isler.where((x) => !x.b('tamam')).length;
    final odemeler = v.hesaplasmaOnerisi();
    final evHedef = v.evHedefi(simdi);
    void ac(Widget w) => git(context, w);
    return [
      KareMenu(baslik: 'Tarla ve Üretim', ogeler: [
        MenuOge('🗺️', 'Tarlalarım', '${v.tarlalar.length} parsel · ${sayi(v.toplamDekar)} da',
            () => ac(TarlalarSayfasi(durum: durum)), renk: const Color(0xFF2E9E5B)),
        MenuOge('🌱', 'Üretim Merkezi',
            '$yil: ${v.ekimler.where((e) => e.t('yil') == yil).length} ekim',
            () => ac(UretimSayfasi(durum: durum)), renk: const Color(0xFF6BAA2E)),
        MenuOge('💰', 'Satışlarım', '$yil: ${v.satislar.where((s) => s.yil == yil).length} satış',
            () => ac(SatislarSayfasi(durum: durum)),
            rozet: bekleyen > 0 ? '$bekleyen bekliyor' : null, renk: const Color(0xFFC9932E)),
        MenuOge('🏭', 'Depo', '${sayi(depoTon)} ton ürün', () => ac(DepoSayfasi(durum: durum)),
            renk: const Color(0xFF2BB3A8)),
        MenuOge('🟣', 'Pancar & Koop.', 'Kota · fabrika',
            () => ac(PancarSayfasi(durum: durum)), renk: const Color(0xFF8E5BE8)),
        MenuOge('📈', 'Piyasa', 'Borsa · TMO fiyatları',
            () => ac(PiyasaSayfasi(durum: durum)), renk: const Color(0xFF3B6FD0)),
      ]),
      KareMenu(baslik: 'Para', ogeler: [
        if (!durum.sinirli)
        MenuOge('👨‍👩‍👦', 'Aile Hesapları',
            odemeler.isEmpty ? 'Hesaplar denk' : '${odemeler.length} ödeme var',
            () => ac(AileSayfasi(durum: durum)), renk: const Color(0xFF2E8B57)),
        MenuOge('📤', 'Borçlarım', '$borcSayisi açık hesap',
            () => ac(HesaplarSayfasi(durum: durum, yon: 'borc')),
            rozet: gecikme ? 'Gecikmiş' : null, renk: const Color(0xFFD9534F)),
        MenuOge('📥', 'Alacaklarım', '$alacakSayisi açık hesap',
            () => ac(HesaplarSayfasi(durum: durum, yon: 'alacak')), renk: const Color(0xFF9B6BE0)),
        MenuOge('📒', 'Gelir - Gider', 'Tüm hareketler',
            () => ac(DefterSayfasi(durum: durum)), renk: const Color(0xFF4F6B8F)),
        MenuOge('💼', 'Ek İşler', 'Maaş · destekler',
            () => ac(EkIslerSayfasi(durum: durum)),
            rozet: maasBekleyen ? 'Maaş' : null, renk: const Color(0xFF3B8FD0)),
        MenuOge('🏦', 'Finans', 'Kredi · sat/beklet',
            () => ac(FinansSayfasi(durum: durum, geri: true)), renk: const Color(0xFFB8862B)),
      ]),
      KareMenu(baslik: 'Diğer', ogeler: [
        MenuOge('📋', 'Görevler', acikIs == 0 ? 'Görev yok' : '$acikIs açık görev',
            () => ac(IslerSayfasi(durum: durum)), renk: const Color(0xFFE08A3C)),
        MenuOge('🪙', 'Varlıklarım', 'Birikim · ev bütçesi',
            () => ac(VarliklarSayfasi(durum: durum)), renk: const Color(0xFFC9A227)),
        if (!durum.sinirli)
        MenuOge('🏡', 'Ev Alma Hedefi',
            evHedef == null ? 'Hedef belirle' : 'Bu ay ${tl0(evHedef.aylik)}',
            () => ac(EvHedefiSayfasi(durum: durum)), renk: const Color(0xFFD9775A)),
        MenuOge('🧰', 'Malzemelerim', 'Traktör · sulama',
            () => ac(EkipmanSayfasi(durum: durum)), renk: const Color(0xFF8A7650)),
        MenuOge('🔬', 'Ar-Ge', 'Verim · girdi fiyatı',
            () => ac(ArgeSayfasi(durum: durum)), renk: const Color(0xFF5A6E99)),
      ]),
    ];
  }
}
