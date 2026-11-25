## Task Registrasi UPT (Flutter)

Berikut ini task untuk halaman registrasi user baru sebagai staff UPT (Unit Pelaksana Teknis). Fitur ini **baru** di backend v4, belum ada di API lama.

## proses bisnis

User yang belum punya akun mendaftar sendiri (guest, tanpa login) sebagai staff sebuah UPT:

1. Pilih **UPT** (dropdown 1).
2. Pilih **unit organisasi** miliknya (dropdown 2, dependent — isinya berubah sesuai UPT yang dipilih di langkah 1).
3. Isi data diri: nama, email, password, NIP (18 digit), jabatan.
4. Submit → akun user langsung dibuat, email verifikasi dikirim, dan status pendaftaran UPT-nya dimulai dari **`menunggu`** sampai disetujui/ditolak admin.
5. User **sudah bisa login** (lihat `login.md`) walau status masih `menunggu` — tapi akses ke fitur-fitur UPT baru penuh setelah status `terverifikasi`. Gunakan endpoint status untuk tahu kondisi terkini dan tampilkan halaman yang sesuai (menunggu approval / ditolak / terverifikasi).

### Endpoint

**Dropdown 1 — Daftar UPT** (tanpa login)

```
GET /api/upt
GET /api/upt?kategori=TAMAN_NASIONAL   (opsional, atau KSDA)
```

200 OK

```
[
  {
    "id": "01a0497a-9efc-7107-bcf5-b2c2d4a5c9b9",
    "nama": "Kerinci Seblat",
    "kategori": "TAMAN_NASIONAL",
    "tipe_balai": "BALAI_BESAR",
    "tipe_grade": "A"
  }
]
```

**Dropdown 2 — Unit organisasi milik UPT terpilih** (dependent, tanpa login)

```
GET /api/upt/{upt_id}/unit-organisasi
```

200 OK — **response flat, bukan tree**. Bangun tampilan berjenjang di sisi Flutter pakai `level` + `parent_id` (level 0 = Kepala, makin besar makin dalam).

```
[
  { "id": "...b9", "nama_unit": "Kepala", "jenis_unit": "KEPALA", "level": 0, "parent_id": null },
  { "id": "...ba", "nama_unit": "Bidang Pengelolaan Taman Nasional Wilayah I", "jenis_unit": "BIDANG_WILAYAH", "level": 1, "parent_id": "...b9" },
  { "id": "...bb", "nama_unit": "Seksi Pengelolaan Taman Nasional Wilayah I", "jenis_unit": "SEKSI_WILAYAH", "level": 2, "parent_id": "...ba" }
]
```

404 kalau `upt_id` tidak valid — `{ "message": "No query results for model [App\\Models\\Upt]." }`

**Submit registrasi** (tanpa login)

```
POST /api/registrasi/upt

{
  "nama": "Budi Santoso",
  "email": "budi.santoso@example.com",
  "password": "password123",
  "password_confirmation": "password123",
  "upt_id": "01a0497a-9efc-7107-bcf5-b2c2d4a5c9b9",
  "unit_organisasi_id": "01a0497a-9efc-7107-bcf5-b2c2d4a5c9ba",
  "nip": "198501012010011001",
  "jabatan": "Kepala Seksi"
}
```

201 Created

```
{
  "message": "Registrasi berhasil, silakan verifikasi email Anda.",
  "user_id": "01a0497a-9efc-7107-bcf5-b2c2d4a5c9bc",
  "entitas_id": "01a0497a-9efc-7107-bcf5-b2c2d4a5c9bd",
  "status_verifikasi": "menunggu"
}
```

422 — contoh error validasi per-field

```
{
  "message": "The given data was invalid.",
  "errors": {
    "email": ["The email has already been taken."],
    "nip": ["NIP sudah terdaftar."],
    "unit_organisasi_id": ["Unit organisasi tidak sesuai dengan UPT yang dipilih."]
  }
}
```

**Cek status pendaftaran** (butuh login — pakai `access_token` dari `login.md`)

```
GET /api/registrasi/status
Authorization: Bearer <access_token>
```

200 OK

```
{
  "status_verifikasi": "menunggu",
  "alasan_penolakan": null,
  "upt": { "id": "...b9", "nama": "Kerinci Seblat" },
  "unit_organisasi": { "id": "...ba", "nama_unit": "Seksi Pengelolaan Taman Nasional Wilayah I" },
  "nip": "198501012010011001",
  "jabatan": "Kepala Seksi"
}
```

404 — user belum pernah daftar UPT sama sekali: `{ "message": "Belum ada pendaftaran UPT." }`

### Validasi field (submit registrasi)

- `nama` — wajib, teks, maks 150 karakter.
- `email` — wajib, format email valid, harus unik (belum pernah dipakai akun lain).
- `password` — wajib, minimal 8 karakter, harus sama dengan `password_confirmation`.
- `upt_id` — wajib, dari dropdown 1.
- `unit_organisasi_id` — wajib, dari dropdown 2 — **harus benar-benar milik `upt_id` yang dipilih** (kalau dropdown 2 di-reset dengan benar tiap ganti UPT, error ini seharusnya tidak pernah muncul).
- `nip` — wajib, **persis 18 digit angka**, harus unik.
- `jabatan` — wajib, teks, maks 100 karakter.

### Checklist

- [ ] Load dropdown UPT dari `GET /api/upt` (opsional filter `kategori` kalau mau ada tab/filter Taman Nasional vs KSDA).
- [ ] Saat UPT dipilih, load dropdown unit organisasi dari `GET /api/upt/{upt_id}/unit-organisasi`. **Reset pilihan unit organisasi setiap kali UPT diganti.**
- [ ] Response unit organisasi flat — tampilkan berjenjang pakai `level`/`parent_id` (indentasi per level), atau minimal tampilkan `nama_unit` di select biasa kalau versi awal belum butuh hierarki visual.
- [ ] Form: nama (teks), email (keyboard email), password + confirm password (obscured, toggle show/hide), NIP (keyboard numeric, validasi persis 18 digit), jabatan (teks).
- [ ] Validasi client-side sebelum submit: email format, password ≥ 8 karakter, password === confirm, NIP persis 18 digit.
- [ ] Submit `POST /api/registrasi/upt`. Sukses (201) → tampilkan pesan "Registrasi berhasil, silakan verifikasi email Anda." lalu arahkan ke halaman **login** (bukan langsung masuk — flow login tetap 2 langkah email/password + OTP, lihat `login.md`).
- [ ] Tangani error 422 per-field: tampilkan pesan di bawah field terkait (`email`, `nip`, `unit_organisasi_id`, dll — pakai key dari `errors`, bukan cuma pesan generik).
- [ ] Setelah user login, panggil `GET /api/registrasi/status` dan arahkan sesuai hasil:
  - `404` → user belum pernah daftar UPT (tampilkan CTA ke form registrasi ini kalau user memang perlu jadi staff UPT).
  - `status_verifikasi = "menunggu"` → halaman info "menunggu persetujuan admin", batasi akses fitur UPT.
  - `status_verifikasi = "ditolak"` → tampilkan `alasan_penolakan`, beri opsi daftar ulang.
  - `status_verifikasi = "terverifikasi"` → lanjut akses normal ke fitur UPT.
