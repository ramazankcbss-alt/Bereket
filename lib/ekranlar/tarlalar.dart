import 'package:flutter/material.dart';

import '../bicim.dart';
import '../hesap.dart';
import '../modeller.dart';
import '../sabitler.dart';
import '../servis/idari.dart';
import '../servis/veri.dart';
import 'cks.dart';
import '../tema.dart';
import 'form.dart';
import 'kabuk.dart';
import 'uretim.dart';

/// Ortak ekim alanları: "Ortak ekiliyor" + her kişi için pay (%).
List<Alan> ortakAlanlari(List<String> sahipler,
        {bool Function(Map<String, dynamic> d)? gorunur}) =>
    [
      Alan('ortak', 'Ortak ekiliyor', tip: AlanTip.anahtar,
          ipucu: 'Masraf, hasat, satış, destek ve kâr paylara göre bölünür.',
          gorunur: gorunur),
      for (final k in sahipler)
        Alan('o_$k', '$k payı', tip: AlanTip.sayi, birim: '%',
            gorunur: (d) => d['ortak'] == true && (gorunur == null || gorunur(d))),
    ];

void ortakDoldur(Map<String, dynamic> bas, Map<String, dynamic> ortaklar) {
  if (ortaklar.isEmpty) return;
  bas['ortak'] = true;
  ortaklar.forEach((k, v) => bas['o_$k'] = v);
}

/// Form değerlerinden 'ortaklar' haritasını kurar, geçici alanları siler.
void ortakTopla(Map<String, dynamic> d) {
  final ortak = d.remove('ortak') == true;
  final m = <String, double>{};
  for (final k in d.keys.where((k) => k.startsWith('o_')).toList()) {
    final v = d.remove(k);
    if (ortak && v is num && v > 0) m[k.substring(2)] = v.toDouble();
  }
  d['ortaklar'] = m;
}

/// Tarla ekle / düzenle. Burada yalnızca konum, ada/parsel ve alan girilir;
/// ÇKS sahibi, arazinin durumu, kira, kim ektiği ve ortaklık her yılın
/// ekiminde (Üretim Merkezi) sorulur.
Future<void> tarlaFormu(BuildContext context, Durum durum, {Kayit? tarla}) async {
  await Idari.yukle();
  if (!context.mounted) return;
  final v = durum.v;
  final bas = <String, dynamic>{
    'il': 'Konya',
    'ilce': 'Karapınar',
    ...?tarla?.d,
  };
  if ((bas['il'] ?? '').toString().isEmpty) bas['il'] = 'Konya';
  String s(Map<String, dynamic> d, String k) => (d[k] ?? '').toString();
  final liste = Idari.hazir;
  return formAc(
    context,
    baslik: tarla == null ? 'Yeni Tarla' : 'Tarlayı Düzenle',
    v: v,
    baslangic: bas,
    alanlar: [
      const Alan('ad', 'Tarla adı / mevki', ipucu: 'Örn. Kuyu başı', zorunlu: true),
      if (liste) ...[
        Alan('il', 'İl', tip: AlanTip.secim, seceneklerFn: (_) => Idari.iller()),
        Alan('ilce', 'İlçe', tip: AlanTip.secim,
            seceneklerFn: (d) => Idari.ilceler(s(d, 'il'))),
        Alan('mahalle', 'Mahalle / köy', tip: AlanTip.secim,
            seceneklerFn: (d) => Idari.mahalleler(s(d, 'il'), s(d, 'ilce'))),
      ] else ...[
        const Alan('il', 'İl'),
        const Alan('ilce', 'İlçe'),
        const Alan('mahalle', 'Mahalle / köy'),
      ],
      const Alan('ada', 'Ada'),
      const Alan('parsel', 'Parsel'),
      const Alan('dekar', 'Alan (ÇKS)', tip: AlanTip.sayi, birim: 'dekar', zorunlu: true,
          aciklama: 'ÇKS\'de m² yazar: 1000\'e bölün (40.000 m² = 40 dekar).'),
      const Alan('not', 'Not', tip: AlanTip.uzun),
    ],
    degisince: (key, d) {
      // Üst seçim değişince alttakiler boşalır (il → ilçe → mahalle).
      if (key == 'il') {
        d['ilce'] = '';
        d['mahalle'] = '';
      } else if (key == 'ilce') {
        d['mahalle'] = '';
      }
    },
    // Eski sürümde tarlaya girilmiş bilgiler (ÇKS, arazi durumu, kira,
    // kim ekiyor...) korunur; o yılın ekiminde seçim yoksa onlar geçerlidir.
    ozet: (d) {
      final da = d['dekar'] is num ? (d['dekar'] as num).toDouble() : 0.0;
      if (da < 1000) return const SizedBox.shrink();
      return Text(
          '${sayi(da)} dekar çok büyük. m² yazdıysanız ${sayi(da / 1000)} dekar olarak '
          'kaydedilecek.',
          style: const TextStyle(color: Renk.turuncu, fontWeight: FontWeight.w700));
    },
    // m² yazıldıysa (1000 ve üstü) dekara çevrilir.
    onKaydet: (d) async {
      final da = d['dekar'] is num ? (d['dekar'] as num).toDouble() : 0.0;
      if (da >= 1000) d['dekar'] = da / 1000;
      await durum.kaydet('tarlalar', d, id: tarla?.id);
    },
    onSil: tarla == null ? null : () => durum.sil('tarlalar', tarla.id),
  );
}

