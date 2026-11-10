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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: const LinearGradient(colors: [Renk.yesil, Renk.yesilKoyu]),
            border: Border.all(color: Renk.altin, width: 2.5),
          ),
          child: const Text('BEREKET',
              style: TextStyle(
                  color: Renk.altin,
                  fontSize: 26,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w900,
                  shadows: [Shadow(color: Colors.black54, offset: Offset(0, 2))])),
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

  Widget _profilKarti(BuildContext context, Veriler v) {
    final i = durum.isletme!;
    final yil = DateTime.now().year;
    final buYil = v.ekimler.where((e) => e.t('yil') == yil && Veriler.ekili(e)).toList();
    final ekili = buYil.fold(0.0, (a, e) => a + v.ekimDekar(e));
    final hasat = buYil
        .where((e) => e.s('durum') == 'Hasat edildi')
        .fold(0.0, (a, e) => a + v.ekimDekar(e));
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
          const SizedBox(height: 10),
          Cubuk(
            oran: ekili > 0 ? hasat / ekili : 0,
            yazi: ekili <= 0
                ? '$yil için henüz ekim girilmedi'
                : '$yil hasat: ${sayi(hasat)} / ${sayi(ekili)} da',
          ),
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
      ListeMenu(baslik: 'Tarla ve Üretim', ogeler: [
        MenuOge('🗺️', 'Tarlalarım', '${v.tarlalar.length} parsel · ${sayi(v.toplamDekar)} da',
            () => ac(TarlalarSayfasi(durum: durum))),
        MenuOge('🌱', 'Üretim Merkezi',
            '$yil: ${v.ekimler.where((e) => e.t('yil') == yil).length} ekim · masraf · stok',
            () => ac(UretimSayfasi(durum: durum))),
        MenuOge('💰', 'Satışlarım', '$yil: ${v.satislar.where((s) => s.yil == yil).length} satış',
            () => ac(SatislarSayfasi(durum: durum)),
            rozet: bekleyen > 0 ? '$bekleyen ödeme bekliyor' : null),
        MenuOge('🏭', 'Depo', '${sayi(depoTon)} ton ürün', () => ac(DepoSayfasi(durum: durum))),
        MenuOge('🟣', 'Pancar & Kooperatif', 'Kota · fabrika · kooperatif',
            () => ac(PancarSayfasi(durum: durum))),
        MenuOge('📈', 'Piyasa', 'Borsa · TMO · fabrika fiyatları',
            () => ac(PiyasaSayfasi(durum: durum))),
      ]),
      ListeMenu(baslik: 'Para', ogeler: [
        MenuOge('👨‍👩‍👦', 'Aile Hesapları',
            odemeler.isEmpty ? 'Herkesin hesabı denk' : '${odemeler.length} ödeme yapılacak',
            () => ac(AileSayfasi(durum: durum))),
        MenuOge('📤', 'Borçlarım', '$borcSayisi açık hesap',
            () => ac(HesaplarSayfasi(durum: durum, yon: 'borc')),
            rozet: gecikme ? 'Gecikmiş' : null),
        MenuOge('📥', 'Alacaklarım', '$alacakSayisi açık hesap',
            () => ac(HesaplarSayfasi(durum: durum, yon: 'alacak'))),
        MenuOge('📒', 'Gelir - Gider', 'Bütün para hareketleri',
            () => ac(DefterSayfasi(durum: durum))),
        MenuOge('💼', 'Ek İşler', 'Maaş · diğer gelirler · destekler',
            () => ac(EkIslerSayfasi(durum: durum)),
            rozet: maasBekleyen ? 'Maaş' : null),
        MenuOge('🏦', 'Finans', 'Kredi · yaklaşan ödemeler · sat/beklet',
            () => ac(FinansSayfasi(durum: durum, geri: true))),
      ]),
      ListeMenu(baslik: 'Diğer', ogeler: [
        MenuOge('📋', 'Görevler', acikIs == 0 ? 'Açık görev yok' : '$acikIs açık görev',
            () => ac(IslerSayfasi(durum: durum))),
        MenuOge('🪙', 'Varlıklarım', 'Birikim · ev bütçesi · net durum',
            () => ac(VarliklarSayfasi(durum: durum))),
        MenuOge('🏡', 'Ev Alma Hedefi',
            evHedef == null ? 'Hedef belirle' : 'Bu ay ${tl0(evHedef.aylik)}',
            () => ac(EvHedefiSayfasi(durum: durum))),
        MenuOge('🧰', 'Malzemelerim', 'Traktör · sulama · araba',
            () => ac(EkipmanSayfasi(durum: durum))),
        MenuOge('🔬', 'Ar-Ge', 'Verimlilik · girdi fiyatları',
            () => ac(ArgeSayfasi(durum: durum))),
      ]),
    ];
  }
}
