import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdfx/pdfx.dart';

import '../bicim.dart';
import '../hesap.dart';
import '../sabitler.dart';
import '../servis/idari.dart';
import '../servis/veri.dart';
import '../tema.dart';
import 'kabuk.dart';

/// ÇKS belgesinden okunan bir parsel satırı.
class CksSatir {
  CksSatir({this.mahalle = '', this.ada = '', this.parsel = '', this.dekar = 0, this.urun = ''});
  String mahalle, ada, parsel, urun;
  double dekar;
  bool secili = true;
  String? tarlaId; // kayıtlı tarla eşleşmesi
}

/// ÇKS Yükle: belgeyi kamerayla çek, galeriden ya da dosyadan (PDF/resim)
/// seç; parseller (ada, parsel, alan, ürün) okunur, onaylananlar tarla ve
/// o sezonun ekimi olarak kaydedilir.
class CksYukle extends StatefulWidget {
  const CksYukle({super.key, required this.durum});
  final Durum durum;

  @override
  State<CksYukle> createState() => _CksYukleState();
}

class _CksYukleState extends State<CksYukle> {
  bool _okunuyor = false;
  bool _kaydediliyor = false;
  File? _resim;
  String _metin = '';
  List<CksSatir>? _satirlar;
  late int _yil = DateTime.now().month >= 8 ? DateTime.now().year + 1 : DateTime.now().year;
  String _cks = Veriler.ben;
  bool _ekimYaz = true;

  Durum get durum => widget.durum;

  Future<void> _cek(ImageSource kaynak) async {
    try {
      final x = await ImagePicker().pickImage(source: kaynak, imageQuality: 95, maxWidth: 3000);
      if (x == null) return;
      setState(() {
        _okunuyor = true;
        _resim = File(x.path);
        _satirlar = null;
      });
      await _oku([x.path]);
    } catch (e) {
      if (mounted) bildir(context, hataYazisi(e));
    } finally {
      if (mounted) setState(() => _okunuyor = false);
    }
  }