/// Yeni hesap sahibi (kişi) ekler; Profil'deki listeye ve Aile Hesapları'na girer.
Future<String?> yeniKisi(BuildContext context, Durum durum) async {
  final s = (await metinSor(context, 'Kişi adı', ipucu: 'Örn. Amcam, Ali Yılmaz'))?.trim();
  if (s == null || s.isEmpty) return null;
  final v = durum.v;
  if (!v.sahipler().contains(s)) {
    final liste = v.sahipler().where((x) => x != Veriler.ben).toList();
    try {
      await durum.ayarYaz('sahipler', {...liste, s}.toList());
    } catch (e) {
      if (context.mounted) bildir(context, hataYazisi(e));
      return null;
    }
  }
  return s;
}

/// Yeni ekimde arazi bilgisinin ilk değeri: tarlanın son ekimindeki ya da
/// eski kayıtlarda tarlaya girilmiş bilgi.
Map<String, dynamic>? araziVarsayilan(Veriler v, String? tarlaId) {
  if (tarlaId == null || tarlaId.isEmpty) return null;
  final t = v.tarla(tarlaId);
  if (t == null) return null;
  final son = v.tarlaEkimleri(tarlaId).where((e) => e.s('mulkiyet').isNotEmpty).firstOrNull;
  String al(String k, String vars) {
    final x = son?.s(k) ?? '';
    if (x.isNotEmpty) return x;
    final y = t.s(k);
    return y.isNotEmpty ? y : vars;
  }
  final kira = (son?.n('kira') ?? 0) > 0 ? son!.n('kira') : t.n('kira');
  return {
    'cks': al('cks', Veriler.ben),
    'mulkiyet': al('mulkiyet', 'Kendi'),
    if (kira > 0) 'kira': kira,
    if (al('kiraVeren', '').isNotEmpty) 'kiraVeren': al('kiraVeren', ''),
  };
}

