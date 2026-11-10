// Bereket: eski Firebase projesinden (egitim-takip-5a833) yenisine
// (bereket-86ea7) kullanıcı hesaplarını ve tarlam_* verilerini taşır.
//
// Kullanım:  node tasi.js kontrol   -> veri yazmaz; sayar, kontrol eder,
//                                       Android uygulama kaydını hazırlar
//            node tasi.js tasi      -> hesapları, verileri ve dizinleri kopyalar,
//                                       kuralları yayınlar
//
// Ortam:     ESKI_ANAHTAR, YENI_ANAHTAR  (servis hesabı JSON dosya yolları)
//
// Hesaplar aynı kullanıcı kimliği (uid) ve aynı şifreyle taşınır; böylece
// işletme üyelikleri ve aile bağlantıları olduğu gibi kalır.
'use strict';

const fs = require('fs');
const path = require('path');
const { initializeApp, cert } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore } = require('firebase-admin/firestore');
const { getSecurityRules } = require('firebase-admin/security-rules');
const { getProjectManagement } = require('firebase-admin/project-management');

const MOD = process.argv[2];
if (!['kontrol', 'tasi'].includes(MOD)) {
  console.error('Kullanım: node tasi.js kontrol|tasi');
  process.exit(2);
}

const ESKI_PROJE = 'egitim-takip-5a833';
const YENI_PROJE = 'bereket-86ea7';
const PAKET = 'com.kocabas.bereket';
const KOK_KOLEKSIYONLAR = ['tarlam_kullanicilar', 'tarlam_kodlar', 'tarlam_aile_kodlar', 'tarlam_isletmeler'];

function oku(p) { return JSON.parse(fs.readFileSync(p, 'utf8')); }
const eskiSA = oku(process.env.ESKI_ANAHTAR);
const yeniSA = oku(process.env.YENI_ANAHTAR);

const hatalar = [];
function hata(m) { hatalar.push(m); console.log('HATA: ' + m); }

if (eskiSA.project_id !== ESKI_PROJE) hata(`Eski anahtar ${eskiSA.project_id} projesine ait, ${ESKI_PROJE} olmalı.`);
if (yeniSA.project_id !== YENI_PROJE) hata(`Yeni anahtar ${yeniSA.project_id} projesine ait, ${YENI_PROJE} olmalı.`);
if (hatalar.length) process.exit(1);

const eski = initializeApp({ credential: cert(eskiSA), projectId: ESKI_PROJE }, 'eski');
const yeni = initializeApp({ credential: cert(yeniSA), projectId: YENI_PROJE }, 'yeni');
const eskiDb = getFirestore(eski);
const yeniDb = getFirestore(yeni);

async function token(app) {
  return (await app.options.credential.getAccessToken()).access_token;
}

async function istek(app, yontem, url, govde) {
  const r = await fetch(url, {
    method: yontem,
    headers: { Authorization: 'Bearer ' + await token(app), 'Content-Type': 'application/json' },
    body: govde ? JSON.stringify(govde) : undefined,
  });
  const metin = await r.text();
  let j = {};
  try { j = metin ? JSON.parse(metin) : {}; } catch (_) { j = { metin }; }
  return { ok: r.ok, durum: r.status, j };
}

async function kimlikAyari(app, proje, yama) {
  const url = `https://identitytoolkit.googleapis.com/admin/v2/projects/${proje}/config` +
    (yama ? '?updateMask=signIn.email.enabled,signIn.email.passwordRequired' : '');
  const r = await istek(app, yama ? 'PATCH' : 'GET', url, yama);
  if (!r.ok) throw new Error(`${proje} kimlik ayarı okunamadı: ${r.durum} ${JSON.stringify(r.j).slice(0, 300)}`);
  return r.j;
}

// ---- Firestore: belgeleri alt koleksiyonlarıyla birlikte gez -------------
async function gez(db, koleksiyon, ziyaret) {
  const refler = await koleksiyon.listDocuments(); // alt koleksiyonu olan "boş" belgeler dahil
  for (let i = 0; i < refler.length; i += 300) {
    const parca = refler.slice(i, i + 300);
    const anlik = await db.getAll(...parca);
    for (const s of anlik) {
      if (s.exists) await ziyaret(s);
      for (const alt of await s.ref.listCollections()) await gez(db, alt, ziyaret);
    }
  }
}

