import 'package:flutter/material.dart';

import '../bicim.dart';
import '../hesap.dart';
import '../modeller.dart';
import '../sabitler.dart';
import '../servis/keles.dart';
import '../servis/veri.dart';
import '../tema.dart';
import 'form.dart';
import 'kabuk.dart';

double _n(Object? v) => v is num ? v.toDouble() : 0;

String ekimEtiketi(Veriler v, Kayit e) =>
    '${e.t('yil')} · ${e.s('urun')} · ${v.tarlaTam(e.s('tarlaId'))} (${v.ekimSahipYazisi(e)})';

/// Kesinti oranlarını satış yerine göre doldurur.
void _oranlariDoldur(Veriler v, Map<String, dynamic> d) {
  final i = v.isletme;
  final yer = (d['yer'] ?? '').toString();
  final borsa = borsalar.contains(yer);
  final tmo = yer == 'TMO';
  d['stopaj'] = (borsa || tmo) ? (i?.stopajBorsa ?? 1) : (i?.stopajDisi ?? 2);
  d['tescil'] = borsa ? (i?.tescilBinde ?? 2) : 0;
  d['sgk'] = i?.sgk ?? 2;
}

/// Ürün satışı (ya da [diger] ise saman, balya, hurda gibi diğer satış).
Future<void> satisFormu(BuildContext context, Durum durum,
    {Kayit? satis, String? ekimId, bool diger = false, String? urun, String? yer}) {
  final v = durum.v;
  final digerMi = satis != null ? satis.s('tur') == 'diger' : diger;
  final ekimler = [...v.ekimler]..sort((a, b) => b.t('yil').compareTo(a.t('yil')));
  final ekimEtiketleri = {for (final e in ekimler) ekimEtiketi(v, e): e.id};
  final alicilar = <String>{
    for (final s in v.satislar)
      if (s.s('alici').isNotEmpty) s.s('alici')
  }.toList();
  final bas = <String, dynamic>{
    'tarih': DateTime.now().millisecondsSinceEpoch,
    'yer': yer ?? (digerMi ? 'Diğer' : 'Tüccar'),
    'tur': digerMi ? 'diger' : 'urun',
    if (urun != null) 'urun': urun,
    if (yer == 'Şeker Fabrikası') 'alici': 'Ereğli Şeker Fabrikası',
    ...?satis?.d,
  };
  if (satis == null) _oranlariDoldur(v, bas);
  String kotaEtiketi(Kayit k) =>
      '${k.t('yil')} · ${k.s('sahibi')} · ${sayi(k.n('ton'))} ton${k.b('kiralik') ? ' (kiralık)' : ''}';
  final kotaEtiketleri = {for (final k in v.kotalar) kotaEtiketi(k): k.id};
  final kotaId = satis?.s('kotaId') ?? '';
  for (final e in kotaEtiketleri.entries) {
    if (e.value == kotaId) bas['kota'] = e.key;
  }
  final eid = ekimId ?? satis?.s('ekimId') ?? '';
  for (final e in ekimEtiketleri.entries) {
    if (e.value == eid) {
      bas['ekim'] = e.key;
      bas['urun'] ??= v.bul('ekimler', eid)?.s('urun');
    }
  }
  if (digerMi) {
    return formAc(
      context,
      baslik: satis == null ? 'Diğer Satış' : 'Satışı Düzenle',
      v: v,
      baslangic: bas,
      alanlar: [
        const Alan('aciklama', 'Ne satıldı', zorunlu: true,
            oneriler: ['Saman', 'Balya', 'Hurda', 'İkinci el makine', 'Hayvan', 'Makine kirası']),
        Alan('alici', 'Kime', oneriler: alicilar),
        const Alan('kg', 'Miktar', tip: AlanTip.sayi, birim: 'kg / adet'),
        const Alan('fiyat', 'Birim fiyat', tip: AlanTip.sayi, birim: '₺'),
        const Alan('tutar', 'Toplam tutar', tip: AlanTip.sayi, birim: '₺', zorunlu: true),
        const Alan('tarih', 'Tarih', tip: AlanTip.tarih),
        const Alan('tarlaId', 'Tarladan çıktıysa (saman, balya)', tip: AlanTip.tarla),
      ],
      degisince: (k, d) {
        if (k == 'kg' || k == 'fiyat') {
          final t = _n(d['kg']) * _n(d['fiyat']);
          if (t > 0) d['tutar'] = t;
        }
      },
      onKaydet: (d) async {
        d['tur'] = 'diger';
        d['yil'] = DateTime.fromMillisecondsSinceEpoch(_n(d['tarih']).toInt()).year;
        // Diğer satışlarda fiyat × miktar yerine toplam tutar esas.
        if (_n(d['kg']) * _n(d['fiyat']) <= 0) {
          d['kg'] = 0;
          d['fiyat'] = 0;
        }
        await durum.kaydet('satislar', d, id: satis?.id);
      },
      onSil: satis == null ? null : () => durum.sil('satislar', satis.id),
    );
  }
  return formAc(
    context,
    baslik: satis == null ? 'Satış' : 'Satışı Düzenle',
    v: v,
    baslangic: bas,
    alanlar: [
      Alan('ekim', 'Hangi hasattan', tip: AlanTip.secim,
          secenekler: ['', ...ekimEtiketleri.keys],
          aciklama: 'Seçerseniz satış o tarlanın kârına yazılır.'),
      Alan('urun', 'Ürün', tip: AlanTip.secim,
          secenekler: [for (final u in urunler) u.ad], zorunlu: true),
      Alan('alici', 'Alıcı (tüccar / fabrika)', oneriler: alicilar, zorunlu: true),
      const Alan('yer', 'Satış yeri', tip: AlanTip.secim, secenekler: satisYerleri),
      if (kotaEtiketleri.isNotEmpty)
        Alan('kota', 'Hangi kotadan', tip: AlanTip.secim,
            secenekler: ['', ...kotaEtiketleri.keys],
            gorunur: (d) => d['urun'] == 'Şeker Pancarı'),
      const Alan('tarih', 'Tarih', tip: AlanTip.tarih),
      const Alan('kg', 'Miktar', tip: AlanTip.sayi, birim: 'kg', zorunlu: true),
      const Alan('fiyat', 'Fiyat', tip: AlanTip.sayi, birim: '₺/kg', zorunlu: true),
      const Alan('stopaj', 'Stopaj', tip: AlanTip.sayi, birim: '%'),
      const Alan('tescil', 'Borsa tescil ücreti', tip: AlanTip.sayi, birim: '‰ (binde)'),
      const Alan('sgk', 'SGK / Bağ-Kur kesintisi', tip: AlanTip.sayi, birim: '%'),
      const Alan('nakliye', 'Nakliye gideri', tip: AlanTip.sayi, birim: '₺'),
      const Alan('sozlesmeli', 'Henüz teslim edilmedi (sözleşmeli)',
          tip: AlanTip.anahtar,
          ipucu: 'Pancar gibi; avanslar geldikçe Ödemeler bölümünden girilir.'),
      const Alan('aciklama', 'Not', tip: AlanTip.uzun),
    ],
    degisince: (k, d) {
      if (k == 'yer') _oranlariDoldur(v, d);
      if (k == 'ekim') {
        final e = v.bul('ekimler', ekimEtiketleri[d['ekim']] ?? '');
        if (e != null) d['urun'] = e.s('urun');
      }
    },
    ozet: (d) {
      final h = satisHesapla(
        kg: _n(d['kg']),
        fiyat: _n(d['fiyat']),
        stopajYuzde: _n(d['stopaj']),
        tescilBinde: _n(d['tescil']),
        sgkYuzde: _n(d['sgk']),
        nakliye: _n(d['nakliye']),
      );
      return Column(
        children: [
          Satir('Brüt tutar', tl(h.tutar)),
          Satir('Stopaj', '- ${tl(h.stopaj)}'),
          Satir('Borsa tescil', '- ${tl(h.tescil)}'),
          Satir('SGK kesintisi', '- ${tl(h.sgk)}'),
          Satir('Alıcıdan beklenen', tl(h.beklenen), kalin: true),
          if (h.nakliye > 0) Satir('Nakliye', '- ${tl(h.nakliye)}'),
          Satir('Cebe kalan', tl(h.net), kalin: true, renk: Renk.yesil),
        ],
      );
    },
    onKaydet: (d) async {
      final kotaE = (d.remove('kota') ?? '').toString();
      d['kotaId'] = d['urun'] == 'Şeker Pancarı' ? (kotaEtiketleri[kotaE] ?? '') : '';
      final etiket = (d.remove('ekim') ?? '').toString();
      final e = v.bul('ekimler', ekimEtiketleri[etiket] ?? '');
      d['ekimId'] = e?.id ?? '';
      d['tarlaId'] = e?.s('tarlaId') ?? '';
      d['tur'] = 'urun';
      d['yil'] = e?.t('yil') ??
          DateTime.fromMillisecondsSinceEpoch(_n(d['tarih']).toInt()).year;
      d['tutar'] = _n(d['kg']) * _n(d['fiyat']);
      await durum.kaydet('satislar', d, id: satis?.id);
    },
    onSil: satis == null ? null : () => durum.sil('satislar', satis.id),
  );
}

