# Tempo V2 — Product Redesign

Dokumen ini menjadi kontrak desain dan implementasi Tempo V2. Fokusnya adalah pengalaman pendampingan pribadi yang tenang, lokal, dan dapat diprediksi—bukan diagnosis atau pengganti bantuan profesional.

## Prinsip produk

- **Local-first dan offline.** Data, aturan, riwayat, dan rekomendasi berjalan di perangkat. Tidak ada akun, analitik, AI jarak jauh, atau ketergantungan jaringan untuk fungsi inti.
- **Privasi secara default.** Informasi sensitif disimpan pada protected local storage; detail sesi privat bersifat opsional dan ringkas. Export tetap terenkripsi dan dikendalikan pengguna.
- **Aman dan tidak menghakimi.** Bahasa memakai nada coach yang netral. Jalur bantuan dan layar keselamatan selalu mengalahkan alur latihan atau sesi terpandu.
- **Deterministik.** Rekomendasi yang sama untuk masukan dan aturan yang sama harus menghasilkan keluaran yang sama, lengkap dengan alasan yang dapat ditampilkan.
- **Aksesibel.** Seluruh alur harus menghormati Dynamic Type, VoiceOver, kontras, Reduce Motion, serta umpan balik haptic yang dapat dilewati.

## Struktur aplikasi

Tempo V2 memakai tepat empat tab utama:

1. **Hari Ini** — aktivitas terjadwal, tindakan cepat, garis waktu, ringkasan besok, dan insight singkat.
2. **Program** — kalender minggu nyata, detail aktivitas, perubahan ketersediaan, dan adaptasi jadwal.
3. **Progres** — riwayat bermakna, konsistensi yang jatuh tempo, dan insight mingguan deterministik.
4. **Profil** — baseline, preferensi pengingat, privasi, export, bantuan, dan pengaturan keamanan.

`Latihan` tidak lagi menjadi tab terpisah. Aktivitas kardio, kekuatan, napas, dan sesi terpandu dibuka dari Hari Ini atau Program melalui satu coordinator/routing layer. Coordinator menjaga tujuan navigasi, sheet, dan layar penuh agar tidak muncul sheet bertumpuk.

## Mesin program dan aturan

Penjadwalan dipisahkan dari tampilan dan penyimpanan. Semua engine murni, dapat diuji, dan menerima konteks lokal yang eksplisit.

| Komponen | Tanggung jawab |
| --- | --- |
| `ProgramEngine` | Menyatukan konteks pengguna, riwayat, eligibility, dan aturan untuk menghasilkan program aktif. |
| `WeeklyPlanGenerator` | Membuat rencana Senin–Minggu dengan tanggal aktual, fase, aktivitas, waktu, durasi, dan alasan. |
| `DailyRecommendationEngine` | Memilih aktivitas utama Hari Ini serta alternatif yang aman. |
| `SessionPrescriptionEngine` | Menghasilkan durasi persiapan, aktif, jeda, pemulihan, dan batas sesi terpandu. |
| `ExercisePrescriptionEngine` | Menghasilkan resep kardio/kekuatan yang bertahap dan sesuai kemampuan. |
| `EligibilityEngine` | Menentukan kegiatan yang tersedia, ditunda, atau perlu pemulihan. |
| `AdaptationPolicy` | Menyesuaikan aktivitas mendatang secara aman sesudah lelah, tertunda, atau perubahan ketersediaan. |
| `PlanActivityResolver` | Menerjemahkan item program ke layar dan aksi yang tepat. |
| `PlanReason` | Kode alasan yang dapat dipahami pengguna, misalnya fase, pemulihan, jadwal, atau adaptasi. |
| `RulesetVersion` | Versi aturan yang melekat pada rencana dan riwayat agar hasil dapat dilacak. |

