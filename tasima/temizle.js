// Bereket taşındıktan sonra eski projeyi (egitim-takip-5a833) temizler.
//
// Kullanım:  node temizle.js kontrol  -> hiçbir şey silmez; eski projedeki her
//                                        tarlam_* belgesinin yeni projede
//                                        (bereket-86ea7) birebir olduğunu doğrular,
//                                        eski projenin kurallarını inceler
//            node temizle.js sil      -> kontrol temizse: eski projenin kurallarından
//                                        Bereket bölümünü çıkarıp yayınlar, ardından
//                                        eski projedeki tarlam_* verisini siler
//
// Ortam:     ESKI_ANAHTAR, YENI_ANAHTAR  (servis hesabı JSON dosya yolları)
//
// Kullanıcı hesaplarına dokunmaz: aynı hesap Eğitim Takip'te de kullanılıyor olabilir.
'use strict';

const fs = require('fs');
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore, DocumentReference, Timestamp, GeoPoint } = require('firebase-admin/firestore');
const { getSecurityRules } = require('firebase-admin/security-rules');

const MOD = process.argv[2];
if (!['kontrol', 'sil'].includes(MOD)) {
  console.error('Kullanım: node temizle.js kontrol|sil');
  process.exit(2);
}

const ESKI_PROJE = 'egitim-takip-5a833';
const YENI_PROJE = 'bereket-86ea7';
const KOKLER = ['tarlam_kullanicilar', 'tarlam_kodlar', 'tarlam_aile_kodlar', 'tarlam_isletmeler'];
const BEREKET_ISARETI = '// ===== Bereket =====';

const oku = (p) => JSON.parse(fs.readFileSync(p, 'utf8'));
const eskiSA = oku(process.env.ESKI_ANAHTAR);
const yeniSA = oku(process.env.YENI_ANAHTAR);
if (eskiSA.project_id !== ESKI_PROJE || yeniSA.project_id !== YENI_PROJE) {
  console.error(`Anahtarlar yanlış projeye ait: ${eskiSA.project_id}, ${yeniSA.project_id}`);
  process.exit(1);
}
const eski = initializeApp({ credential: cert(eskiSA), projectId: ESKI_PROJE }, 'eski');
const yeni = initializeApp({ credential: cert(yeniSA), projectId: YENI_PROJE }, 'yeni');
const eskiDb = getFirestore(eski);
const yeniDb = getFirestore(yeni);

const hatalar = [];
const hata = (m) => { hatalar.push(m); console.log('HATA: ' + m); };

// Karşılaştırma için değerleri düz metne çevirir (alan sırası önemsiz).
function duz(v) {
  if (v instanceof DocumentReference) return { $ref: v.path };
  if (v instanceof Timestamp) return { $ts: [v.seconds, v.nanoseconds] };
  if (v instanceof GeoPoint) return { $geo: [v.latitude, v.longitude] };
  if (Buffer.isBuffer(v)) return { $bytes: v.toString('base64') };
  if (Array.isArray(v)) return v.map(duz);
  if (v && typeof v === 'object') {
    const o = {};
    for (const k of Object.keys(v).sort()) o[k] = duz(v[k]);
    return o;
  }
  return v;
}

async function gez(db, koleksiyon, ziyaret) {
  const refler = await koleksiyon.listDocuments();
  for (let i = 0; i < refler.length; i += 300) {
    const anlik = await db.getAll(...refler.slice(i, i + 300));
    for (const s of anlik) {
      if (s.exists) await ziyaret(s);
      for (const alt of await s.ref.listCollections()) await gez(db, alt, ziyaret);
    }
  }
}