/// Satışa ödeme (avans, ürün bedeli...) ekler.
Future<void> tahsilatEkle(BuildContext context, Durum durum, Kayit satis) {
  final v = durum.v;
  final kalan = v.satisHesap(satis).kalan(tahsilToplam(satis));
  return formAc(
    context,
    baslik: 'Ödeme Girişi',
    v: v,
    baslangic: {
      'tur': satis.b('sozlesmeli') ? 'Avans' : 'Ürün bedeli',
      'banka': satis.s('yer') == 'Şeker Fabrikası' ? 'Vakıfbank' : 'Nakit',
      'tarih': DateTime.now().millisecondsSinceEpoch,
      'alan': Veriler.ben,
      if (kalan > 0) 'tutar': double.parse(kalan.toStringAsFixed(2)),
    },
    alanlar: [
      const Alan('tur', 'Ödeme türü', tip: AlanTip.secim, secenekler: tahsilatTurleri),
      const Alan('tutar', 'Tutar', tip: AlanTip.sayi, birim: '₺', zorunlu: true),
      Alan('alan', 'Para kime yattı / kim aldı', tip: AlanTip.secim,
          secenekler: v.sahipler(),
          aciklama: 'Satış kimin olursa olsun, parayı alan kişinin hesabına geçer.'),
      const Alan('banka', 'Nereye yattı', tip: AlanTip.secim, secenekler: bankalar),
      const Alan('tarih', 'Tarih', tip: AlanTip.tarih),
      const Alan('ac', 'Not'),
    ],
    onKaydet: (d) async {
      final l = [...satis.liste('tahsilatlar'), d];
      await durum.kaydet('satislar', {'tahsilatlar': l}, id: satis.id);
    },
  );
}

