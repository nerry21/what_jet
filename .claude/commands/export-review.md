---
description: Simpan PCAC / Naskah CC ke satu file utuh di review-out/, siap dibuka & di-copy ke reviewer eksternal (Web Claude)
argument-hint: [nama-singkat, mis. fcm-delivery-ticks]
allowed-tools: Write, Bash(git branch:*), Bash(date:*), Bash(mkdir -p:*)
model: opus
---

- Branch: !`git branch --show-current`
- Timestamp: !`date +%Y%m%d-%H%M`

## Tugasmu

Ambil PCAC dan/atau Naskah CC yang BARU SAJA dihasilkan di sesi ini. Tulis SEMUANYA SECARA UTUH
— jangan dipotong, jangan diringkas, jangan diganti placeholder — ke satu file markdown, supaya
Nerry bisa membukanya, membaca penuh, lalu copy-paste ke reviewer eksternal (Web Claude).

Path file: `review-out/<branch>-<$ARGUMENTS, atau 'naskah' kalau kosong>-<timestamp>.md`
Buat folder `review-out/` dulu kalau belum ada.

Susunan isi file (berurutan, lengkap):

1. `#` Judul + metadata (branch, timestamp).
2. `##` PCAC lengkap (kalau ada di sesi ini) — termasuk Bagian F (matrix regresi + audit call-site).
3. `##` Naskah CC lengkap (kalau ada) — byte-exact, TERMASUK blok "JANGAN-TOUCH".
4. `##` File terdampak — daftar path.
5. `##` Pertanyaan untuk reviewer eksternal:
   - Ada regresi tersembunyi pada widget/state/provider yang berubah?
   - Ada pemanggil method/constructor/dependency yang terlewat (audit SEMUA call-site)?
   - Scope sudah pas, tidak ada perubahan di luar tujuan?
   - Ada gate (5-Gate Flutter) yang berisiko gagal?

Setelah file selesai ditulis, laporkan HANYA path file-nya dalam satu baris, contoh:
`Tersimpan: review-out/feature-x-20260617-1530.md`
JANGAN cetak ulang seluruh isi ke terminal — Nerry akan membuka filenya langsung di editor.