async function dogrula() {
  let toplam = 0;
  const sayac = {};
  for (const kok of KOKLER) {
    await gez(eskiDb, eskiDb.collection(kok), async (s) => {
      toplam++;
      sayac[s.ref.parent.id] = (sayac[s.ref.parent.id] || 0) + 1;
      const y = await yeniDb.doc(s.ref.path).get();
      if (!y.exists) return hata(`Yeni projede yok: ${s.ref.path}`);
      // Belge yeni projede sonradan değişmiş olabilir; bu durumda yeni sürüm daha güncel.
      if (JSON.stringify(duz(s.data())) !== JSON.stringify(duz(y.data()))) {
        const eskiZ = s.updateTime.toMillis();
        const yeniZ = y.updateTime.toMillis();
        if (yeniZ <= eskiZ) hata(`Farklı ve eski projede daha yeni: ${s.ref.path}`);
        else console.log(`Bilgi: yeni projede sonradan güncellenmiş: ${s.ref.path}`);
      }
    });
  }
  console.log(`Eski projedeki Bereket belgeleri: ${toplam} ${JSON.stringify(sayac)}`);
  return toplam;
}

// Kural metninden Bereket bölümünü (işaretten, belgeler bloğunun sonuna kadar) çıkarır.
function bereketiCikar(kaynak) {
  const bas = kaynak.indexOf(BEREKET_ISARETI);
  if (bas < 0) return null;
  let derinlik = 0;
  let i = bas;
  for (; i < kaynak.length; i++) {
    if (kaynak[i] === '{') derinlik++;
    else if (kaynak[i] === '}') {
      if (derinlik === 0) break; // /databases/{database}/documents bloğunun kapanışı
      derinlik--;
    }
  }
  const satirBasi = kaynak.lastIndexOf('\n', bas) + 1;
  const kapanisSatiri = kaynak.lastIndexOf('\n', i) + 1;
  return (kaynak.slice(0, satirBasi).replace(/\s+$/, '\n') + kaynak.slice(kapanisSatiri));
}

async function main() {
  console.log(`== Mod: ${MOD}`);

  const toplam = await dogrula();

  const kurallar = getSecurityRules(eski);
  const mevcut = await kurallar.getFirestoreRuleset();
  const kaynak = mevcut.source[0].content;
  console.log(`Eski projenin şu anki kuralları: ${kaynak.split('\n').length} satır, ` +
    `Bereket bölümü ${kaynak.includes('tarlam_') ? 'VAR' : 'yok'}, ` +
    `Keleş Satış bölümü ${kaynak.includes('satis_') ? 'VAR' : 'yok'}`);

  let yeniKaynak = null;
  if (kaynak.includes('tarlam_')) {
    yeniKaynak = bereketiCikar(kaynak);
    if (!yeniKaynak) hata('Kurallarda "' + BEREKET_ISARETI + '" işareti bulunamadı; kurallar elle düzenlenmeli.');
    else if (yeniKaynak.includes('tarlam')) hata('Bereket bölümü çıkarıldıktan sonra kurallarda hâlâ "tarlam" geçiyor.');
    else console.log(`Bereket'siz kurallar: ${yeniKaynak.split('\n').length} satır.`);
  }

  if (MOD === 'kontrol') {
    if (yeniKaynak) console.log('\n----- Yayınlanacak kurallar -----\n' + yeniKaynak + '----- son -----');
    console.log(hatalar.length ? `\n${hatalar.length} sorun var; silme yapılmamalı.` : '\nKONTROL TAMAM: silmeye hazır.');
    process.exit(hatalar.length ? 1 : 0);
  }

  if (hatalar.length) {
    console.log(`\n${hatalar.length} sorun var; hiçbir şey silinmedi.`);
    process.exit(1);
  }

  console.log('\n----- Eski kurallar (yedek) -----\n' + kaynak + '----- son -----');
  if (yeniKaynak) {
    await kurallar.releaseFirestoreRulesetFromSource(yeniKaynak);
    console.log('Eski projeye Bereket\'siz kurallar yayınlandı.');
  }
  for (const kok of KOKLER) {
    await eskiDb.recursiveDelete(eskiDb.collection(kok));
    console.log(`Silindi: ${kok}`);
  }
  let kalan = 0;
  for (const kok of KOKLER) kalan += (await eskiDb.collection(kok).listDocuments()).length;
  console.log(kalan ? `UYARI: ${kalan} kök belge kaldı.` : `\nTEMİZLİK TAMAM: ${toplam} belge silindi.`);
}

main().catch((e) => { console.error(e); process.exit(1); });