class SatislarSayfasi extends StatefulWidget {
  const SatislarSayfasi({super.key, required this.durum});
  final Durum durum;

  @override
  State<SatislarSayfasi> createState() => _SatislarSayfasiState();
}

class _SatislarSayfasiState extends State<SatislarSayfasi> {
  int _yil = DateTime.now().year;
  String _kisi = 'Hepsi';

  Durum get durum => widget.durum;

  @override
  Widget build(BuildContext context) {
    return Sayfa(
      baslik: 'Satışlarım',
      durum: durum,
      fab: ekleButonu('Satış Ekle', () => satisFormu(context, durum)),
      builder: (context, v) {
        final yillar = v.yillar(DateTime.now().year);
        final kisiler = ['Hepsi', ...v.sahipler()];
        final l = v.satislar
            .where((s) => s.s('tur') != 'diger' && s.yil == _yil)
            .where((s) => _kisi == 'Hepsi' || (v.satisPaylari(s)[_kisi] ?? 0) > 0)
            .toList();
        final gruplar = <String, List<Kayit>>{};
        for (final s in l) {
          gruplar.putIfAbsent(s.s('alici').isEmpty ? 'Belirsiz' : s.s('alici'), () => []).add(s);
        }
        double toplam(Iterable<Kayit> x) => x.fold(0.0, (a, s) => a + v.satisHesap(s).beklenen);
        double tahsil(Iterable<Kayit> x) => x.fold(0.0, (a, s) => a + tahsilToplam(s));
        final kg = l.fold(0.0, (a, s) => a + s.n('kg'));
        final sirali = gruplar.entries.toList()
          ..sort((a, b) => toplam(b.value).compareTo(toplam(a.value)));
        return [
          SecimSatiri(
            secenekler: [for (final y in yillar) '$y'],
            etiket: 'Yıl',
            secili: '$_yil',
            onSec: (s) => setState(() => _yil = int.parse(s)),
          ),
          const SizedBox(height: 8),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('$_yil satışları', style: yaziKalin),
                Text('${l.length} satış · ${sayi(kg / 1000)} ton', style: yaziSoluk),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: BilgiKutu(baslik: 'Toplam', deger: tl0(toplam(l)))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: BilgiKutu(
                            baslik: 'Bekleyen',
                            deger: tl0((toplam(l) - tahsil(l)).clamp(0, double.infinity)),
                            renk: Renk.kirmizi)),
                  ],
                ),
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: () => git(context, KelesAktar(durum: durum)),
                  icon: const Icon(Icons.download),
                  label: const Text('Keleş Satış\'tan aktar'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          KisiSecici(
            kisiler: kisiler,
            secili: _kisi,
            onSec: (s) => setState(() => _kisi = s),
          ),
          const SizedBox(height: 10),
          if (l.isEmpty)
            const BosDurum(simge: '🚛', yazi: 'Bu yıl satış yok.'),
          for (final g in sirali) _aliciKarti(context, v, g.key, g.value),
        ];
      },
    );
  }

  Widget _aliciKarti(BuildContext context, Veriler v, String alici, List<Kayit> l) {
    final toplam = l.fold(0.0, (a, s) => a + v.satisHesap(s).beklenen);
    final tahsil = l.fold(0.0, (a, s) => a + tahsilToplam(s));
    final kg = l.fold(0.0, (a, s) => a + s.n('kg'));
    final brut = l.fold(0.0, (a, s) => a + v.satisHesap(s).tutar);
    final urunAdlari = {for (final s in l) s.s('urun')}.toList();
    final kalan = (toplam - tahsil).clamp(0, double.infinity).toDouble();
    final yerler = {for (final s in l) s.s('yer')}.where((x) => x.isNotEmpty).join(', ');
    return Panel(
      padding: const EdgeInsets.all(14),
      onTap: () => git(context, AliciDetay(durum: durum, alici: alici, yil: _yil)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.storefront, color: Renk.soluk),
              const SizedBox(width: 6),
              Expanded(
                child: Text(alici,
                    style: const TextStyle(
                        color: Renk.yazi, fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              Text(yerler, style: yaziSoluk),
            ],
          ),
          const Divider(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final u in urunAdlari)
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Renk.zeminAlt,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Renk.cizgi, width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Text(urunSimge(u), style: const TextStyle(fontSize: 28)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Satir('Miktar', '${sayi(kg)} kg'),
          if (kg > 0) Satir('Ortalama fiyat', '${tl(brut / kg)}/kg'),
          Satir('Toplam (kesintiler düşülmüş)', tl0(toplam), kalin: true),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: kalan < 1
                ? const Etiket('Ödendi', renk: Renk.yesil, simge: '✔')
                : (tahsil > 0
                    ? Etiket('Kısmen ödendi · kalan ${tl0(kalan)}', renk: Renk.turuncu)
                    : Etiket('Bekliyor · ${tl0(kalan)}', renk: Renk.kirmizi)),
          ),
        ],
      ),
    );
  }
}

