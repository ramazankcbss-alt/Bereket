import 'package:flutter/material.dart';

import '../bicim.dart';
import '../hesap.dart';
import '../modeller.dart';
import '../sabitler.dart';
import '../servis/veri.dart';
import '../tema.dart';
import 'form.dart';
import 'kabuk.dart';
import 'tarlalar.dart';
import 'uretim.dart';

double _n(Object? v) => v is num ? v.toDouble() : 0;

/// Bir hareketin kimden kime olduğu (eski kayıtlar "yon" ile tutulur).
(String, String) hareketYonu(Kayit h) {
  if (h.s('veren').isNotEmpty && h.s('alan').isNotEmpty) return (h.s('veren'), h.s('alan'));
  return h.s('yon') == 'o_verdi' ? (h.s('kisi'), Veriler.ben) : (Veriler.ben, h.s('kisi'));
}

/// Kişiler arası para hareketi: kim kime para verdi (ya da birinin borcunu
/// ödedi). Aile dışından kişiler de "+ Yeni kişi" ile eklenebilir.
Future<void> paraHareketiFormu(BuildContext context, Durum durum,
    {String? veren, String? alan, Kayit? hareket}) {
  final v = durum.v;
  final kisiler = v.sahipler();
  final (hv, ha) = hareket == null ? ('', '') : hareketYonu(hareket);
  return formAc(
    context,
    baslik: hareket == null ? 'Para Hareketi' : 'Para Hareketini Düzenle',
    v: v,
    baslangic: {
      'tarih': DateTime.now().millisecondsSinceEpoch,
      ...?hareket?.d,
      'veren': hareket == null ? (veren ?? Veriler.ben) : hv,
      'alan': hareket == null ? (alan ?? (kisiler.length > 1 ? kisiler[1] : '')) : ha,
    },
    alanlar: [
      Alan('veren', 'Parayı veren / ödeyen', tip: AlanTip.secim,
          secenekler: kisiler, yeniYazi: '+ Yeni kişi', yeniEkle: (c) => yeniKisi(c, durum)),
      Alan('alan', 'Parayı alan / borcu ödenen', tip: AlanTip.secim,
          secenekler: kisiler, yeniYazi: '+ Yeni kişi', yeniEkle: (c) => yeniKisi(c, durum)),
      const Alan('tutar', 'Tutar', tip: AlanTip.sayi, birim: '₺', zorunlu: true),
      const Alan('aciklama', 'Açıklama', oneriler: [
        'Nakit', 'Havale', 'Borcunu ödedi', 'Gübre parası', 'Mazot parası',
        'Pancar parası', 'Destek parası',
      ]),
      const Alan('tarih', 'Tarih', tip: AlanTip.tarih),
    ],
    ozet: (d) {
      final ve = (d['veren'] ?? '').toString(), al = (d['alan'] ?? '').toString();
      if (ve.isEmpty || al.isEmpty) return const SizedBox.shrink();
      if (ve == al) {
        return const Text('Veren ve alan aynı kişi olamaz.', style: TextStyle(color: Renk.kirmizi));
      }
      return Text('$ve → $al: ${tl0(_n(d['tutar']))}. $ve\'nin alacağı artar, $al\'nin borcu artar.',
          style: yaziSoluk);
    },
    onKaydet: (d) async {
      final ve = (d['veren'] ?? '').toString().trim();
      final al = (d['alan'] ?? '').toString().trim();
      if (ve.isEmpty || al.isEmpty || ve == al) throw 'Veren ve alan farklı kişiler olmalı.';
      final t = _n(d['tarih']).toInt();
      // Aile üyesi kendi ekranında görebilsin diye "kisi" ve eski "yon" de yazılır.
      final kisi = al == Veriler.ben ? ve : (ve == Veriler.ben ? al : ve);
      final veri = <String, dynamic>{
        'veren': ve,
        'alan': al,
        'kisi': kisi,
        'yon': kisi == ve ? 'o_verdi' : 'ben_verdim',
        'tutar': _n(d['tutar']),
        'aciklama': (d['aciklama'] ?? '').toString(),
        'tarih': t,
        'yil': DateTime.fromMillisecondsSinceEpoch(t).year,
        'ekleyen': hareket?.s('ekleyen').isNotEmpty == true ? hareket!.s('ekleyen') : durum.uid,
        'ekleyenAd': hareket?.s('ekleyenAd').isNotEmpty == true
            ? hareket!.s('ekleyenAd')
            : durum.isim(durum.uid),
      };
      if (hareket == null) {
        await Veri.kol(durum.iid, 'aile_hareketler').add({...veri, 'olusturma': Veri.simdi});
      } else {
        await Veri.kol(durum.iid, 'aile_hareketler').doc(hareket.id).update(veri);
      }
    },
    onSil: hareket == null
        ? null
        : () => Veri.kol(durum.iid, 'aile_hareketler').doc(hareket.id).delete(),
  );
}