/// Ekim / hasat kaydı. Gelecek yılın sezonu seçilirse durum "Ekim planlanıyor" olur
/// (ÇKS'de gelecek yılın ürünü bu yılın başvuru döneminde yazılır).
Future<void> ekimFormu(BuildContext context, Durum durum,
    {Kayit? ekim, String? tarlaId, String? urun, int? yil}) {
  final v = durum.v;
  if (v.tarlalar.isEmpty) {
    bildir(context, 'Önce bir tarla ekleyin.');
    return Future.value();
  }
  final buYil = DateTime.now().year;
  final sezon = yil ?? buYil;
  final bas = <String, dynamic>{
    'yil': sezon,
    'durum': sezon > buYil ? ekimPlanlaniyor : 'Ekildi',
    'tarlaId': tarlaId ?? '',
    if (urun != null) 'urun': urun,
    'sahip': tarlaId == null ? '' : v.tarlaSahibi(tarlaId),
    'gelirSahibi': Veriler.ben,
    ...?araziVarsayilan(v, tarlaId),
    ...?ekim?.d,
  };
  if (ekim != null && ekim.s('mulkiyet').isEmpty) bas.addAll(araziVarsayilan(v, ekim.s('tarlaId')) ?? {});
  final kiraVerenler = <String>{
    'Milli Emlak',
    for (final x in [...v.tarlalar, ...v.ekimler])
      if (x.s('kiraVeren').isNotEmpty) x.s('kiraVeren'),
  }.toList();
  bool kiralik(Map<String, dynamic> d) {
    final m = (d['mulkiyet'] ?? '').toString();
    return m.isNotEmpty && m != 'Kendi' && m != 'Ortak';
  }
  bool verildi(Map<String, dynamic> d) => d['sahip'] == baskasi;
  bas['farkliAlan'] = (ekim?.n('dekar') ?? 0) > 0;
  if (ekim != null) ortakDoldur(bas, ekim.m('ortaklar'));
  int yilOf(Map<String, dynamic> d) =>
      d['yil'] is num ? (d['yil'] as num).toInt() : buYil;
  // Aynı tarlada aynı yıl girilmiş diğer ekimlerin alanı (bu ekim hariç).
  double digerleri(Map<String, dynamic> d) => v.ekimler
      .where((e) =>
          e.id != ekim?.id &&
          e.s('tarlaId') == (d['tarlaId'] ?? '').toString() &&
          e.t('yil') == yilOf(d))
      .fold(0.0, (a, e) => a + v.ekimDekar(e));
  return formAc(
    context,
    baslik: ekim == null ? 'Ekim / Hasat' : 'Ekimi Düzenle',
    v: v,
    baslangic: bas,
    alanlar: [
      const Alan('tarlaId', 'Tarla', tip: AlanTip.tarla, zorunlu: true),
      const Alan('yil', 'Sezon (yıl)', tip: AlanTip.yil),
      Alan('farkliAlan', 'Ekilen alan ÇKS alanından farklı', tip: AlanTip.anahtar,
          ipucu: 'Tarlanın bir kısmı ekildiyse ya da tarla iki ürüne bölündüyse açın. '
              'Kapalıysa tarlanın ÇKS alanının tamamı sayılır.'),
      Alan('dekar', 'Ekilen alan', tip: AlanTip.sayi, birim: 'dekar', zorunlu: true,
          gorunur: (d) => d['farkliAlan'] == true,
          aciklama: 'Giderler aynı tarladaki ekimlere bu alanlara göre bölünür.'),
      Alan('kiraDekar', 'Kira dekar fiyatı', tip: AlanTip.sayi, birim: '₺/da',
          gorunur: (d) => !verildi(d) && kiralik(d),
          aciklama: 'Yazınca kira bedeli ekilen alanla çarpılıp kendiliğinden hesaplanır.'),
      Alan('urun', 'Ürün', tip: AlanTip.secim,
          secenekler: [for (final u in urunler) u.ad], zorunlu: true),
      Alan('cks', 'ÇKS kimin üzerine', tip: AlanTip.secim,
          secenekler: [...v.sahipler(), cksBizdeDegil]),
      Alan('sahip', 'Kim ekiyor', tip: AlanTip.secim,
          secenekler: [...v.sahipler(), baskasi],
          yeniYazi: '+ Yeni kişi',
          yeniEkle: (c) => yeniKisi(c, durum),
          aciklama: 'Maliyet, satış ve kâr bu kişinin hesabına yazılır. '
              '"Başkası": tarlayı kiraya verdik.'),
      ...ortakAlanlari(v.sahipler(), gorunur: (d) => !verildi(d)),
      Alan('kiraci', 'Kiracının adı', gorunur: verildi),
      Alan('kiraGeliri', 'Aldığımız kira', tip: AlanTip.sayi, birim: '₺', gorunur: verildi),
      Alan('gelirSahibi', 'Kira geliri kimin', tip: AlanTip.secim,
          secenekler: v.sahipler(), gorunur: verildi),
      Alan('mulkiyet', 'Arazinin durumu', tip: AlanTip.secim, secenekler: mulkiyetler,
          gorunur: (d) => !verildi(d),
          aciklama: 'Aileden biri kendi arazisini ekiyorsa "Kendi"; '
              'başkasının arazisini kiraladıysak "Kiralık".'),
      Alan('kira', 'Kira / ecrimisil bedeli', tip: AlanTip.sayi, birim: '₺',
          gorunur: (d) => !verildi(d) && kiralik(d),
          aciklama: 'Bu ekimin maliyetine eklenir (ayrıca gider girilmediyse).'),
      Alan('kiraVeren', 'Kime ödeniyor', oneriler: kiraVerenler,
          gorunur: (d) => !verildi(d) && kiralik(d)),
      Alan('destekSahibi', 'Mazot-gübre desteği kimin', tip: AlanTip.secim,
          secenekler: ['', ...v.sahipler()],
          gorunur: (d) => !verildi(d) && !kiralik(d),
          aciklama: 'Boşsa ÇKS sahibine yazılır. Ürün desteği her zaman ekene yazılır.'),
      const Alan('durum', 'Durum', tip: AlanTip.secim, secenekler: ekimDurumlari),
      Alan('ekimTarihi', 'Ekim tarihi', tip: AlanTip.tarih,
          gorunur: (d) => d['durum'] != ekimPlanlaniyor),
      Alan('hasatKg', 'Hasat edilen miktar', tip: AlanTip.sayi, birim: 'kg',
          gorunur: (d) => d['durum'] == 'Hasat edildi',
          aciklama: 'Depoya bu miktar girer.'),
      Alan('hasatTarihi', 'Hasat tarihi', tip: AlanTip.tarih,
          gorunur: (d) => d['durum'] == 'Hasat edildi'),
      const Alan('not', 'Not', tip: AlanTip.uzun),
    ],
    ozet: (d) {
      final t = v.tarla((d['tarlaId'] ?? '').toString());
      final u = (d['urun'] ?? '').toString();
      final y = yilOf(d);
      if (t == null) {
        return const Text('Tarla ve ürün seçince münavebe kontrol edilir.',
            style: yaziSoluk);
      }
      final cks = t.n('dekar');
      final bu = d['farkliAlan'] == true
          ? (d['dekar'] is num ? (d['dekar'] as num).toDouble() : 0.0)
          : cks;
      final diger = digerleri(d);
      final asim = bu + diger > cks + 0.001;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              'ÇKS alanı ${sayi(cks)} da · bu ekim ${sayi(bu)} da'
              '${diger > 0 ? ' · aynı yıl diğer ekimler ${sayi(diger)} da' : ''}',
              style: TextStyle(color: asim ? Renk.turuncu : Renk.soluk)),
          if (asim)
            const Text('Ekimlerin toplamı ÇKS alanını aşıyor.',
                style: TextStyle(color: Renk.turuncu)),
          if (u.isNotEmpty) ...[
            const SizedBox(height: 6),
            MunavebeSatiri(v.munavebe(t, u, y)),
          ],
        ],
      );
    },
    degisince: (key, d) {
      // Farklı alan seçilince kalan alanı öner (tarla ikiye bölünüyorsa).
      if (key == 'tarlaId' && ekim == null) {
        final id = (d['tarlaId'] ?? '').toString();
        if (id.isNotEmpty) {
          d['sahip'] = v.tarlaSahibi(id);
          d.addAll(araziVarsayilan(v, id) ?? {});
        }
      }
      if (key == 'farkliAlan' || key == 'tarlaId' || key == 'yil') {
        final t = v.tarla((d['tarlaId'] ?? '').toString());
        final dk = d['dekar'];
        if (d['farkliAlan'] == true && t != null && (dk is! num || dk <= 0)) {
          final kalan = t.n('dekar') - digerleri(d);
          if (kalan > 0) d['dekar'] = kalan;
        }
      }
      // Kira bedeli = dekar fiyatı × ekilen alan.
      if (key == 'kiraDekar' || key == 'dekar' || key == 'farkliAlan' || key == 'tarlaId' ||
          key == 'mulkiyet') {
        final df = d['kiraDekar'] is num ? (d['kiraDekar'] as num).toDouble() : 0.0;
        if (df > 0 && kiralik(d)) {
          final t = v.tarla((d['tarlaId'] ?? '').toString());
          final alan = d['farkliAlan'] == true
              ? (d['dekar'] is num ? (d['dekar'] as num).toDouble() : 0.0)
              : (t?.n('dekar') ?? 0.0);
          if (alan > 0) d['kira'] = double.parse((df * alan).toStringAsFixed(2));
        }
      }
      if (key != 'yil') return;
      final y = d['yil'] is num ? (d['yil'] as num).toInt() : buYil;
      if (y > buYil) {
        d['durum'] = ekimPlanlaniyor;
      } else if (d['durum'] == ekimPlanlaniyor) {
        d['durum'] = 'Ekildi';
      }
    },
    onKaydet: (d) async {
      if (d.remove('farkliAlan') != true) d['dekar'] = null;
      // m² yazıldıysa dekara çevir.
      final ekDa = d['dekar'] is num ? (d['dekar'] as num).toDouble() : 0.0;
      if (ekDa >= 1000) {
        d['dekar'] = ekDa / 1000;
        final df = d['kiraDekar'] is num ? (d['kiraDekar'] as num).toDouble() : 0.0;
        if (df > 0) d['kira'] = double.parse((df * ekDa / 1000).toStringAsFixed(2));
      }
      if (d['sahip'] == baskasi) {
        d['ortaklar'] = null;
      } else {
        d['kiraci'] = null;
        d['kiraGeliri'] = null;
      }
      if (!kiralik(d)) {
        d['kira'] = null;
        d['kiraDekar'] = null;
        d['kiraVeren'] = null;
      }
      if (d['durum'] == ekimPlanlaniyor) d['ekimTarihi'] = null;
      if (d['durum'] != 'Hasat edildi') {
        d['hasatKg'] = null;
        d['hasatTarihi'] = null;
      }
      ortakTopla(d);
      await durum.kaydet('ekimler', d, id: ekim?.id);
    },
    onSil: ekim == null ? null : () => durum.sil('ekimler', ekim.id),
  );
}

