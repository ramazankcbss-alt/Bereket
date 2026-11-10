import 'package:flutter/material.dart';

import '../bicim.dart';
import '../hesap.dart';
import '../modeller.dart';
import '../sabitler.dart';
import '../servis/veri.dart';
import '../tema.dart';
import 'form.dart';
import 'tarlalar.dart';
import 'uretim.dart';

/// Ortak stok (toplu alım): gübre, tohum, ilaç, mazot gibi topluca alınan
/// girdiler. Alım maliyete yazılmaz; herkes kullandığını "Kullanım Gir" ile
/// tarlasına yazdıkça miktar ana depodan düşer ve maliyet o tarlaya
/// (o yılı ekene) alış fiyatından yazılır.
const stokBirimleri = ['kg', 'ton', 'lt', 'çuval', 'torba', 'adet'];

double _n(Object? v) => v is num ? v.toDouble() : 0;

Future<void> stokFormu(BuildContext context, Durum durum, {Kayit? stok}) {
  final v = durum.v;
  final simdi = DateTime.now();
  final tedarikciler = <String>{
    for (final g in v.giderler)
      if (g.s('tedarikci').isNotEmpty) g.s('tedarikci'),
    for (final s in v.stoklar)
      if (s.s('tedarikci').isNotEmpty) s.s('tedarikci'),
  }.toList();
  final kullanilan = stok == null ? 0.0 : v.stokKullanilan(stok.id);
  return formAc(
    context,
    baslik: stok == null ? 'Toplu Alım (Ortak Stok)' : 'Stoğu Düzenle',
    v: v,
    baslangic: {
      'kalem': 'Gübre',
      'birim': 'kg',
      'tarih': simdi.millisecondsSinceEpoch,
      'yil': simdi.year,
      'odendi': true,
      'odeyen': Veriler.ben,
      ...?stok?.d,
    },
    alanlar: [
      Alan('kalem', 'Ne alındı', tip: AlanTip.secim,
          secenekler: const ['Gübre', 'Tohum', 'İlaç', 'Mazot', 'Diğer']),
      const Alan('aciklama', 'Ürün adı', zorunlu: true,
          ipucu: 'Örn. DAP 18-46, Üre, Amonyum sülfat'),
      const Alan('birim', 'Birim', tip: AlanTip.secim, secenekler: stokBirimleri),
      const Alan('miktar', 'Alınan miktar', tip: AlanTip.sayi, zorunlu: true),
      const Alan('birimFiyat', 'Birim fiyat', tip: AlanTip.sayi, birim: '₺',
          aciklama: 'Kullanımlar bu fiyattan tarlalara maliyet olarak yazılır.'),
      const Alan('tutar', 'Toplam tutar', tip: AlanTip.sayi, birim: '₺', zorunlu: true),
      const Alan('tarih', 'Alış tarihi', tip: AlanTip.tarih),
      const Alan('yil', 'Hangi sezon için', tip: AlanTip.yil),
      Alan('tedarikci', 'Nereden alındı', oneriler: tedarikciler),
      Alan('odeyen', 'Kim ödedi / ödeyecek', tip: AlanTip.secim,
          secenekler: v.sahipler(),
          yeniYazi: '+ Yeni kişi',
          yeniEkle: (c) => yeniKisi(c, durum),
          aciklama: 'Herkes kullandığı kadarını üstlenir; aradaki fark Aile Hesapları\'nda borç/alacak olur.'),
      if (!durum.sinirli)
        const Alan('odendi', 'Ödendi', tip: AlanTip.anahtar,
            ipucu: 'Kapatırsanız tutar satıcı adına Borçlarım\'a yazılır.'),
      const Alan('not', 'Not', tip: AlanTip.uzun),
    ],
    degisince: (key, d) {
      if (key == 'kalem') {
        d['birim'] = (d['kalem'] == 'İlaç' || d['kalem'] == 'Mazot') ? 'lt' : 'kg';
      }
      final m = _n(d['miktar']), bf = _n(d['birimFiyat']), t = _n(d['tutar']);
      if ((key == 'miktar' || key == 'birimFiyat') && m > 0 && bf > 0) {
        d['tutar'] = double.parse((m * bf).toStringAsFixed(2));
      } else if (key == 'tutar' && m > 0 && t > 0) {
        d['birimFiyat'] = double.parse((t / m).toStringAsFixed(4));
      }
    },
    ozet: (d) {
      final m = _n(d['miktar']);
      final b = (d['birim'] ?? '').toString();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (stok != null) ...[
            Satir('Kullanılan', '${sayi(kullanilan)} $b'),
            Satir('Kalan', '${sayi(m - kullanilan)} $b',
                kalin: true, renk: m - kullanilan < 0 ? Renk.kirmizi : Renk.altin),
          ] else
            const Text(
                'Alım maliyete yazılmaz; tarlalara kullanıldıkça yazılır. '
                'Kullanımı Üretim Merkezi → Stok → Kullanım Gir ile ya da Maliyet Ekle\'de '
                '"Ortak stoktan" seçerek girin.',
                style: yaziSoluk),
        ],
      );
    },
    onKaydet: (d) async {
      if (durum.sinirli) d['odendi'] = true;
      final m = _n(d['miktar']);
      if (_n(d['birimFiyat']) <= 0 && m > 0) {
        d['birimFiyat'] = double.parse((_n(d['tutar']) / m).toStringAsFixed(4));
      }
      await durum.kaydet('stoklar', d, id: stok?.id);
      if (stok == null && d['odendi'] != true) {
        await Veri.borcaYaz(durum.iid, v,
            kime: (d['tedarikci'] ?? '').toString(),
            tur: 'Bayi',
            tutar: _n(d['tutar']),
            aciklama: 'Toplu alım: ${(d['aciklama'] ?? '').toString()}',
            tarih: _n(d['tarih']).toInt(),
            uid: durum.uid,
            kimin: (d['odeyen'] ?? '').toString());
      }
    },
    onSil: stok == null ? null : () => durum.sil('stoklar', stok.id),
  );
}

