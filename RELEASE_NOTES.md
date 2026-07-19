# TEMPO 2.1.2

## Correctness hotfix

- Health recheck yang bersih kini juga menandai keluhan readiness hari ini sebagai selesai, sehingga safety lock tidak berulang.
- Daily readiness membedakan iritasi ringan, nyeri, keluhan saluran kemih/cairan tidak biasa, serta darah/demam dengan jalur keselamatan yang sesuai.
- Readiness lama dipakai hanya sebagai tren; kondisi langsung hari ini memakai check-in hari ini atau perkiraan baseline yang netral.
- Penundaan manual dan reschedule otomatis menggunakan pemeriksa batasan jadwal yang sama.
- Batas guided rolling tujuh hari dihitung pada tanggal kandidat, dan aktivitas tertunda tidak lagi merusak skor konsistensi.
- Kalender Program menampilkan nomor minggu yang sedang dilihat, tanpa mengubah minggu aktual.
- Preferensi aktivitas dapat diubah dari Profil tanpa menghapus riwayat; hanya rencana masa depan yang belum disentuh yang diperbarui.
- Flow dan helper V1 yang tidak lagi dipakai telah dikeluarkan dari target aplikasi. Data lama tetap dimigrasikan secara kompatibel.

## Sideload

`Tempo-resign-ready.ipa` adalah paket ARM64 untuk sideload. Re-sign terlebih dahulu memakai alat sideload dan Apple ID/perangkat yang kamu gunakan. Berkas `.sha256` menyertai release untuk memverifikasi unduhan sebelum re-sign.