class MunavebeSatiri extends StatelessWidget {
  const MunavebeSatiri(this.m, {super.key});
  final Munavebe m;

  @override
  Widget build(BuildContext context) {
    final renk = switch (m.seviye) {
      0 => Renk.yesil,
      1 => Renk.turuncu,
      _ => Renk.kirmizi,
    };
    final simge = switch (m.seviye) { 0 => '✅', 1 => '⚠️', _ => '⛔' };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(simge, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 8),
        Expanded(child: Text(m.mesaj, style: TextStyle(color: renk, fontSize: 14.5))),
      ],
    );
  }
}

/// "Ne ekeyim?" önerileri.
Future<void> neEkeyim(BuildContext context, Durum durum, Kayit tarla) {
  final v = durum.v;
  final yil = DateTime.now().month >= 8 ? DateTime.now().year + 1 : DateTime.now().year;
  final oneriler = v.neEkeyim(tarla, yil);
  final gecmis = v.urunGecmisi(tarla);
  final yillar = gecmis.keys.toList()..sort((a, b) => b.compareTo(a));
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      builder: (c, kontrol) => ListView(
        controller: kontrol,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Text('${v.tarlaTam(tarla.id)} · $yil için ne ekilsin?', style: yaziKalin),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final y in yillar.take(6))
                Etiket('$y: ${gecmis[y]}', renk: Renk.kartAcik, simge: urunSimge(gecmis[y]!)),
            ],
          ),
          if (yillar.isEmpty)
            const Text('Geçmiş yıl bilgisi yok. Son yıllarda ne ekildiğini "Ekim Gir" ile geçmiş sezonlara girerseniz öneriler daha doğru olur.',
                style: yaziSoluk),
          const SizedBox(height: 12),
          for (final o in oneriler)
            Panel(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              kenarRengi: o.munavebe.seviye == 0
                  ? Renk.yesil
                  : (o.munavebe.seviye == 1 ? Renk.turuncu : Renk.cizgi),
              onTap: o.munavebe.seviye == 2
                  ? null
                  : () {
                      Navigator.pop(c);
                      ekimFormu(context, durum, tarlaId: tarla.id, urun: o.urun, yil: yil);
                    },
              child: Row(
                children: [
                  Text(urunSimge(o.urun), style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(o.urun, style: yaziKalin),
                        MunavebeSatiri(o.munavebe),
                      ],
                    ),
                  ),
                  if (o.dekarKar != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(tl0(o.dekarKar!),
                            style: TextStyle(
                                color: o.dekarKar! >= 0 ? Renk.yesil : Renk.kirmizi,
                                fontWeight: FontWeight.w800)),
                        const Text('dekar kârı', style: yaziSoluk),
                      ],
                    ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

/// ÇKS Yükle (Üretim Merkezi'nde): kamera, galeri ya da dosyadan.
void cksBilgi(BuildContext context, Durum durum) => git(context, CksYukle(durum: durum));

/// Ne Ekeyim? için tarla seçtirir (Üretim Merkezi'nde).
Future<void> neEkeyimSec(BuildContext context, Durum durum) async {
  final v = durum.v;
  if (v.tarlalar.isEmpty) {
    bildir(context, 'Önce Tarlalarım\'dan tarla ekleyin.');
    return;
  }
  final adlar = {for (final t in v.tarlalar) v.tarlaEtiketi(t.id): t};
  final s = await secimYap(context, 'Hangi tarla?', adlar.keys.toList());
  if (s != null && context.mounted) await neEkeyim(context, durum, adlar[s]!);
}

class TarlalarSayfasi extends StatefulWidget {
  const TarlalarSayfasi({super.key, required this.durum});
  final Durum durum;

  @override
  State<TarlalarSayfasi> createState() => _TarlalarSayfasiState();
}

class _TarlalarSayfasiState extends State<TarlalarSayfasi> {
  String _filtre = 'Hepsi';
  String _ara = '';

  Durum get durum => widget.durum;

  bool _uyar(Veriler v, Kayit t) {
    final yil = DateTime.now().year;
    final p = v.tarlaYilPaylari(t.id, yil);
    final m = v.araziDurumu(t.id, yil);
    switch (_filtre) {
      case 'Hepsi':
        return true;
      case 'Benim ektiklerim':
        return p.containsKey(Veriler.ben) && !v.kirayaVerildi(t.id, yil);
      case 'Kiraladıklarımız':
        return m == 'Kiralık' || m.startsWith('Hazine');
      case 'Başkasına verilenler':
        return v.kirayaVerildi(t.id, yil);
      case 'ÇKS bizde olmayanlar':
        return v.cksSahibi(t.id, yil) == cksBizdeDegil;
      default:
        return p.containsKey(_filtre);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Sayfa(
      baslik: 'Tarlalarım',
      durum: durum,
      fab: ekleButonu('Tarla Ekle', () => tarlaFormu(context, durum)),
      builder: (context, v) {
        final yil = DateTime.now().year;
        final ekiliIds = {
          for (final e in v.ekimler)
            if (e.t('yil') == yil && Veriler.ekili(e)) e.s('tarlaId')
        };
        double da(Iterable<Kayit> l) => l.fold(0.0, (a, t) => a + t.n('dekar'));
        final ekili = v.tarlalar.where((t) => ekiliIds.contains(t.id));
        final bos = v.tarlalar.where((t) => !ekiliIds.contains(t.id));
        final filtreler = [
          'Hepsi',
          'Benim ektiklerim',
          ...v.sahipler().where((s) => s != Veriler.ben),
          'Kiraladıklarımız',
          'Başkasına verilenler',
          'ÇKS bizde olmayanlar',
        ];
        final a = araMetni(_ara);
        final liste = v.tarlalar
            .where((t) => _uyar(v, t))
            .where((t) =>
                a.isEmpty ||
                araMetni('${t.s('ad')} ${t.s('mahalle')} ${t.s('ada')}/${t.s('parsel')}')
                    .contains(a))
            .toList()
          ..sort((x, y) => v.tarlaAdi(x.id).compareTo(v.tarlaAdi(y.id)));
        return [
          Panel(
            child: Column(
              children: [
                const Text('🗺️', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: BilgiKutu(
                          baslik: 'Boş tarlalar ($yil)',
                          deger: '${bos.length} · ${sayi(da(bos))} da'),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: BilgiKutu(
                          baslik: 'Ekili tarlalar',
                          deger: '${ekili.length} · ${sayi(da(ekili))} da'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SecimSatiri(
            secenekler: filtreler,
            secili: filtreler.contains(_filtre) ? _filtre : 'Hepsi',
            onSec: (s) => setState(() => _filtre = s),
          ),
          const SizedBox(height: 8),
          if (v.tarlalar.length > 5)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(
                decoration: const InputDecoration(
                    hintText: 'Ara (ad, köy, ada/parsel)...',
                    prefixIcon: Icon(Icons.search)),
                onChanged: (s) => setState(() => _ara = s),
              ),
            ),
          if (v.tarlalar.isEmpty)
            BosDurum(
              simge: '🌾',
              yazi: 'Henüz tarla yok. Parsellerinizi ekleyin; ÇKS\'deki ada/parsel ve dekar bilgisi yeterli.',
              butonYazi: 'Tarla Ekle',
              onTap: () => tarlaFormu(context, durum),
            )
          else if (liste.isEmpty)
            const BosDurum(simge: '🔎', yazi: 'Bu filtrede tarla yok.'),
          for (final t in liste) _tarlaKarti(context, v, t, yil),
        ];
      },
    );
  }

  Widget _tarlaKarti(BuildContext context, Veriler v, Kayit t, int yil) {
    final gecmis = v.urunGecmisi(t);
    final yillar = gecmis.keys.toList()..sort((a, b) => b.compareTo(a));
    final buYilEkim = v.tarlaEkimleri(t.id).where((e) => e.t('yil') == yil).toList();
    final buYilPlanli = buYilEkim.isNotEmpty && buYilEkim.every((e) => !Veriler.ekili(e));
    final buYilUrun = gecmis[yil];
    final planlar = v.planliEkimler(t.id, yil + 1);
    // Tarla bölünerek ekildiyse ürünün yanında alanı da yazılır.
    String urunYazi(Kayit e) =>
        e.n('dekar') > 0 ? '${e.s('urun')} ${sayi(e.n('dekar'))} da' : e.s('urun');
    final buYilYazi = buYilEkim.isEmpty
        ? buYilUrun
        : buYilEkim.map(urunYazi).join(', ');
    final verildi = v.kirayaVerildi(t.id, yil);
    final paylar = verildi ? {baskasi: 1.0} : v.tarlaYilPaylari(t.id, yil);
    final eken = paylar.length == 1 ? paylar.keys.first : null;
    final m = buYilUrun == null ? null : v.munavebe(t, buYilUrun, yil);
    final ekimler = v.tarlaEkimleri(t.id);
    final kira = v.yillikKira(t.id, yil);
    final arazi = v.araziDurumu(t.id, yil);
    final cks = v.cksSahibi(t.id, yil);
    final buEkim = v.yilEkimi(t.id, yil);
    final kiraci = (buEkim?.s('kiraci').isNotEmpty ?? false) ? buEkim!.s('kiraci') : t.s('kiraci');
    final kiraGeliri = buEkim != null && buEkim.s('sahip') == baskasi
        ? buEkim.n('kiraGeliri')
        : t.n('kiraGeliri');
    return Panel(
        onTap: () => tarlaFormu(context, durum, tarla: t),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(v.tarlaAdi(t.id),
                      style: const TextStyle(
                          color: Renk.yazi, fontSize: 19, fontWeight: FontWeight.w800)),
                ),
                Text(
                  [t.s('mahalle'), t.s('ilce')].where((x) => x.isNotEmpty).join('/'),
                  style: const TextStyle(color: Renk.yazi, fontSize: 14),
                ),
                const Text(' 📍'),
              ],
            ),
            const Divider(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Renk.zeminAlt,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Renk.cizgi, width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Text(buYilUrun == null ? '🟫' : urunSimge(buYilUrun),
                      style: const TextStyle(fontSize: 38)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: [
                      Satir('Ada / Parsel', '${t.s('ada').isEmpty ? '-' : t.s('ada')} / ${t.s('parsel').isEmpty ? '-' : t.s('parsel')}'),
                      Satir('Alan', '${sayi(t.n('dekar'))} dekar'),
                      Satir('Arazi', arazi),
                      if (kira > 0) Satir(kiraKalemi(arazi), tl0(kira)),
                      Satir('$yil',
                          buYilUrun == null
                              ? 'Ekilmedi'
                              : (buYilPlanli ? '$buYilYazi (planlanıyor)' : buYilYazi!),
                          renk: buYilUrun == null ? Renk.soluk : Renk.altin),
                      for (final p in planlar)
                        Satir('${p.t('yil')} planı', urunYazi(p), renk: Renk.turkuaz),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Etiket('ÇKS: ${cks.isEmpty ? '-' : cks}', renk: Renk.mor),
                Etiket(
                    verildi
                        ? 'Eken: ${kiraci.isEmpty ? baskasi : kiraci}'
                        : (eken == null
                            ? 'Ortak: ${paylar.entries.map((e) => '${e.key} %${(e.value * 100).round()}').join(', ')}'
                            : 'Eken: $eken'),
                    renk: eken == Veriler.ben ? Renk.yesilKoyu : Renk.maviKoyu),
                if (verildi && kiraGeliri > 0)
                  Etiket('Kira geliri ${tl0(kiraGeliri)}', renk: Renk.turkuaz),
              ],
            ),
            if (yillar.any((y) => y < yil)) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final y in yillar.where((y) => y < yil).take(4))
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Renk.zeminAlt,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Renk.cizgi),
                      ),
                      child: Text('$y ${urunSimge(gecmis[y]!)} ${gecmis[y]}',
                          style: const TextStyle(color: Renk.soluk, fontSize: 12.5)),
                    ),
                ],
              ),
            ],
            if (m != null) ...[
              const SizedBox(height: 8),
              MunavebeSatiri(m),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Buton(
                    yazi: ekimler.any((e) => e.t('yil') == yil) ? 'Tarlayı Yönet' : 'Ekim Gir',
                    yukseklik: 44,
                    onTap: () {
                      final buYil = ekimler.where((e) => e.t('yil') == yil).toList();
                      if (buYil.isEmpty) {
                        ekimFormu(context, durum, tarlaId: t.id);
                      } else {
                        git(context, EkimDetay(durum: durum, ekimId: buYil.first.id));
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
    );
  }
}