Masukan adaptasi mencakup baseline, fase program, hari dalam minggu, jadwal atau jendela waktu, ketersediaan, aktivitas yang selesai/dilewati, tingkat energi, tidur, stres, keluhan yang dikonfirmasi, sesi privat, sesi terpandu, latihan fisik, dan safety hold. Engine tidak menetapkan target klinis atau sasaran seksual manual.

Rencana awal menggunakan pola kesadaran yang ringan dengan sesi terpandu pada Senin dan Kamis bila eligible. Setiap perubahan hanya memengaruhi item masa depan yang belum selesai; item selesai dan riwayat tidak diubah. Jadwal baru menyimpan alasan adaptasi dan versi aturan.

## Onboarding dan baseline

Onboarding memerlukan dua belas langkah ringkas sebelum Hari Ini tersedia. Urutannya mencakup: pengantar, prinsip privasi, tujuan umum, pola tidur, energi, stres, aktivitas harian, kebiasaan gerak, preferensi ritme, batas kenyamanan, preferensi pengingat, dan ringkasan minggu pertama.

Pengguna memilih jendela pengingat, bukan target klinis. Setelah baseline disimpan, aplikasi menampilkan pratinjau minggu pertama yang dihasilkan engine dan dapat langsung menyesuaikan ketersediaan untuk hari mendatang.

## Hari Ini dan jalur cepat

Hari Ini selalu menampilkan tanggal dan minggu program, lalu sebuah aktivitas primer berisi waktu, durasi, alasan, dan tombol **Mulai**. Di bawahnya terdapat garis waktu hari ini, pratinjau besok, dan satu insight yang hanya muncul bila datanya cukup.

Tindakan cepat wajib memakai label berikut:

- **Aku mau onani sekarang** membuka jalur cepat dengan pilihan sesi privat yang diskret.
- **Aku sedang sangat terangsang** membuka jalur urge cepat.

Jalur urge maksimal tiga keputusan: pilihan aksi, intensitas, lalu konfirmasi gejala singkat. Sesudah itu pengguna langsung diarahkan ke rekomendasi aman yang relevan; tidak ada formulir panjang. Jika jawaban keselamatan mengaktifkan hold, aplikasi keluar dari alur latihan dan menampilkan jalur bantuan yang sesuai.

## Sesi privat dan sesi terpandu

`PrivateSessionTimerView` adalah layar penuh untuk sesi privat. Layar menyediakan timer nyata, mulai/jeda/lanjut/selesai, haptic, tombol darurat, dan fase pemulihan. Saat selesai, pengguna dapat menyimpan ringkasan lokal atau memilih tidak menyimpan detail. Keberadaan sesi privat dapat memengaruhi rekomendasi pemulihan dan eligibility, tetapi tidak menambah skor sesi terpandu.

Sesi terpandu juga berupa layar penuh imersif, bukan formulir scroll. Prescription memisahkan durasi persiapan, bagian aktif, warning, jeda/pemulihan, dan penutupan. Warning harus menjadi state yang terlihat sebelum transisi eksplisit ke pemulihan; state warning tidak boleh dilompati dalam satu mutasi. Kontrol tidak boleh mensimulasikan kondisi seperti “stabil” atau “naik” tanpa input bermakna. Log hanya ditulis setelah sesi benar-benar selesai atau dihentikan dengan status yang jelas.

## Kardio dan kekuatan

Kardio serta kekuatan dibuka dari aktivitas program. Keduanya memakai sesi interaktif berisi langkah, timer atau set/repetisi, jeda, progres aman, opsi berhenti, dan pencatatan hasil. Tombol selesai statis tanpa pelaksanaan sesi bukan implementasi yang cukup. Prescription tetap lokal dan menghindari kenaikan beban yang tidak didukung riwayat atau kondisi pengguna.

## Program kalender dan adaptasi

Tab Program menunjukkan satu minggu Senin–Minggu dengan tanggal aktual, status tiap item (direncanakan, selesai, dilewati, diadaptasi, atau pemulihan), waktu, durasi, dan alasan. Memilih hari menampilkan detail aktivitas, fase, tujuan, penjelasan, serta tindakan yang aman.