/// Üretim Merkezi → Stok sekmesi.
List<Widget> stokSekmesi(BuildContext context, Durum durum, Veriler v) {
  final liste = [...v.stoklar]..sort((a, b) {
      final ka = v.stokKalan(a.id) > 0, kb = v.stokKalan(b.id) > 0;
      if (ka != kb) return ka ? -1 : 1;
      return b.t('tarih').compareTo(a.t('tarih'));
    });
  return [
    if (liste.isEmpty)
      const BosDurum(
        simge: '📦',
        yazi: 'Topluca aldığınız gübre, tohum, ilaç, mazotu "Toplu Alım" ile girin. '
            'Herkes kullandığını girdikçe ana depodan düşer, kalan burada görünür.',
      ),
    for (final s in liste) _stokKarti(context, durum, v, s),
  ];
}

Widget _stokKarti(BuildContext context, Durum durum, Veriler v, Kayit s) {
  final b = s.s('birim');
  final alinan = s.n('miktar');
  final kullanilan = v.stokKullanilan(s.id);
  final kalan = alinan - kullanilan;
  final oran = alinan > 0 ? (kullanilan / alinan).clamp(0.0, 1.0) : 0.0;
  // Kişilere göre kullanım (o yılı ekenin hesabına).
  final kisiler = <String, double>{};
  for (final g in v.stokKullanimlari(s.id)) {
    for (final k in v.sahipler()) {
      final p = v.giderSahipPayi(g, k);
      if (p > 0) kisiler[k] = (kisiler[k] ?? 0) + g.n('miktar') * p;
    }
  }
  return Panel(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    onTap: () => stokFormu(context, durum, stok: s),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(giderSimge[s.s('kalem')] ?? '📦', style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 8),
            Expanded(child: Text(v.stokAdi(s), style: yaziKalin)),
            Text('${s.t('yil')}', style: yaziSoluk),
          ],
        ),
        const SizedBox(height: 8),
        Satir('Alınan', '${sayi(alinan)} $b'),
        Satir('Kullanılan', '${sayi(kullanilan)} $b'),
        Satir('Kalan', '${sayi(kalan)} $b',
            kalin: true, renk: kalan < 0 ? Renk.kirmizi : Renk.altin),
        if (s.n('birimFiyat') > 0) Satir('Birim fiyat', tl(s.n('birimFiyat'))),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: oran,
            minHeight: 8,
            backgroundColor: Renk.zeminAlt,
            color: kalan < 0 ? Renk.kirmizi : Renk.yesil,
          ),
        ),
        if (kisiler.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final e in kisiler.entries)
                Etiket('${e.key}: ${sayi(e.value)} $b', renk: Renk.kartAcik),
            ],
          ),
        ],
        if (kalan < 0)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('Kullanım alınan miktarı aşıyor.', style: TextStyle(color: Renk.kirmizi)),
          ),
        const SizedBox(height: 10),
        Buton(
          yazi: 'Kullanım Gir',
          yukseklik: 44,
          onTap: () => giderFormu(context, durum, stokId: s.id),
        ),
      ],
    ),
  );
}
