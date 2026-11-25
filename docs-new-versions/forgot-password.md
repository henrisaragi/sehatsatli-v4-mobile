## Task Lupa Password (Flutter)

Berikut ini task untuk halaman lupa password. Endpoint ini **baru dibuat** di backend v4 (belum ada sebelumnya) — polanya sengaja dibuat mirip flow login OTP di `login.md`, ditambah satu langkah untuk mengatur password baru.

## proses bisnis

1. User isi email di halaman "Lupa Password".
2. Kalau email terdaftar, backend generate OTP 6 digit, kirim ke email, dan mengembalikan `reset_token` (sekali pakai, berlaku 5 menit).
3. User pindah ke screen input OTP, masukkan kode 6 digit dari email.
4. Kalau OTP benar, `reset_token` yang sama ditandai terverifikasi (bukan diganti) — dipakai sekali lagi pada langkah terakhir.
5. User isi password baru + konfirmasi, submit dengan `reset_token` yang sama.
6. Password langsung berubah. **Semua access token yang pernah diterbitkan untuk user tersebut ikut dicabut** — kalau user login di perangkat lain, sesi itu ikut ter-logout dan harus login ulang.

### Endpoint

**Langkah 1 — Minta OTP**

```
POST /api/auth/password/otp/request

{
  "email": "henribornok@gmail.com"
}
```

200 OK

```
{
  "reset_token": "k2JUDcDxfrhMiVTCw2o1eyl0Ydyb4sbFM8yg3tDA24fLhSCO6xyTre8VaSzvx0wu",
  "expires_in": 300
}
```

404 — email tidak terdaftar

```
{ "message": "Email tidak terdaftar." }
```

**Langkah 2 — Verifikasi OTP**

```
POST /api/auth/password/otp/verify

{
  "reset_token": "k2JUDcDxfrhMiVTCw2o1eyl0Ydyb4sbFM8yg3tDA24fLhSCO6xyTre8VaSzvx0wu",
  "otp": "123456"
}
```

200 OK — `reset_token` yang sama dikembalikan, sekarang siap dipakai di langkah 3

```
{
  "message": "OTP terverifikasi, silakan atur password baru.",
  "reset_token": "k2JUDcDxfrhMiVTCw2o1eyl0Ydyb4sbFM8yg3tDA24fLhSCO6xyTre8VaSzvx0wu"
}
```

422 — kemungkinan error (bedakan pesannya di UI, sama seperti login OTP):

```
{ "message": "OTP kadaluarsa atau tidak valid, silakan ulangi dari awal." }
```

```
{ "message": "OTP salah.", "attempts_remaining": 4 }
```

```
{ "message": "Terlalu banyak percobaan, silakan ulangi dari awal." }
```

Maksimal 5 kali percobaan OTP salah, setelah itu `reset_token` dibatalkan dan user harus ulang dari langkah 1.

**Langkah 3 — Atur password baru**

```
POST /api/auth/password/otp/reset

{
  "reset_token": "k2JUDcDxfrhMiVTCw2o1eyl0Ydyb4sbFM8yg3tDA24fLhSCO6xyTre8VaSzvx0wu",
  "password": "password-baru123",
  "password_confirmation": "password-baru123"
}
```

200 OK

```
{ "message": "Password berhasil diubah, silakan login." }
```

422 — `reset_token` belum diverifikasi (langkah 2 dilewati), sudah kedaluwarsa, atau sudah pernah dipakai (sekali pakai):

```
{ "message": "Token reset tidak valid atau belum diverifikasi, silakan ulangi dari awal." }
```

422 — validasi password (mis. konfirmasi tidak cocok, kurang dari 8 karakter) mengikuti bentuk error standar Laravel:

```
{
  "message": "The given data was invalid.",
  "errors": {
    "password": ["The password field confirmation does not match."]
  }
}
```

Catatan: endpoint `/api/auth/*` (termasuk ketiga endpoint ini) dibatasi throttle 6 request/menit per IP — tangani response `429` dengan pesan "terlalu banyak percobaan, coba lagi nanti".

### Validasi field

- `email` (langkah 1) — wajib, format email valid.
- `otp` (langkah 2) — wajib, persis 6 digit angka.
- `password` (langkah 3) — wajib, minimal 8 karakter, harus sama dengan `password_confirmation`.

### Checklist

- [ ] Screen 1: field email, tombol kirim → `POST /api/auth/password/otp/request`.
- [ ] Tangani error 404 — tampilkan pesan "Email tidak terdaftar." langsung dari response.
- [ ] Simpan `reset_token` sementara (state/in-memory selama proses, bukan secure storage) + jalankan countdown dari `expires_in` (300 detik) di screen OTP.
- [ ] Screen 2: input OTP 6 digit (numeric, auto-focus/auto-advance), tombol verifikasi → `POST /api/auth/password/otp/verify` pakai `reset_token` dari screen 1.
- [ ] Tangani 3 varian error 422 secara berbeda (sama seperti `login.md`):
  - OTP salah → tampilkan `attempts_remaining`.
  - `reset_token` kedaluwarsa/tidak valid ATAU sudah 5x salah → tampilkan pesan lalu **redirect balik ke screen 1** (tidak ada endpoint resend OTP, harus minta ulang).
- [ ] Screen 3: field password baru + konfirmasi (obscured, toggle show/hide) → `POST /api/auth/password/otp/reset` pakai `reset_token` yang sama dari screen 1/2.
- [ ] Validasi client-side sebelum submit: password ≥ 8 karakter, password === confirm.
- [ ] Tangani error 422 di screen 3 — bedakan pesan generik "token tidak valid/belum diverifikasi" (jangan tampilkan di field, arahkan balik ke screen 1) dari error validasi per-field `password` (tampilkan di bawah field).
- [ ] Setelah sukses (200), tampilkan pesan "Password berhasil diubah, silakan login." dan arahkan ke halaman **login** (lihat `login.md`) — jangan asumsikan user otomatis login, endpoint ini tidak mengembalikan `access_token`.
- [ ] Karena semua token lama ikut dicabut, kalau user sedang login di app saat melakukan reset password (mis. dari halaman Ubah Password di Profil, bukan alur guest), pastikan app langsung clear secure storage + arahkan ke halaman login setelah sukses — access token lama di memori/secure storage sudah tidak valid lagi.
- [ ] Tangani `429` (rate limit) dengan pesan generik "terlalu banyak percobaan, coba lagi nanti" di ketiga langkah.
