# Panduan Pengembangan TEMPO

## Bentuk produk akhir

TEMPO adalah aplikasi iPhone offline dengan satu layar utama yang langsung memberi tahu pengguna apa yang perlu dilakukan hari ini. Pengguna tidak menyusun target sendiri karena aplikasi menentukan program berdasarkan assessment dan histori lokal.

### Tindakan utama di Home

- **Mulai aktivitas hari ini**
- **Aku lagi terangsang**
- **Mulai latihan kontrol**
- **Aku punya keluhan**

Dalam mode privat, label tersebut bisa berubah menjadi:

- Aktivitas hari ini
- Quick check-in
- Guided session
- Health check

## Cara aplikasi “berpikir” tanpa AI

Urutannya selalu seperti ini:

1. **Safety gate** memeriksa tanda bahaya.
2. **Readiness engine** menilai apakah pengguna perlu istirahat, menenangkan diri, berolahraga, atau berlatih.
3. **Program engine** menentukan target sesi.
4. **Scheduler** menempatkan aktivitas pada hari yang aman.
5. **Scoring engine** menghitung awareness, control, recovery, calm, consistency, dan independence.
6. **Progression engine** menaikkan atau menurunkan tingkat latihan.

Semua hasil dapat dijelaskan dengan alasan sederhana. Contoh:

> Hari ini disarankan pemulihan karena kamu sudah melakukan sesi kemarin dan melaporkan iritasi ringan.

## Prioritas pengembangan

### Tahap 1 — Fondasi

- SwiftUI app shell
- dark design system
- SwiftData lokal
- biometric lock
- privacy cover ketika app masuk background

### Tahap 2 — Otak aplikasi

- baseline assessment
- safety rules
- rule engine
- scheduler tujuh hari
- score calculator
- program state machine

### Tahap 3 — Fitur inti

- tombol Aku lagi terangsang
- urge check-in
- urge surfing
- guided start–stop
- red warning animation
- haptic feedback
- recovery timer

### Tahap 4 — Gaya hidup

- walking/jogging progression
- push-up dan bodyweight workout
- breathing dan mobility
- jadwal pemulihan
- materi edukasi lokal

### Tahap 5 — Penyelesaian

- progress dashboard
- accessibility
- HealthKit opsional
- sideload signing
- test offline pada iPhone fisik

## Aturan jadwal awal

- latihan start–stop: 2 kali per minggu;
- maksimal: 3 kali per minggu;
- tidak dijadwalkan pada hari berurutan;
- cardio: mulai 2 kali per minggu;
- strength: mulai 1 kali per minggu, lalu naik menjadi 2;
- minimal 1 hari recovery penuh;
- breathing singkat pada hari stres atau sebelum sesi;
- jadwal dihitung ulang setiap minggu.

## Alur tombol “Aku lagi terangsang”

1. Pengguna memberi nilai intensitas 1–10.
2. Memilih penyebab: gairah, bosan, stres, kesepian, atau sulit tidur.
3. Memilih tujuan: menenangkan, latihan, atau sesi pribadi.
4. Menjawab pertanyaan safety.
5. Engine menghasilkan rekomendasi.

### Contoh hasil

- Bosan + intensitas 4 → urge surfing lima menit.
- Gairah 8 + jadwal latihan tersedia → guided start–stop.
- Baru melakukan sesi enam jam lalu → recovery.
- Nyeri atau cairan abnormal → guided session diblokir.

## Alur guided session

1. Pre-check.
2. Persiapan napas 90–120 detik.
3. Pengguna mengatur level gairah.
4. Level 6 memunculkan warning amber.
5. Level 7 memunculkan warning merah dan haptic kuat.
6. Pengguna berhenti dan menjalankan recovery timer.
7. Setelah turun ke level 3–4, pengguna boleh lanjut.
8. Sesi selesai setelah target cycle atau batas waktu.
9. Aplikasi menghitung sesi berikutnya.

## Definisi keberhasilan

Keberhasilan bukan hanya durasi. Aplikasi mengutamakan:

- berhenti lebih awal;
- mengenali kenaikan gairah;
- menurunkan gairah setelah pause;
- mengurangi ketegangan dan kecemasan;
- mengikuti jadwal termasuk hari istirahat;
- akhirnya mampu berlatih tanpa melihat timer.