// ---- Bileşik dizinler (eski projede elle oluşturulmuş olabilir) ----------
async function dizinler(app, proje) {
  const r = await istek(app, 'GET',
    `https://firestore.googleapis.com/v1/projects/${proje}/databases/(default)/collectionGroups/-/indexes`);
  if (!r.ok) throw new Error(`${proje} dizinleri okunamadı: ${r.durum} ${JSON.stringify(r.j).slice(0, 300)}`);
  return (r.j.indexes || []).filter((x) => (x.fields || []).filter((f) => f.fieldPath !== '__name__').length > 1);
}
function dizinAnahtari(x) {
  const grup = x.name.split('/collectionGroups/')[1].split('/')[0];
  return grup + '|' + x.queryScope + '|' + x.fields.map((f) => f.fieldPath + ':' + (f.order || f.arrayConfig)).join(',');
}

// ---- Android uygulama kaydı ve ayarları -----------------------------------
async function androidAyarlari(olustur) {
  const pm = getProjectManagement(yeni);
  let uygulama = null;
  for (const a of await pm.listAndroidApps()) {
    const m = await a.getMetadata();
    if (m.packageName === PAKET) { uygulama = a; break; }
  }
  if (!uygulama && olustur) {
    uygulama = await pm.createAndroidApp(PAKET, 'Bereket');
    console.log('Yeni projeye Android uygulaması kaydedildi: ' + PAKET);
  }
  if (!uygulama) return null;
  const gs = JSON.parse(await uygulama.getConfig());
  const istemci = gs.client.find((c) => c.client_info.android_client_info.package_name === PAKET);
  return {
    apiKey: istemci.api_key[0].current_key,
    appId: istemci.client_info.mobilesdk_app_id,
    messagingSenderId: gs.project_info.project_number,
    projectId: gs.project_info.project_id,
    storageBucket: gs.project_info.storage_bucket,
  };
}

