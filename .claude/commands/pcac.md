---
description: Buat PCAC lengkap byte-grounded dari BRIEF aktif, simpan ber-versi ke review/out/pcac via rev.sh (auto -vN+1, never overwrite)
argument-hint: <label>  (mis. wave1-presence)
---

# /pcac — Pre-Change Analysis & Commitment (byte-grounded)

Susun **PCAC lengkap** dari **BRIEF aktif** di sesi ini, lalu tulis utuh ke file ber-versi.

## Langkah
1. **Alokasikan path** (jangan pernah menimpa versi lama). Jalankan dari root repo:

   ```bash
   PCAC_PATH=$(bash review/rev.sh pcac $ARGUMENTS)
   ```

   `rev.sh` akan `mkdir -p review/out/pcac`, mencari `-vN` tertinggi untuk label ini, lalu echo path baru `review/out/pcac/PCAC-<label>-v<N+1>.md`. Wajib ada `<label>` — tanpa argumen = usage-error.
2. Susun PCAC **byte-grounded**: verifikasi tiap fakta ke kode nyata (sertakan `path:baris`), **bukan** menyalin BRIEF.
3. Tulis **SELURUH** PCAC ke `$PCAC_PATH` — LF, tanpa dipotong/diringkas/placeholder.
4. Laporkan path file dalam **satu baris**.

## Disiplin WAJIB (tegakkan di isi PCAC)
- **Additive-only** · **flag-gated** (flag baru default **OFF**) · **ZERO ROLLBACK**.
- Hanya tambah **method / endpoint / flag BARU** — tidak mengubah tanda tangan atau perilaku yang lama.
- **JANGAN TOUCH:**
  - resolusi **whitelist** & `JET_ADMIN_PHONES`
  - jalur **booking** (reguler / dropping / rental / paket)
  - `buildRequestBody`
  - `CustomerBookingNotificationService`
  - **SJ / KEU** flow
  - **bridge booking** endpoints
  - `sendMessage` & sender lama

## Struktur PCAC (wajib lengkap)
1. Judul + metadata (branch, timestamp, sumber BRIEF).
2. **Temuan grounding vs BRIEF** — byte-exact, sertakan `path:baris`; tandai klaim BRIEF yang meleset.
3. **Keputusan terkunci** (D-1..D-n) — method/endpoint/flag/hook baru.
4. **Scope file** (per repo) + blok **JANGAN-TOUCH**.
5. **Section regresi (WAJIB):** matrix area berisiko + **audit SEMUA call-site** (constructor / method / dependency yang menyentuh simbol diubah).
6. **Gerbang nol-regresi (WAJIB):**
   - **SET full-suite:** total test == baseline (`before==after`), `before_only=∅`, `after_only=∅`.
   - **Kanari regresi:** suite jalur kritikal (mis. Dropping / Rental / Sbb / CustomerBookingNotification / sender) identik baseline.
   - **5-Gate** (analyze / format / test / scope / bersih) untuk sisi Flutter.
7. Keputusan menunggu konfirmasi (bila ada).