/// Bir alıcıya yapılan satışlar ve ödemeleri.
class AliciDetay extends StatelessWidget {
  const AliciDetay({super.key, required this.durum, required this.alici, required this.yil});
  final Durum durum;
  final String alici;
  final int yil;

  @override
  Widget build(BuildContext context) {
    return Sayfa(
      baslik: alici,
      durum: durum,
      builder: (context, v) {
        final l = v.satislar
            .where((s) =>
                s.s('tur') != 'diger' &&
                s.yil == yil &&
                (s.s('alici').isEmpty ? 'Belirsiz' : s.s('alici')) == alici)
            .toList()
          ..sort((a, b) => b.t('tarih').compareTo(a.t('tarih')));
        return [
          for (final s in l) SatisKarti(durum: durum, v: v, satis: s),
          if (l.isEmpty) const BosDurum(simge: '🗑️', yazi: 'Satış kalmadı.'),
        ];
      },
    );
  }
}

class SatisKarti extends StatelessWidget {
  const SatisKarti({super.key, required this.durum, required this.v, required this.satis});
  final Durum durum;
  final Veriler v;
  final Kayit satis;

  @override
  Widget build(BuildContext context) {
    final s = satis;
    final h = v.satisHesap(s);
    final tahsil = tahsilToplam(s);
    final ekim = v.bul('ekimler', s.s('ekimId'));
    return Panel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(urunSimge(s.s('urun')), style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${s.s('urun')} · ${sayi(s.n('kg'))} kg',
                        style: yaziKalin),
                    Text(
                        [
                          tarih(s.t('tarih')),
                          s.s('yer'),
                          if (ekim != null) v.tarlaTam(ekim.s('tarlaId')),
                          v.satisSahibi(s),
                          if (s.b('sozlesmeli')) 'sözleşmeli',
                          if (s.s('kelesId').isNotEmpty) 'Keleş Satış',
                        ].where((x) => x.isNotEmpty).join(' · '),
                        style: yaziSoluk),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Renk.soluk),
                onPressed: () => satisFormu(context, durum, satis: s),
              ),
            ],
          ),
          const Divider(height: 14),
          Satir('Fiyat', '${tl(s.n('fiyat'))}/kg'),
          Satir('Brüt', tl(h.tutar)),
          Satir('Kesintiler', '- ${tl(h.kesinti)}'),
          Satir('Beklenen', tl(h.beklenen), kalin: true),
          for (final o in s.liste('tahsilatlar'))
            Satir(
                '${o['tur'] ?? 'Ödeme'} · ${o['banka'] ?? ''} · ${tarih(_n(o['t'] ?? o['tarih']).toInt())}',
                tl(_n(o['tutar'])),
                renk: Renk.yesil),
          if (s.n('tahsil') > 0) Satir('Tahsil edilen', tl(s.n('tahsil')), renk: Renk.yesil),
          Satir('Kalan', tl(h.kalan(tahsil)),
              kalin: true, renk: h.kalan(tahsil) < 1 ? Renk.yesil : Renk.kirmizi),
          const SizedBox(height: 8),
          Buton(
            yazi: 'Ödeme Gir (avans / bedel)',
            renk: ButonRenk.yesil,
            yukseklik: 44,
            onTap: () => tahsilatEkle(context, durum, s),
          ),
        ],
      ),
    );
  }
}