Pengguna dapat menyatakan tidak tersedia atau menunda aktivitas mendatang. `AdaptationPolicy` mencari slot aman berikutnya, mencegah duplikasi, mempertahankan batas pemulihan, dan memberi alasan perubahan. Pengguna tidak perlu menyusun target latihan sendiri. Perubahan tersimpan lokal dan pengingat terkait diperbarui.

## Progres dan pengingat

Progres tidak menampilkan skor nol seolah-olah merupakan evaluasi ketika sampel belum cukup. Konsistensi dihitung hanya dari item yang telah jatuh tempo, bukan seluruh rencana mingguan sejak awal. Insight mingguan dihasilkan secara deterministik dari riwayat yang cukup dan menyebutkan dasar waktunya secara wajar.

Pengingat dibuat per aktivitas program dan jendela waktu yang dipilih pengguna. Sistem harus melakukan deduplikasi berdasarkan ID aktivitas, membatalkan atau menjadwal ulang pengingat saat plan beradaptasi, serta tidak menjadwalkan aktivitas yang telah selesai, dilewati, atau berada dalam safety hold.

## Data, migrasi, dan keselamatan

Penyimpanan dibagi antara profil/pengaturan yang sesuai dan riwayat terlindungi. Model lama harus tetap dapat didekode; field baru memiliki nilai aman untuk data yang belum memilikinya. Migrasi menjaga baseline, riwayat aktivitas, sesi terpandu, keluhan, safety hold, dan preferensi privasi yang ada. Data privat disimpan sesedikit mungkin.

Safety hold selalu memblokir aktivitas yang tidak sesuai dan mengarahkan ke informasi bantuan. Tombol darurat tersedia dari sesi sensitif. Aplikasi tidak membuat klaim diagnosis, prediksi klinis, atau saran profesional individual.

## Matriks pengujian

Implementasi V2 perlu diverifikasi dengan unit test domain dan UI test setidaknya untuk:

1. pembuatan minggu Senin–Minggu dengan tanggal aktual;
2. determinisme `RulesetVersion` dan `PlanReason`;
3. rekomendasi harian dan fallback saat tidak tersedia;
4. adaptasi penundaan tanpa mengubah item selesai;
5. deduplikasi dan reschedule pengingat;
6. eligibility setelah sesi privat dan masa pemulihan;
7. sesi privat tidak menaikkan skor terpandu;
8. transisi warning sesi terpandu yang eksplisit;
9. penyelesaian, jeda, pembatalan, dan pemulihan timer;
10. alur urge tiga keputusan dan routing hasil;
11. safety hold yang mengalahkan rekomendasi normal;
12. baseline/onboarding dua belas langkah dan pratinjau minggu pertama;
13. riwayat lama yang dimigrasikan tanpa kehilangan data;
14. progres tanpa sampel cukup dan konsistensi due-only;
15. interaksi kardio/kekuatan serta pencatatan hasil;
16. empat tab, navigasi tunggal, dan tidak ada nested sheet;
17. Dynamic Type, Reduce Motion, dan label aksesibilitas;
18. build, archive, IPA validation, instalasi, dan launch pada simulator/CI.

## Build dan rilis

Rilis dilakukan hanya setelah test domain, test iOS, build archive, validasi IPA, dan pemasangan/launch simulator berhasil pada CI. Artefak IPA sideload harus dipublikasikan sebagai asset rilis GitHub bersama checksum dan catatan rilis yang menyebutkan versi aturan. Keberhasilan rilis tidak boleh diklaim hanya karena dokumentasi atau mockup telah dibuat.

## Status implementasi

Dokumen ini mendefinisikan target V2 dan peta verifikasi. Status tiap poin harus diperbarui berdasarkan bukti test/build aktual, bukan dianggap selesai hanya karena bagian UI atau model telah dibuat.