  Future<void> _dosya() async {
    try {
      final r = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );
      if (r == null || r.files.isEmpty) return;
      final f = r.files.first;
      final bytes = f.bytes;
      if (bytes == null) throw 'Dosya okunamadı.';
      setState(() {
        _okunuyor = true;
        _satirlar = null;
        _resim = null;
      });
      final gecici = Directory.systemTemp.createTempSync('cks');
      final yollar = <String>[];
      if (f.name.toLowerCase().endsWith('.pdf')) {
        final doc = await PdfDocument.openData(bytes);
        try {
          final sayfa = doc.pagesCount < 6 ? doc.pagesCount : 6;
          for (var i = 1; i <= sayfa; i++) {
            final p = await doc.getPage(i);
            try {
              final img = await p.render(
                width: p.width * 3,
                height: p.height * 3,
                format: PdfPageImageFormat.png,
                backgroundColor: '#FFFFFF',
              );
              if (img == null) continue;
              final yol = '${gecici.path}/s$i.png';
              File(yol).writeAsBytesSync(img.bytes);
              yollar.add(yol);
            } finally {
              await p.close();
            }
          }
        } finally {
          await doc.close();
        }
      } else {
        final yol = '${gecici.path}/${f.name}';
        File(yol).writeAsBytesSync(bytes);
        yollar.add(yol);
      }
      if (yollar.isEmpty) throw 'Dosyadan sayfa çıkarılamadı.';
      if (mounted) setState(() => _resim = File(yollar.first));
      await _oku(yollar);
    } catch (e) {
      if (mounted) bildir(context, hataYazisi(e));
    } finally {
      if (mounted) setState(() => _okunuyor = false);
    }
  }

  /// Yazıyı okur; tablo satırlarını yükseklik (y) konumuna göre yeniden kurar.
  Future<void> _oku(List<String> yollar) async {
    await Idari.yukle();
    final okuyucu = TextRecognizer(script: TextRecognitionScript.latin);
    final satirlar = <String>[];
    try {
      for (final y in yollar) {
        final sonuc = await okuyucu.processImage(InputImage.fromFilePath(y));
        final parcalar = <TextLine>[for (final b in sonuc.blocks) ...b.lines];
        parcalar.sort((a, b) => a.boundingBox.center.dy.compareTo(b.boundingBox.center.dy));
        final gruplar = <List<TextLine>>[];
        for (final l in parcalar) {
          final h = l.boundingBox.height;
          if (gruplar.isNotEmpty &&
              (gruplar.last.first.boundingBox.center.dy - l.boundingBox.center.dy).abs() < h * 0.6) {
            gruplar.last.add(l);
          } else {
            gruplar.add([l]);
          }
        }
        for (final g in gruplar) {
          g.sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));
          satirlar.add(g.map((l) => l.text).join(' | '));
        }
      }
    } finally {
      await okuyucu.close();
    }
    _metin = satirlar.join('\n');
    if (_metin.trim().isEmpty) {
      throw 'Belgede yazı bulunamadı. Daha aydınlık ve düz bir fotoğraf deneyin.';
    }
    final l = _coz(satirlar);
    setState(() => _satirlar = l);
  }

  static String _kucuk(String s) => s
      .replaceAll('İ', 'i')
      .replaceAll('I', 'ı')
      .toLowerCase();

  /// Türkçe sayı: "21.450,50" → 21450.5; "21450" → 21450.
  static double? _sayi(String s) {
    var t = s.trim();
    if (t.contains(',')) {
      t = t.replaceAll('.', '').replaceAll(',', '.');
    } else if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(t)) {
      t = t.replaceAll('.', '');
    }
    return double.tryParse(t);
  }

  List<CksSatir> _coz(List<String> satirlar) {
    final v = durum.v;
    // Bilinen köy/mahalle adları: kayıtlı tarlaların ilçeleri + Karapınar.
    final ilceler = <(String, String)>{
      ('Konya', 'Karapınar'),
      for (final t in v.tarlalar)
        if (t.s('ilce').isNotEmpty) (t.s('il').isEmpty ? 'Konya' : t.s('il'), t.s('ilce')),
    };
    final mahalleler = <String>{
      for (final (il, ilce) in ilceler) ...Idari.mahalleler(il, ilce),
      for (final t in v.tarlalar)
        if (t.s('mahalle').isNotEmpty) t.s('mahalle'),
    }.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    final urunAdlari = [for (final u in urunler) u.ad]..sort((a, b) => b.length.compareTo(a.length));
    final adaParsel = RegExp(r'(?<!\d)(\d{1,5})\s*[/\\]\s*(\d{1,5})(?!\d)');
    final sayiRe = RegExp(r'\d{1,3}(?:\.\d{3})+(?:,\d+)?|\d+(?:,\d+)?');

    final out = <CksSatir>[];
    for (final ham in satirlar) {
      final k = _kucuk(ham);
      final sayilar = [for (final m in sayiRe.allMatches(ham)) m.group(0)!];
      if (sayilar.length < 2) continue;
      String ada = '', parsel = '';
      final ap = adaParsel.firstMatch(ham);
      var kalan = ham;
      if (ap != null) {
        ada = ap.group(1)!;
        parsel = ap.group(2)!;
        kalan = ham.replaceRange(ap.start, ap.end, ' ');
      }
      // Alan: ondalıklı ya da en büyük sayı (m² ise dekara çevrilir).
      final adaylar = [
        for (final m in sayiRe.allMatches(kalan))
          if (_sayi(m.group(0)!) != null) (m.group(0)!, _sayi(m.group(0)!)!),
      ];
      if (ada.isEmpty) {
        // "| 1549 | 10 |" gibi ayrı sütunlar: alan olmayan ilk iki tam sayı.
        final tam = [
          for (final a in adaylar)
            if (!a.$1.contains(',') && !a.$1.contains('.') && a.$2 < 100000) a
        ];
        if (tam.length < 3) continue; // ada, parsel ve alan yoksa tablo satırı değil
        ada = tam[tam.length - 3].$1;
        parsel = tam[tam.length - 2].$1;
      }
      final alanAday = adaylar.where((a) => a.$1 != ada && a.$1 != parsel).toList()
        ..sort((a, b) => b.$2.compareTo(a.$2));
      if (alanAday.isEmpty) continue;
      var dekar = alanAday.first.$2;
      if (dekar >= 1000) dekar = dekar / 1000; // m²
      if (dekar <= 0 || dekar > 5000) continue;
      final mahalle = mahalleler.firstWhere((m) => k.contains(_kucuk(m)), orElse: () => '');
      final urun = urunAdlari.firstWhere((u) => k.contains(_kucuk(u)), orElse: () => '');
      final s = CksSatir(
          mahalle: mahalle,
          ada: ada,
          parsel: parsel,
          dekar: double.parse(dekar.toStringAsFixed(3)),
          urun: urun);
      // Aynı ada/parsel ikinci kez okunduysa atla.
      if (out.any((x) => x.ada == s.ada && x.parsel == s.parsel && x.mahalle == s.mahalle)) continue;
      s.tarlaId = _eslesen(v, s);
      out.add(s);
    }
    return out;
  }

  String? _eslesen(Veriler v, CksSatir s) {
    for (final t in v.tarlalar) {
      if (t.s('ada') == s.ada &&
          t.s('parsel') == s.parsel &&
          (s.mahalle.isEmpty || t.s('mahalle').isEmpty || t.s('mahalle') == s.mahalle)) {
        return t.id;
      }
    }
    return null;
  }

  Future<void> _kaydet() async {
    final l = (_satirlar ?? []).where((s) => s.secili).toList();
    if (l.isEmpty) return;
    setState(() => _kaydediliyor = true);
    final v = durum.v;
    var yeniTarla = 0, yeniEkim = 0;
    try {
      final ilce = v.tarlalar.isNotEmpty && v.tarlalar.first.s('ilce').isNotEmpty
          ? v.tarlalar.first.s('ilce')
          : 'Karapınar';
      final il = v.tarlalar.isNotEmpty && v.tarlalar.first.s('il').isNotEmpty
          ? v.tarlalar.first.s('il')
          : 'Konya';
      for (final s in l) {
        var id = s.tarlaId;
        if (id == null) {
          id = await durum.kaydet('tarlalar', {
            'ad': s.mahalle.isNotEmpty ? '${s.mahalle} ${s.ada}/${s.parsel}' : '${s.ada}/${s.parsel}',
            'il': il,
            'ilce': ilce,
            'mahalle': s.mahalle,
            'ada': s.ada,
            'parsel': s.parsel,
            'dekar': s.dekar,
          });
          yeniTarla++;
        }
        if (_ekimYaz && s.urun.isNotEmpty) {
          final var_ = v.ekimler.any((e) => e.s('tarlaId') == id && e.t('yil') == _yil);
          if (!var_) {
            await durum.kaydet('ekimler', {
              'tarlaId': id,
              'yil': _yil,
              'urun': s.urun,
              'durum': _yil > DateTime.now().year ? ekimPlanlaniyor : 'Ekildi',
              'cks': _cks,
              'sahip': v.tarlaSahibi(id),
            });
            yeniEkim++;
          }
        }
      }
      if (!mounted) return;
      bildir(context, '$yeniTarla yeni tarla, $yeniEkim ekim kaydedildi.');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) bildir(context, hataYazisi(e));
    } finally {
      if (mounted) setState(() => _kaydediliyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Sayfa(
      baslik: 'ÇKS Yükle',
      durum: durum,
      builder: (context, v) {
        final l = _satirlar;
        return [
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                    'ÇKS belgenizi (e-Devlet ya da Ziraat Odası çıktısı) yükleyin. Parseller '
                    'okunur, onayladıklarınız tarla ve sezonun ekimi olarak kaydedilir.',
                    style: yaziSoluk),
                const SizedBox(height: 12),
                Buton(
                  yazi: 'Kamerayla Çek',
                  ikon: Icons.photo_camera,
                  renk: ButonRenk.yesil,
                  onTap: _okunuyor ? null : () => _cek(ImageSource.camera),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Buton(
                        yazi: 'Dosyalarım',
                        ikon: Icons.folder_open,
                        yukseklik: 48,
                        onTap: _okunuyor ? null : _dosya,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Buton(
                        yazi: 'Galeri',
                        ikon: Icons.photo_library,
                        renk: ButonRenk.mor,
                        yukseklik: 48,
                        onTap: _okunuyor ? null : () => _cek(ImageSource.gallery),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text('Dosyalarım: PDF, JPG ya da PNG. Çok sayfalı PDF\'in ilk 6 sayfası okunur.',
                    style: yaziSoluk),
              ],
            ),
          ),
          if (_okunuyor)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_resim != null && !_okunuyor)
            Panel(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(_resim!, height: 200, fit: BoxFit.contain),
              ),
            ),
          if (l != null && !_okunuyor) ...[
            if (l.isEmpty)
              Panel(
                kenarRengi: Renk.turuncu,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Parsel satırı bulunamadı.', style: yaziKalin),
                    const Text(
                        'Belgeyi düz, gölgesiz ve tablo tam görünecek şekilde çekin ya da PDF\'i '
                        'yükleyin. Okunan yazı aşağıda.',
                        style: yaziSoluk),
                    const SizedBox(height: 8),
                    Text(_metin, maxLines: 30, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: Renk.soluk)),
                  ],
                ),
              )
            else ...[
              Panel(
                baslik: '${l.length} parsel okundu',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Yanlış okunanların işaretini kaldırın ya da dokunup düzeltin.',
                        style: yaziSoluk),
                    for (final s in l) _satir(v, s),
                  ],
                ),
              ),
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SecimSatiri(
                      etiket: 'Sezon',
                      secenekler: [for (var y = DateTime.now().year + 1; y >= DateTime.now().year - 1; y--) '$y'],
                      secili: '$_yil',
                      onSec: (s) => setState(() => _yil = int.parse(s)),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: v.sahipler().contains(_cks) ? _cks : Veriler.ben,
                      isExpanded: true,
                      dropdownColor: Renk.kartAcik,
                      decoration: const InputDecoration(labelText: 'ÇKS kimin üzerine'),
                      items: [for (final k in v.sahipler()) DropdownMenuItem(value: k, child: Text(k))],
                      onChanged: (k) => setState(() => _cks = k ?? Veriler.ben),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _ekimYaz,
                      onChanged: (b) => setState(() => _ekimYaz = b),
                      title: const Text('Ürünleri bu sezonun ekimi olarak kaydet'),
                      subtitle: Text(
                          _yil > DateTime.now().year
                              ? 'Gelecek sezon: "Ekim planlanıyor" olarak yazılır.'
                              : 'O tarlaya bu sezon ekim girilmişse atlanır.',
                          style: yaziSoluk),
                    ),
                    const SizedBox(height: 6),
                    Buton(
                      yazi: _kaydediliyor ? 'Kaydediliyor…' : 'Seçilenleri Kaydet',
                      ikon: Icons.check,
                      renk: ButonRenk.yesil,
                      onTap: _kaydediliyor ? null : _kaydet,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ];
      },
    );
  }

  Widget _satir(Veriler v, CksSatir s) {
    final kayitli = s.tarlaId != null;
    return InkWell(
      onTap: () => _duzelt(s),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Checkbox(value: s.secili, onChanged: (b) => setState(() => s.secili = b ?? false)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      'Ada ${s.ada} · Parsel ${s.parsel}'
                      '${s.mahalle.isEmpty ? '' : ' · ${s.mahalle}'}',
                      style: yaziKalin),
                  Text(
                      '${sayi(s.dekar)} da'
                      '${s.urun.isEmpty ? '' : ' · ${urunSimge(s.urun)} ${s.urun}'}',
                      style: yaziSoluk),
                  Text(kayitli ? 'Kayıtlı: ${v.tarlaAdi(s.tarlaId!)}' : 'Yeni tarla eklenecek',
                      style: TextStyle(
                          color: kayitli ? Renk.mavi : Renk.yesilKoyu,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const Icon(Icons.edit, color: Renk.soluk, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _duzelt(CksSatir s) async {
    final ada = TextEditingController(text: s.ada);
    final parsel = TextEditingController(text: s.parsel);
    final mah = TextEditingController(text: s.mahalle);
    final alan = TextEditingController(text: girdi(s.dekar));
    var urun = s.urun;
    final tamam = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, ss) => AlertDialog(
          title: const Text('Parseli düzelt'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: mah, decoration: const InputDecoration(labelText: 'Mahalle / köy')),
                TextField(
                    controller: ada,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Ada')),
                TextField(
                    controller: parsel,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Parsel')),
                TextField(
                    controller: alan,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Alan (dekar)')),
                DropdownButtonFormField<String>(
                  initialValue: urun,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Ürün'),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('—')),
                    for (final u in urunler) DropdownMenuItem(value: u.ad, child: Text(u.ad)),
                  ],
                  onChanged: (x) => ss(() => urun = x ?? ''),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Tamam')),
          ],
        ),
      ),
    );
    if (tamam != true) return;
    setState(() {
      s.ada = ada.text.trim();
      s.parsel = parsel.text.trim();
      s.mahalle = mah.text.trim();
      var d = sayiOku(alan.text) ?? s.dekar;
      if (d >= 1000) d = d / 1000;
      s.dekar = d;
      s.urun = urun;
      s.tarlaId = _eslesen(durum.v, s);
    });
  }
}