/// Keleş Satış'taki satışları Bereket'e aktarma.
class KelesAktar extends StatefulWidget {
  const KelesAktar({super.key, required this.durum});
  final Durum durum;

  @override
  State<KelesAktar> createState() => _KelesAktarState();
}

class _KelesAktarState extends State<KelesAktar> {
  late Future<List<KelesSiparis>> _yukle = Keles.siparisler(widget.durum.uid);
  bool _gizlileriGoster = false;

  Durum get durum => widget.durum;

  List<String> _gizli(Veriler v) {
    final g = v.isletme?.ayarlar['kelesGizli'];
    return g is List ? [for (final x in g) x.toString()] : <String>[];
  }

  final Set<String> _secili = {};
  bool _islem = false;

  /// Ürün adı tutan ekimler (yeni yıl önce).
  List<Kayit> _uygunEkimler(Veriler v, KelesSiparis k) {
    final ekimler = [...v.ekimler]..sort((a, b) => b.t('yil').compareTo(a.t('yil')));
    final ilk = araMetni(k.urun).split(' ').first;
    return ekimler.where((e) => araMetni(e.s('urun')).contains(ilk)).toList();
  }

  /// Toplu aktarımda ekim: satış yılındaki aynı ürünlü ekim, yoksa en yakın önceki.
  Kayit? _otomatikEkim(Veriler v, KelesSiparis k) {
    final yil = DateTime.fromMillisecondsSinceEpoch(k.tarih).year;
    final l = _uygunEkimler(v, k).where((e) => e.t('yil') <= yil).toList();
    if (l.isEmpty) return null;
    final buYil = l.where((e) => e.t('yil') == yil).toList();
    // Aynı yıl birden çok tarla varsa tarla belirsiz: tarlasız al.
    if (buYil.length > 1) return null;
    return buYil.isNotEmpty ? buYil.first : (l.first.t('yil') == yil - 1 ? l.first : null);
  }

