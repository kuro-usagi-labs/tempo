# TEMPO — Blueprint Aplikasi iOS Offline Tanpa AI

Dokumentasi ini adalah rancangan lengkap aplikasi iPhone untuk membantu pengguna dewasa melatih kesadaran gairah, menjalankan teknik start–stop secara terstruktur, mengurangi kebiasaan terburu-buru, serta membangun rutinitas olahraga dan pemulihan yang lebih sehat.

## Konsep utamanya

TEMPO **tidak menggunakan AI**, tidak membutuhkan akun, dan tidak membutuhkan internet. Aplikasi terlihat pintar karena menggunakan:

- rule engine deterministik;
- decision table;
- scoring berdasarkan histori pengguna;
- program state machine;
- scheduler lokal;
- aturan keselamatan berprioritas tinggi.

Saat pengguna menekan **“Aku lagi terangsang”**, aplikasi menanyakan intensitas, penyebab, tujuan, dan keluhan fisik. Setelah itu sistem memilih salah satu tindakan:

1. latihan menenangkan dorongan;
2. guided start–stop session;
3. sesi pribadi dengan pengingat aman;
4. pemulihan karena terlalu dekat dengan sesi sebelumnya;
5. health check jika ditemukan tanda bahaya.

## Teknologi yang direkomendasikan

- Native SwiftUI
- Swift Concurrency dan Observation
- SwiftData untuk database lokal
- Keychain dan CryptoKit untuk perlindungan data
- UserNotifications untuk reminder lokal yang netral
- Core Haptics untuk feedback yang terasa premium
- HealthKit opsional untuk membaca aktivitas olahraga dengan izin pengguna
- XCTest dan XCUITest

## Arah UI/UX

- dark theme modern dan minimalis;
- background hitam-charcoal;
- aksen indigo/cyan;
- peringatan merah hanya ketika harus berhenti;
- animasi breathing orb;
- progress ring dengan gerakan spring;
- haptic berbeda untuk warning, pause, dan cycle selesai;
- tidak ada ilustrasi vulgar;
- notifikasi tidak pernah menyebut onani atau informasi seksual.

## Dokumen yang dibaca lebih dulu

1. `00_OVERVIEW/00_PANDUAN_PENGEMBANGAN.md`
2. `01_PRODUCT/02_PRD.md`
3. `02_PROGRAM/01_PROGRAM_12_WEEKS.md`
4. `03_ENGINE/01_RULE_ENGINE_SPEC.md`
5. `03_ENGINE/05_URGE_MODE_SPEC.md`
6. `03_ENGINE/06_GUIDED_SESSION_SPEC.md`
7. `05_DESIGN/03_MOTION_AND_HAPTICS.md`
8. `04_ENGINEERING/01_IOS_ARCHITECTURE.md`
9. `08_DELIVERY/01_IMPLEMENTATION_ROADMAP.md`

## Batasan penting

Aplikasi ini tidak boleh menjanjikan pengguna pasti sembuh atau pasti tahan lebih lama. Produk harus diposisikan sebagai aplikasi latihan dan wellness. Keluhan seperti nyeri, perih saat kencing, cairan tidak normal, darah, demam, atau perubahan fungsi seksual yang mendadak harus menghentikan latihan dan mengarahkan pengguna ke tenaga kesehatan.
