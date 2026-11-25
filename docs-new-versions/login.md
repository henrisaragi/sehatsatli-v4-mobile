## Task Login (Flutter)

Berikut ini task untuk halaman login. **Kontrak API BARU (backend v4)** — beda dari `/auth/login-app` yang mungkin masih dipakai di kode existing: login sekarang **2 langkah** (email+password → OTP email → access_token), bukan 1 langkah dengan hash md5.

## proses bisnis

1. User isi email + password di screen login.
2. Kalau cocok, backend generate OTP 6 digit dan kirim ke email user, lalu mengembalikan `login_token` (sekali pakai, berlaku 5 menit).
3. User pindah ke screen input OTP, masukkan kode 6 digit dari email.
4. Kalau OTP benar, `login_token` langsung tidak berlaku lagi dan backend menerbitkan `access_token` (Bearer, OAuth2/Passport, berlaku ±1 tahun).
5. Simpan `access_token` di secure storage, pakai sebagai header `Authorization: Bearer <access_token>` di semua request berikutnya.

### Endpoint

**Langkah 1 — Login (email & password)**

```
POST /api/auth/login

{
  "email": "henribornok@gmail.com",
  "password": "password"
}
```

200 OK

```
{
  "login_token": "k2JUDcDxfrhMiVTCw2o1eyl0Ydyb4sbFM8yg3tDA24fLhSCO6xyTre8VaSzvx0wu",
  "expires_in": 300
}
```

401 — email/password salah

```
{ "message": "Email atau password salah." }
```

**Langkah 2 — Verifikasi OTP**

```
POST /api/auth/otp/verify

{
  "login_token": "k2JUDcDxfrhMiVTCw2o1eyl0Ydyb4sbFM8yg3tDA24fLhSCO6xyTre8VaSzvx0wu",
  "otp": "123456"
}
```

200 OK

```
{
  "access_token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9...",
  "token_type": "Bearer",
  "expires_in": 31536000
}
```

422 — kemungkinan error (bedakan pesannya di UI):

```
{ "message": "OTP kadaluarsa atau tidak valid, silakan login ulang." }
```

```
{ "message": "OTP salah.", "attempts_remaining": 4 }
```

```
{ "message": "Terlalu banyak percobaan, silakan login ulang." }
```

Maksimal 5 kali percobaan OTP salah, setelah itu `login_token` dibatalkan dan user harus ulang dari langkah 1.

**Profil user setelah login**

```
GET /api/user
Authorization: Bearer <access_token>
```

200 OK

```
{
  "id": "01a0497a-9efc-7107-bcf5-b2c2d4a5c9b9",
  "email": "henribornok@gmail.com",
  "nama_lengkap": "Henri Bornok",
  "no_hp": null,
  "status": "aktif",
  "email_verified_at": "2026-08-28T17:46:14.000000Z",
  "created_at": "2026-08-28T17:46:07.000000Z",
  "updated_at": "2026-08-28T17:46:15.000000Z",
  "roles": [
    { "id": 2, "name": "upt-ksda", "guard_name": "web" }
  ],
  "permissions": ["penyakit.index", "entitas.index"]
}
```

**Status pendaftaran UPT** (dipakai untuk menentukan halaman tujuan setelah login — lihat `register-upt.md`)

```
GET /api/registrasi/status
Authorization: Bearer <access_token>
```

Catatan: endpoint `/api/auth/*` dibatasi throttle 6 request/menit per IP — tangani response `429` dengan pesan "terlalu banyak percobaan, coba lagi nanti".

### Checklist

- [ ] Screen 1: field email + password, tombol masuk → `POST /api/auth/login`.
- [ ] Simpan `login_token` sementara (state/in-memory selama proses OTP, bukan secure storage permanen) + jalankan countdown dari `expires_in` (300 detik) di screen OTP.
- [ ] Tangani error 401 — tampilkan pesan "Email atau password salah." langsung dari response.
- [ ] Screen 2: input OTP 6 digit (numeric, auto-focus/auto-advance), tombol verifikasi → `POST /api/auth/otp/verify` pakai `login_token` dari screen 1.
- [ ] Tangani 3 varian error 422 secara berbeda:
  - OTP salah → tampilkan `attempts_remaining` (mis. "OTP salah, sisa 4 percobaan").
  - `login_token` kedaluwarsa/tidak valid ATAU sudah 5x salah → tampilkan pesan lalu **redirect balik ke screen 1** (login_token harus diminta ulang, tidak ada endpoint resend OTP).
- [ ] Setelah OTP berhasil, simpan `access_token` + `token_type` + `expires_in` ke secure storage, set default header `Authorization: Bearer <access_token>` untuk semua request selanjutnya.
- [ ] Fetch `GET /api/user` setelah login sukses, simpan snapshot user (termasuk `roles`/`permissions`) untuk keperluan RBAC di app.
- [ ] Fetch `GET /api/registrasi/status` untuk menentukan halaman tujuan setelah login (lihat detail status di `register-upt.md`): `404` → belum pernah daftar UPT; `menunggu`/`ditolak`/`terverifikasi` → arahkan sesuai status.
- [ ] Tangani `429` (rate limit) dengan pesan generik "terlalu banyak percobaan, coba lagi nanti" di kedua langkah.
