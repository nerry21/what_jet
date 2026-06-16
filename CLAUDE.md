# CLAUDE.md — what_jet (Flutter omnichannel app)

Proyek **Flutter/Dart** (app WhatsJet: WhatsApp-style omnichannel, FCM push, peta OpenStreetMap, voice notes, delivery ticks). Bagian dari `my-omnichannel-workspace` bersama `chatbot_ai` (Laravel) & `hitungan_lkt` (Laravel). **Disiplin kerja sama persis** dua proyek itu, tapi toolchain Dart/Flutter.

## Prinsip Nerry (lintas proyek — WAJIB)
- **Pelan-pelan tapi solid.** Surgical patch, bukan rewrite besar.
- **ZERO ROLLBACK.** Tiap perubahan dipagari & dapat di-rollback (feature flag / fallback bila menyentuh jalur kritikal).
- Bahasa kerja: **Bahasa Indonesia.**
- Energy management = domain keputusan Nerry. Jangan menyuruh istirahat/menunda.
- Nerry menerima rekomendasi dengan "saya ikut rekomendasi".

## Alur kerja gated (sama seperti chatbot_ai/hitungan_lkt)
Web BRIEF -> CC PCAC -> Web review -> CC Naskah byte-exact -> Web review -> CC eksekusi -> **5-Gate** -> commit lokal -> **STOP**. Nerry push/deploy/build manual. CC tidak pernah push.

## 5-GATE (versi Flutter/Dart)
1. **Analyze:** `flutter analyze` -> 0 error (warning pre-existing dicatat, tidak ditambah).
2. **Format:** `dart format --output=none --set-exit-if-changed lib/ test/` -> tidak ada file ter-reformat tak terduga.
3. **Test:** `flutter test` -> hijau; test baru lulus; baseline before==after (tidak ada test lama jadi merah).
4. **Scope:** `git diff --name-status main...HEAD` = file sesuai scope; tidak ada perubahan liar.
5. **Bersih:** `git status` clean (review-out/ ignored); CR=0 (LF); commit heredoc, blank-line baris-2, **no Co-Authored-By, no --no-verify, no dummy commit**.

## Toolchain (BUKAN Laravel)
- Test: `flutter test` (BUKAN `phpunit`). Single file: `flutter test test/path/foo_test.dart`.
- Static: `flutter analyze`; format: `dart format`.
- Deps: `flutter pub get` (BUKAN composer). Tambah paket: `flutter pub add <nama>` — **hanya dengan izin Nerry**.
- Build: `flutter build apk` / `flutter build ipa` — **manual oleh Nerry**, bukan CC.
- TIDAK ada: `php artisan`, `queue:restart`, `route:clear`, `composer`, migrasi DB, deploy SSH.

## Struktur
- Kode: `lib/`. Test: `test/`. Platform: `android/`, `ios/`, `web/`, `windows/`, `macos/`, `linux/`.
- Skill teknis Flutter resmi di `.agents/skills/` (architecting, state, forms, layouts, testing, dll) — rujuk bila relevan.

## Non-negotiables
- Squash-merge via GitHub web UI saja (manual Nerry).
- Push branch fitur OK; **main hanya setelah 5-Gate lulus** + review.
- LF line endings; indent 2-spasi (konvensi Dart).
- Jangan sentuh konfigurasi platform (android/ios/web build, FCM service account, signing) tanpa instruksi eksplisit.
- Jangan ubah jalur kritikal (HTTP client/API, FCM handler, state global) tanpa fallback/flag.

## Review command (.claude/commands/)
- `/export-review [nama]` — simpan PCAC/Naskah utuh ke `review-out/`.
- `/review-packet [base]` — susun paket diff + JANGAN-TOUCH siap copy ke reviewer eksternal.

## Catatan
`settings.json` men-deny `git push`, `ssh`, `scp`, `rm -r/-rf/-fr`. CC berhenti di commit lokal; Nerry yang push & build.