class AileSayfasi extends StatefulWidget {
  const AileSayfasi({super.key, required this.durum});
  final Durum durum;

  @override
  State<AileSayfasi> createState() => _AileSayfasiState();
}

class _AileSayfasiState extends State<AileSayfasi> {
  String _yil = '${DateTime.now().year}';

  @override
  Widget build(BuildContext context) {
    final durum = widget.durum;
    return Sayfa(
      baslik: 'Aile Hesapları',
      durum: durum,
      builder: (context, v) {
        final yillar = ['Tüm yıllar', for (final y in v.yillar(DateTime.now().year)) '$y'];
        final yil = int.tryParse(_yil);
        final kisiler = v.sahipler();
        return [
          SecimSatiri(
            secenekler: yillar,
            etiket: 'Yıl',
            secili: yillar.contains(_yil) ? _yil : yillar[1],
            onSec: (s) => setState(() => _yil = s),
          ),
          const SizedBox(height: 10),
          _borclarPaneli(context, v, yil),
          for (final k in kisiler)
            _kisiKarti(context, v, v.sahipOzet(k, yil: yil)),
          const Panel(
            child: Text(
              'Herkesin hesabı ayrıdır: her ekimde "Kim ekiyor", her gider ve toplu alımda '
              '"Kim ödedi", her tahsilatta "Para kime yattı" seçilir. Herkes kullandığı '
              'malzeme ve masraf kadarını üstlenir; kim kime ne kadar borçlu buradan çıkar. '
              'Aralarında para verilince "Para Hareketi Ekle" ile girin.',
              style: yaziSoluk,
            ),
          ),
        ];
      },
    );
  }

