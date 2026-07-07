---
description: Tulis Naskah byte-exact (anchor unik, indent benar, LF) dari PCAC aktif, simpan ber-versi ke review/out/naskah via rev.sh (auto -vN+1, never overwrite)
argument-hint: <label>  (mis. wave1-presence)
---

# /naskah — Naskah eksekusi byte-exact

Susun **Naskah byte-exact** dari **PCAC aktif** di sesi ini, lalu tulis utuh ke file ber-versi.

## Langkah
1. **Alokasikan path** (jangan pernah menimpa versi lama). Jalankan dari root repo:

   ```bash
   NASKAH_PATH=$(bash review/rev.sh naskah $ARGUMENTS)
   ```

   `rev.sh` akan `mkdir -p review/out/naskah`, mencari `-vN` tertinggi untuk label ini, lalu echo path baru `review/out/naskah/NASKAH-<label>-v<N+1>.md`. Wajib ada `<label>` — tanpa argumen = usage-error.
2. Tulis **SELURUH** Naskah ke `$NASKAH_PATH` — LF, tanpa dipotong/diringkas.
3. Laporkan path file dalam **satu baris**.

## Aturan byte-exact (WAJIB)
- Tiap perubahan memakai **anchor byte-exact & UNIK**: cuplikan konteks existing (sebelum/sesudah) yang dijamin **unik** di file, supaya bisa diterapkan tanpa ambiguitas.
- **Hanya tambah method / endpoint / flag BARU.** Tidak menyentuh / menulis-ulang kode lama.
- Indentasi: **PHP 4-spasi**, **Dart 2-spasi**. Line ending **LF**.
- Additive-only · flag baru default **OFF** · **ZERO ROLLBACK**.
- Sertakan blok **JANGAN-TOUCH** (identik PCAC):
  - whitelist & `JET_ADMIN_PHONES`
  - booking (reguler / dropping / rental / paket)
  - `buildRequestBody`
  - `CustomerBookingNotificationService`
  - SJ / KEU flow
  - bridge booking endpoints
  - `sendMessage` & sender lama

## Struktur Naskah (per file)
- **Path file + repo.**
- **Anchor** (cuplikan unik existing) → **blok sisipan BARU** (byte-exact, indent benar).
- Catatan **call-site** yang wajib diverifikasi setelah apply.
- Penutup: ringkasan file terdampak + urutan apply.