  Map<String, dynamic> _satisVerisi(KelesSiparis k, Kayit? e) {
    final i = durum.v.isletme;
    return {
      'tur': 'urun',
      'kelesId': k.id,
      'ekimId': e?.id ?? '',
      'tarlaId': e?.s('tarlaId') ?? '',
      'urun': e?.s('urun') ?? k.urun,
      'alici': k.musteri,
      'yer': 'Tüccar',
      'tarih': k.tarih,
      'yil': e?.t('yil') ?? DateTime.fromMillisecondsSinceEpoch(k.tarih).year,
      'kg': k.kg,
      'fiyat': k.kgFiyat,
      'tutar': k.tutar,
      'stopaj': i?.stopajDisi ?? 2,
      'tescil': 0,
      'sgk': i?.sgk ?? 2,
      'tahsilatlar': [
        if (k.tahsil > 0)
          {'tur': 'Keleş Satış tahsilatı', 'tutar': k.tahsil, 'banka': '', 't': k.tarih}
      ],
    };
  }

  /// Seçilenleri tek seferde Bereket'e al.
  Future<void> _topluAl(List<KelesSiparis> secilenler) async {
    final v = durum.v;
    final secim = await secimYap(context, '${secilenler.length} satış hangi hasattan?', [
      'Ürüne göre otomatik eşleştir',
      'Tarla belirtmeden al',
    ]);
    if (secim == null) return;
    final otomatik = secim.startsWith('Ürüne');
    setState(() => _islem = true);
    var n = 0, eslesen = 0;
    try {
      final veriler = <Map<String, dynamic>>[];
      for (final k in secilenler) {
        final e = otomatik ? _otomatikEkim(v, k) : null;
        if (e != null) eslesen++;
        veriler.add(_satisVerisi(k, e));
      }
      // 400'erli gruplar hâlinde yaz.
      for (var i = 0; i < veriler.length; i += 400) {
        final grup = veriler.sublist(i, i + 400 > veriler.length ? veriler.length : i + 400);
        await Veri.topluEkle(durum.iid, 'satislar', grup, uid: durum.uid);
        n += grup.length;
      }
      _secili.clear();
      if (mounted) {
        bildir(context,
            '$n satış alındı${otomatik ? ' ($eslesen tanesi tarlasıyla eşleşti)' : ''}.');
      }
    } catch (err) {
      if (mounted) bildir(context, hataYazisi(err));
    } finally {
      if (mounted) setState(() => _islem = false);
    }
  }

  /// Seçilenleri "Ticari" diye gizle.
  Future<void> _topluGizle(List<KelesSiparis> secilenler) async {
    final l = {..._gizli(durum.v), for (final k in secilenler) k.id}.toList();
    try {
      await durum.ayarYaz('kelesGizli', l);
      setState(_secili.clear);
    } catch (e) {
      if (mounted) bildir(context, hataYazisi(e));
    }
  }

  /// Daha önce alınan satışları Keleş Satış'taki son hâline getirir
  /// (miktar, fiyat, tahsilat değiştiyse).
  Future<void> _guncelle(List<(Kayit, KelesSiparis)> degisen) async {
    setState(() => _islem = true);
    try {
      for (final (s, k) in degisen) {
        final tah = [
          for (final o in s.liste('tahsilatlar'))
            if (o['tur'] != 'Keleş Satış tahsilatı') o,
          if (k.tahsil > 0)
            {'tur': 'Keleş Satış tahsilatı', 'tutar': k.tahsil, 'banka': '', 't': k.tarih},
        ];
        await durum.kaydet(
            'satislar',
            {
              'alici': k.musteri,
              'kg': k.kg,
              'fiyat': k.kgFiyat,
              'tutar': k.tutar,
              'tahsilatlar': tah,
            },
            id: s.id);
      }
      if (mounted) bildir(context, '${degisen.length} satış güncellendi.');
    } catch (err) {
      if (mounted) bildir(context, hataYazisi(err));
    } finally {
      if (mounted) setState(() => _islem = false);
    }
  }