  Widget _borclarPaneli(BuildContext context, Veriler v, int? yil) {
    final oneriler = v.hesaplasmaOnerisi(yil: yil);
    return Panel(
      baslik: '🤝 Kim kime ne ödemeli',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (oneriler.isEmpty)
            const Text('Herkesin hesabı denk.', style: yaziSoluk)
          else
            for (final o in oneriler)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('${o.kimden} → ${o.kime}',
                          style: const TextStyle(color: Renk.yazi, fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                    Text(tl0(o.tutar),
                        style: const TextStyle(color: Renk.altin, fontSize: 16, fontWeight: FontWeight.w800)),
                    IconButton(
                      tooltip: 'Ödendi olarak gir',
                      icon: const Icon(Icons.check_circle_outline, color: Renk.yesil),
                      onPressed: () => paraHareketiFormu(context, widget.durum,
                          veren: o.kimden, alan: o.kime),
                    ),
                  ],
                ),
              ),
          if (yil != null && oneriler.isNotEmpty)
            const Text('Yalnızca bu yılın kayıtları. Tüm hesap için "Tüm yıllar"ı seçin.',
                style: yaziSoluk),
          const SizedBox(height: 8),
          Buton(
            yazi: 'Para Hareketi Ekle',
            yukseklik: 44,
            renk: ButonRenk.yesil,
            onTap: () => paraHareketiFormu(context, widget.durum),
          ),
        ],
      ),
    );
  }

  Widget _kisiKarti(BuildContext context, Veriler v, SahipOzet o) {
    final ben = o.sahip == Veriler.ben;
    final kalemler = o.kalemler.entries.toList()
      ..sort((a, b) => b.value.tutar.compareTo(a.value.tutar));
    return Panel(
      baslik: '${ben ? '🧑‍🌾' : '👤'} ${o.sahip}',
      eylem: Text('${o.tarlaSayisi} tarla · ${sayi(o.dekar)} da', style: yaziSoluk),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Satir('Masraf', tl0(o.masraf)),
          if (o.dekar > 0 && o.masraf > 0)
            Satir('Dekar başı masraf', tl0(o.masraf / o.dekar), renk: Renk.altin),
          Satir('Hasat', '${sayi(o.hasatKg)} kg'),
          Satir('Satış', tl0(o.satis)),
          if (o.destek > 0) Satir('Destekler', tl0(o.destek), renk: Renk.turkuaz),
          if (o.kiraGeliri > 0) Satir('Kira geliri', tl0(o.kiraGeliri)),
          Satir('Kâr', tl0(o.kar), kalin: true, renk: o.kar >= 0 ? Renk.yesil : Renk.kirmizi),
          if (kalemler.isNotEmpty) ...[
            const Divider(height: 18),
            const Text('Kullanılan malzeme ve masraflar', style: yaziSoluk),
            const SizedBox(height: 4),
            for (final k in kalemler)
              Satir(
                  '${giderSimge[k.key] ?? '📦'} ${k.key}'
                  '${k.value.miktar > 0 ? ' · ${sayi(k.value.miktar)} ${k.value.birim}' : ''}',
                  tl0(k.value.tutar)),
          ],
          if (o.ekimler.isNotEmpty) ...[
            const Divider(height: 18),
            for (var i = 0; i < o.ekimler.length; i++)
              InkWell(
                onTap: () => git(context, EkimDetay(durum: widget.durum, ekimId: o.ekimler[i].ekim.id)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Text(urunSimge(o.ekimler[i].ekim.s('urun')),
                          style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                            '${o.ekimler[i].ekim.t('yil')} · ${o.ekimler[i].ekim.s('urun')} · '
                            '${v.tarlaAdi(o.ekimler[i].ekim.s('tarlaId'))}'
                            '${o.paylar[i] < 0.999 ? ' (%${(o.paylar[i] * 100).round()})' : ''}',
                            style: const TextStyle(color: Renk.yazi)),
                      ),
                      Text(tl0(o.ekimler[i].kar * o.paylar[i]),
                          style: TextStyle(
                              color: o.ekimler[i].kar >= 0 ? Renk.yesil : Renk.kirmizi)),
                    ],
                  ),
                ),
              ),
          ],
          ..._defterKutusu(context, v, o),
        ],
      ),
    );
  }

  List<Widget> _defterKutusu(BuildContext context, Veriler v, SahipOzet o) {
    final d = o.defter;
    final hareketler = v.aileHareketleri.where((h) {
      final (ve, al) = hareketYonu(h);
      return ve == o.sahip || al == o.sahip;
    }).toList()
      ..sort((a, b) => b.t('tarih').compareTo(a.t('tarih')));
    if (d == null || (d.bos && hareketler.isEmpty)) return const [];
    final h = d.bakiye;
    return [
      const Divider(height: 18),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Renk.zeminAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: h >= 0 ? Renk.yesil : Renk.turuncu, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Kişisel hesap', style: yaziKalin),
            const SizedBox(height: 4),
            Satir('Ödediği (gider, toplu alım)', tl0(d.odedi)),
            Satir('Kullandığı malzeme ve masraf', tl0(d.yuk)),
            if (d.hak > 0) Satir('Satış ve destekten payı', tl0(d.hak)),
            if (d.aldi > 0) Satir('Satış ve destekten eline geçen', tl0(d.aldi)),
            if (d.verdi > 0) Satir('Başkalarına verdiği', tl0(d.verdi)),
            if (d.aldiPara > 0) Satir('Başkalarından aldığı', tl0(d.aldiPara)),
            const SizedBox(height: 6),
            Text(
              h.abs() < 1
                  ? 'Hesap denk.'
                  : (h > 0 ? 'Alacağı: ${tl0(h)}' : 'Borcu: ${tl0(-h)}'),
              style: TextStyle(
                  color: h >= 0 ? Renk.yesil : Renk.turuncu,
                  fontSize: 16,
                  fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
      if (hareketler.isNotEmpty) ...[
        const SizedBox(height: 8),
        const Text('Para hareketleri', style: yaziSoluk),
        for (final x in hareketler.take(8))
          InkWell(
            onTap: () => paraHareketiFormu(context, widget.durum, hareket: x),
            child: Builder(builder: (_) {
              final (ve, al) = hareketYonu(x);
              return Satir(
                  '${tarih(x.t('tarih'))} · $ve → $al'
                  '${x.s('aciklama').isEmpty ? '' : ' · ${x.s('aciklama')}'}',
                  tl0(x.n('tutar')),
                  renk: ve == o.sahip ? Renk.yesil : Renk.turuncu);
            }),
          ),
      ],
    ];
  }
}