async function main() {
  console.log(`== Mod: ${MOD}`);

  // 1) Bereket kullanıcıları (tarlam_kullanicilar, işletme üyeleri, aile)
  const uidler = new Set();
  (await eskiDb.collection('tarlam_kullanicilar').listDocuments()).forEach((r) => uidler.add(r.id));
  for (const f of (await eskiDb.collection('tarlam_isletmeler').get()).docs) {
    const d = f.data();
    for (const k of ['uyeler', 'yoneticiler']) (d[k] || []).forEach((u) => uidler.add(u));
    if (d.sahip) uidler.add(d.sahip);
    Object.keys(d.aile || {}).forEach((u) => uidler.add(u));
  }
  console.log(`Bereket kullanıcı kimliği: ${uidler.size}`);

  const kullanicilar = [];
  let sayfa;
  do {
    const r = await getAuth(eski).listUsers(1000, sayfa);
    r.users.forEach((u) => { if (uidler.has(u.uid)) kullanicilar.push(u); });
    sayfa = r.pageToken;
  } while (sayfa);
  const sifresiz = kullanicilar.filter((u) => !u.passwordHash);
  console.log(`Taşınacak hesap: ${kullanicilar.length} (şifre bilgisi olmayan: ${sifresiz.length})`);
  sifresiz.forEach((u) => console.log(`  şifresiz: ${u.email || u.uid}`));
  const bulunamayan = [...uidler].filter((u) => !kullanicilar.some((k) => k.uid === u));
  if (bulunamayan.length) console.log(`Verilerde olup hesabı olmayan kimlik: ${bulunamayan.length}`);

  // 2) Şifre karma ayarı ve yeni projenin giriş ayarı
  const eskiAyar = await kimlikAyari(eski, ESKI_PROJE);
  const hc = eskiAyar.signIn && eskiAyar.signIn.hashConfig;
  if (!hc || hc.algorithm !== 'SCRYPT') hata('Eski projenin şifre karma ayarı alınamadı.');
  else console.log(`Şifre karma ayarı alındı (SCRYPT, rounds=${hc.rounds}, memoryCost=${hc.memoryCost}).`);

  let epostaAcik = false;
  try {
    const yeniAyar = await kimlikAyari(yeni, YENI_PROJE);
    epostaAcik = !!(yeniAyar.signIn && yeniAyar.signIn.email && yeniAyar.signIn.email.enabled);
    console.log(`Yeni projede e-posta/şifre girişi: ${epostaAcik ? 'açık' : 'KAPALI (taşımada açılacak)'}`);
  } catch (e) {
    console.log('Yeni projenin giriş ayarı okunamadı (Authentication henüz başlatılmamış olabilir): ' + e.message);
  }
  try {
    const yeniHesap = await getAuth(yeni).listUsers(1);
    console.log(`Yeni projede şu an hesap var mı: ${yeniHesap.users.length ? 'evet' : 'hayır'}`);
  } catch (e) {
    hata('Yeni projede Authentication kullanılamıyor: ' + e.message +
      ' (Firebase Console → Authentication → Get started → Email/Password açın)');
  }

  // 3) Firestore: belge sayıları, yeni projenin durumu, dizinler
  const sayac = {};
  for (const k of KOK_KOLEKSIYONLAR) {
    await gez(eskiDb, eskiDb.collection(k), async (s) => {
      const tur = s.ref.parent.id;
      sayac[tur] = (sayac[tur] || 0) + 1;
    });
  }
  console.log('Eski projedeki belgeler: ' + JSON.stringify(sayac));

  try {
    const mevcut = await yeniDb.listCollections();
    console.log(`Yeni projenin veritabanı erişilebilir. Kök koleksiyonlar: ${mevcut.map((c) => c.id).join(', ') || '(boş)'}`);
  } catch (e) {
    hata(`Yeni projenin Firestore veritabanına erişilemedi (oluşturulmamış olabilir): ${e.message}`);
  }

  let eskiDizinler = [];
  try {
    eskiDizinler = (await dizinler(eski, ESKI_PROJE)).filter((x) => {
      const grup = x.name.split('/collectionGroups/')[1].split('/')[0];
      return !['students', 'homeworks', 'books', 'readingLogs', 'testBooks', 'testResults', 'users', 'invites',
        'satis_firmalar', 'siparisler', 'satis_kullanicilar', 'satis_kodlar', 'satis_hareketleri'].includes(grup);
    });
    console.log(`Eski projedeki ilgili bileşik dizin: ${eskiDizinler.length}`);
    eskiDizinler.forEach((x) => console.log('  ' + dizinAnahtari(x)));
  } catch (e) {
    console.log('Dizinler okunamadı (önemli değil): ' + e.message);
  }

  // 4) Android uygulama kaydı (veri değildir, kontrol modunda da hazırlanır)
  try {
    const a = await androidAyarlari(true);
    console.log('ANDROID_AYARLARI ' + JSON.stringify(a));
  } catch (e) {
    hata('Android uygulaması kaydedilemedi/okunamadı: ' + e.message);
  }

  if (MOD === 'kontrol') {
    console.log(hatalar.length ? `\n${hatalar.length} sorun var.` : '\nKONTROL TAMAM: taşımaya hazır.');
    process.exit(hatalar.length ? 1 : 0);
  }
  if (hatalar.length) process.exit(1);

  // ---- TAŞIMA ------------------------------------------------------------
  if (!epostaAcik) {
    await kimlikAyari(yeni, YENI_PROJE, { signIn: { email: { enabled: true, passwordRequired: true } } });
    console.log('Yeni projede e-posta/şifre girişi açıldı.');
  }

  // a) Hesaplar (aynı uid ve şifre)
  const kayitlar = kullanicilar.map((u) => {
    const k = {
      uid: u.uid,
      email: u.email,
      emailVerified: u.emailVerified,
      displayName: u.displayName,
      disabled: u.disabled,
    };
    const md = {};
    if (u.metadata.creationTime) md.creationTime = u.metadata.creationTime;
    if (u.metadata.lastSignInTime) md.lastSignInTime = u.metadata.lastSignInTime;
    if (Object.keys(md).length) k.metadata = md;
    if (u.passwordHash) {
      k.passwordHash = Buffer.from(u.passwordHash, 'base64');
      k.passwordSalt = Buffer.from(u.passwordSalt || '', 'base64');
    }
    Object.keys(k).forEach((a) => k[a] === undefined && delete k[a]);
    return k;
  });
  for (let i = 0; i < kayitlar.length; i += 1000) {
    const r = await getAuth(yeni).importUsers(kayitlar.slice(i, i + 1000), {
      hash: {
        algorithm: 'SCRYPT',
        key: Buffer.from(hc.signerKey, 'base64'),
        saltSeparator: Buffer.from(hc.saltSeparator || '', 'base64'),
        rounds: hc.rounds,
        memoryCost: hc.memoryCost,
      },
    });
    console.log(`Hesap aktarımı: ${r.successCount} başarılı, ${r.failureCount} hatalı`);
    r.errors.forEach((e) => hata(`Hesap ${kayitlar[i + e.index].email || kayitlar[i + e.index].uid}: ${e.error.message}`));
  }

  // b) Veriler (aynı belge kimlikleri, aynı alanlar ve türler)
  const yazici = yeniDb.bulkWriter();
  yazici.onWriteError((e) => { hata(`Yazılamadı ${e.documentRef.path}: ${e.message}`); return false; });
  let yazilan = 0;
  for (const k of KOK_KOLEKSIYONLAR) {
    await gez(eskiDb, eskiDb.collection(k), async (s) => {
      yazici.set(yeniDb.doc(s.ref.path), s.data());
      yazilan++;
    });
  }
  await yazici.close();
  console.log(`Kopyalanan belge: ${yazilan}`);

  // c) Doğrulama
  const yeniSayac = {};
  for (const k of KOK_KOLEKSIYONLAR) {
    await gez(yeniDb, yeniDb.collection(k), async (s) => {
      const tur = s.ref.parent.id;
      yeniSayac[tur] = (yeniSayac[tur] || 0) + 1;
    });
  }
  console.log('Yeni projedeki belgeler: ' + JSON.stringify(yeniSayac));
  for (const t of Object.keys(sayac)) {
    if ((yeniSayac[t] || 0) < sayac[t]) hata(`${t}: eski ${sayac[t]}, yeni ${yeniSayac[t] || 0}`);
  }

  // d) Bileşik dizinler
  if (eskiDizinler.length) {
    let mevcutlar = new Set();
    try { mevcutlar = new Set((await dizinler(yeni, YENI_PROJE)).map(dizinAnahtari)); } catch (_) {}
    for (const x of eskiDizinler) {
      if (mevcutlar.has(dizinAnahtari(x))) continue;
      const grup = x.name.split('/collectionGroups/')[1].split('/')[0];
      const r = await istek(yeni, 'POST',
        `https://firestore.googleapis.com/v1/projects/${YENI_PROJE}/databases/(default)/collectionGroups/${grup}/indexes`,
        { queryScope: x.queryScope, fields: x.fields.filter((f) => f.fieldPath !== '__name__') });
      if (r.ok) console.log('Dizin oluşturuluyor: ' + dizinAnahtari(x));
      else hata(`Dizin oluşturulamadı (${dizinAnahtari(x)}): ${r.durum} ${JSON.stringify(r.j).slice(0, 200)}`);
    }
  }

  // e) Güvenlik kuralları
  try {
    const kaynak = fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8');
    await getSecurityRules(yeni).releaseFirestoreRulesetFromSource(kaynak);
    console.log('Yeni projeye güvenlik kuralları yayınlandı.');
  } catch (e) {
    hata(`Kurallar yayınlanamadı (Console'dan elle yapıştırın): ${e.message}`);
  }

  console.log(hatalar.length ? `\nTAŞIMA BİTTİ, ${hatalar.length} sorun var.` : '\nTAŞIMA TAMAM.');
  process.exit(hatalar.length ? 1 : 0);
}

main().catch((e) => { console.error('HATA: ' + (e.stack || e)); process.exit(1); });