  static double _kelesTahsil(Kayit s) {
    var t = 0.0;
    for (final o in s.liste('tahsilatlar')) {
      if (o['tur'] == 'Keleş Satış tahsilatı' && o['tutar'] is num) t += (o['tutar'] as num).toDouble();
    }
    return t;
  }

  Future<void> _kendiUrunum(KelesSiparis k) async {
    final v = durum.v;
    final ekimler = [...v.ekimler]..sort((a, b) => b.t('yil').compareTo(a.t('yil')));
    final uygun = _uygunEkimler(v, k);
    final liste = uygun.isNotEmpty ? uygun : ekimler;
    final etiketler = {for (final e in liste) ekimEtiketi(v, e): e};
    final secim = await secimYap(context, 'Hangi hasattan satıldı?',
        ['Tarla belirtmeden al', ...etiketler.keys]);
    if (secim == null) return;
    final e = etiketler[secim];
    try {
      await durum.kaydet('satislar', _satisVerisi(k, e));
      if (mounted) bildir(context, 'Satış Bereket\'e alındı.');
    } catch (err) {
      if (mounted) bildir(context, hataYazisi(err));
    }
  }

  /// Keleş Satış hesabıyla giriş penceresi (Keleş Satış ayrı Firebase projesinde).
  Future<void> _kelesGiris() async {
    final eposta = TextEditingController();
    final sifre = TextEditingController();
    final tamam = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keleş Satış girişi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: eposta,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'E-posta'),
            ),
            TextField(
              controller: sifre,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Şifre'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Giriş')),
        ],
      ),
    );
    final e = eposta.text.trim(), p = sifre.text;
    eposta.dispose();
    sifre.dispose();
    if (tamam != true || e.isEmpty || p.isEmpty) return;
    try {
      await Keles.girisYap(e, p);
      if (mounted) setState(() => _yukle = Keles.siparisler(durum.uid));
    } catch (err) {
      if (mounted) bildir(context, hataYazisi(err));
    }
  }

  Future<void> _gizle(KelesSiparis k, bool gizle) async {
    final l = _gizli(durum.v);
    if (gizle) {
      l.add(k.id);
    } else {
      l.remove(k.id);
    }
    try {
      await durum.ayarYaz('kelesGizli', l);
    } catch (e) {
      if (mounted) bildir(context, hataYazisi(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Keleş Satış\'tan Al'),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() => _yukle = Keles.siparisler(durum.uid)),
          ),
        ],
      ),
      body: FutureBuilder<List<KelesSiparis>>(
        future: _yukle,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            final girisGerekli = snap.error is KelesGirisGerekli;
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(girisGerekli ? snap.error.toString() : hataYazisi(snap.error!),
                        textAlign: TextAlign.center, style: const TextStyle(color: Renk.yazi)),
                    if (girisGerekli) ...[
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _kelesGiris,
                        icon: const Icon(Icons.login),
                        label: const Text('Keleş Satış\'a giriş yap'),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }
          return Canli(
            durum: durum,
            builder: (context, v) {
              final alinan = {for (final s in v.satislar) s.s('kelesId')};
              final gizli = _gizli(v).toSet();
              final l = snap.data!
                  .where((k) => !alinan.contains(k.id))
                  .where((k) => _gizlileriGoster || !gizli.contains(k.id))
                  .toList();
              _secili.removeWhere((id) => !l.any((k) => k.id == id));
              final secilenler = l.where((k) => _secili.contains(k.id)).toList();
              // Daha önce alınmış, Keleş'te sonradan değişmiş satışlar.
              final kMap = {for (final k in snap.data!) k.id: k};
              final degisen = <(Kayit, KelesSiparis)>[
                for (final s in v.satislar)
                  if (kMap[s.s('kelesId')] case final k?)
                    if ((s.n('kg') - k.kg).abs() > 0.01 ||
                        (s.n('tutar') - k.tutar).abs() > 0.5 ||
                        (_kelesTahsil(s) - k.tahsil).abs() > 0.5)
                      (s, k),
              ];
              return Column(
                children: [
                  Expanded(
                    child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 40),
                children: [
                  if (degisen.isNotEmpty)
                    Panel(
                      kenarRengi: Renk.turuncu,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('${degisen.length} satış Keleş Satış\'ta değişmiş', style: yaziKalin),
                          const Text(
                              'Daha önce aldığınız satışların miktarı, fiyatı ya da tahsilatı '
                              'güncellenmiş. Tek dokunuşla Bereket\'e çekin.',
                              style: yaziSoluk),
                          const SizedBox(height: 8),
                          Buton(
                            yazi: 'Değişenleri Güncelle',
                            ikon: Icons.sync,
                            renk: ButonRenk.turuncu,
                            yukseklik: 44,
                            onTap: _islem ? null : () => _guncelle(degisen),
                          ),
                        ],
                      ),
                    ),
                  const Panel(
                    child: Text(
                      'Keleş Satış\'taki satışlar burada listelenir (Bereket yalnızca okur). '
                      'Kendi tarlanızdan çıkan ürünü "Kendi ürünüm" ile alın; ticari alım-satımları '
                      '"Ticari" ile gizleyin.',
                      style: yaziSoluk,
                    ),
                  ),
                  SwitchListTile(
                    value: _gizlileriGoster,
                    onChanged: (b) => setState(() => _gizlileriGoster = b),
                    title: const Text('Ticari diye gizlenenleri de göster',
                        style: TextStyle(color: Renk.yazi)),
                  ),
                  if (l.isEmpty)
                    const BosDurum(simge: '✅', yazi: 'Aktarılacak satış kalmadı.')
                  else
                    CheckboxListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      value: secilenler.length == l.length
                          ? true
                          : (secilenler.isEmpty ? false : null),
                      tristate: true,
                      onChanged: (_) => setState(() {
                        if (secilenler.length == l.length) {
                          _secili.clear();
                        } else {
                          _secili.addAll(l.map((k) => k.id));
                        }
                      }),
                      title: Text('Tümünü seç (${l.length} satış)', style: yaziKalin),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  for (final k in l)
                    Panel(
                      padding: const EdgeInsets.all(12),
                      kenarRengi: _secili.contains(k.id) ? Renk.yesil : null,
                      onTap: () => setState(() =>
                          _secili.contains(k.id) ? _secili.remove(k.id) : _secili.add(k.id)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Checkbox(
                                value: _secili.contains(k.id),
                                onChanged: (b) => setState(
                                    () => b == true ? _secili.add(k.id) : _secili.remove(k.id)),
                              ),
                              Expanded(child: Text('#${k.no} · ${k.musteri}', style: yaziKalin)),
                            ],
                          ),
                          Text(
                              '${tarih(k.tarih)} · ${k.urun} · ${sayi(k.miktar)} ${k.birim}'
                              '${k.fiyat > 0 ? ' × ${tl(k.fiyat)}' : ''}',
                              style: yaziSoluk),
                          if (k.tutar > 0)
                            Satir('Tutar / tahsil', '${tl0(k.tutar)} / ${tl0(k.tahsil)}'),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Buton(
                                  yazi: 'Kendi ürünüm',
                                  renk: ButonRenk.yesil,
                                  yukseklik: 42,
                                  onTap: () => _kendiUrunum(k),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Buton(
                                  yazi: gizli.contains(k.id) ? 'Geri al' : 'Ticari',
                                  renk: ButonRenk.gri,
                                  yukseklik: 42,
                                  onTap: () => _gizle(k, !gizli.contains(k.id)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
                    ),
                  ),
                  if (secilenler.isNotEmpty)
                    SafeArea(
                      top: false,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                        decoration: const BoxDecoration(
                          color: Renk.kart,
                          boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 10)],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Buton(
                                yazi: _islem ? 'Aktarılıyor…' : '${secilenler.length} satışı al',
                                ikon: Icons.download_done,
                                renk: ButonRenk.yesil,
                                yukseklik: 48,
                                onTap: _islem ? null : () => _topluAl(secilenler),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: Buton(
                                yazi: 'Ticari',
                                renk: ButonRenk.gri,
                                yukseklik: 48,
                                onTap: _islem ? null : () => _topluGizle(secilenler),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
