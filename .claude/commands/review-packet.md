---
description: Susun paket review siap-copy (git diff + 5-Gate Flutter + JANGAN-TOUCH) untuk reviewer eksternal
argument-hint: [base-branch, default main]
allowed-tools: Bash(git diff:*), Bash(git status:*), Bash(git log:*), Bash(git branch:*)
model: opus
---

## Konteks live (otomatis diambil)

- Branch sekarang: !`git branch --show-current`
- Status: !`git status --short`
- File yang berubah vs ${1:-main}: !`git diff --name-status ${1:-main}...HEAD`
- Diff lengkap vs ${1:-main}: !`git diff ${1:-main}...HEAD`
- Pesan commit di branch ini: !`git log ${1:-main}..HEAD --oneline`

## Tugasmu

Susun SATU blok teks siap-copy untuk reviewer eksternal (auditor independen yang TIDAK punya
akses file dan TIDAK ikut menulis kode ini). Reviewer cuma butuh ringkasan perubahan, bukan
seluruh codebase. Format paketnya persis seperti ini:

---
PAKET REVIEW EKSTERNAL — [nama branch]

1. TUJUAN PERBAIKAN (1-3 kalimat)
   [Jelaskan apa yang diperbaiki/ditambah, dari konteks diff. Singkat.]

2. FILE TERDAMPAK (daftar dari --name-status di atas)
   [list path + jenis perubahan: M/A/D]

3. JANGAN-TOUCH — file/area yang SENGAJA tidak disentuh dan kenapa
   [Sebutkan area sensitif berdekatan yang sengaja dibiarkan: service API/HTTP client,
    state/provider lain, widget owner-routing/notify kategori lain, konfigurasi FCM/platform
    channel. Kalau tak relevan, tulis "tidak ada area sensitif berdekatan".]

4. DIFF LENGKAP
   [tempel diff vs base di sini, dalam blok kode]

5. PERTANYAAN UNTUK REVIEWER
   - Ada regresi tersembunyi pada widget/state/provider yang berubah?
   - Ada pemanggil method/constructor/dependency yang terlewat (audit SEMUA call-site)?
   - Scope sudah pas, tidak ada perubahan liar di luar tujuan?
   - 5-Gate Flutter ada yang berisiko gagal?
---

Keluarkan HANYA blok paket itu, rapi, siap aku copy ke reviewer eksternal.
Jangan eksekusi perubahan apa pun.
