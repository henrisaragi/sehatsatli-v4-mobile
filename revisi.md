# Task: Implementasi Flutter — Laporan Umum (Cepat/New & Semua/{id})

Scope **hanya** 2 halaman di web:

- `app/laporan-umum/cepat/new` — form laporan cepat (create)
- `app/laporan-umum/semua/{id}` — form laporan lengkap (4 tahap)

Referensi detail field & endpoint: lihat [new-report.md](new-report.md). Dokumen ini fokus ke breakdown task implementasi.

> Catatan bug yang sudah diperbaiki & **diverifikasi langsung dengan login sungguhan ke API produksi** (bukan cuma baca kode) — jangan replikasi versi lama, ikuti perilaku yang sudah diperbaiki:
>
> 1. **[PALING PENTING] Response `POST masterss` membungkus semua grup opsi di dalam `data.options.*`, bukan flat di `data`.** Response asli: `{success, data: {options: {upt_type: [...], case_types: [...], genders: [...], ...}, trained}}`. Kode web sebelumnya membaca `data[optionName]` langsung (flat) sehingga **semua dropdown/radio/checkbox master data kosong di seluruh aplikasi** — bukan cuma "Tipe UPT" dan "Kesimpulan Awal" yang dilaporkan user, tapi juga Jenis Kelamin, Kelompok Umur, Tipe Konservasi, tags kondisi klinis, dll. **Untuk Flutter:** saat parsing response `masterss`, ambil opsi dari `data['options'][optionName]`, JANGAN `data[optionName]`. Juga perhatikan: `id` pada beberapa grup (mis. `upt_type`) adalah **string kode** (`"PUSAT"`, `"KSDA"`), bukan angka — jangan asumsikan semua id master data numerik.
> 2. **"6. Tipe UPT" & "7. Nama UPT"** seharusnya auto-terisi dari user login. Response `POST auth/login` asli: `{success, data: {user: {..., upt_id: 1, upt_type: "PUSAT"}, access_token}}` — field `upt_type`/`upt_id` ada **di dalam** object `user` yang nested, bukan flat di root `data`. **Untuk Flutter:** mapping model hasil login harus mengambil `data.user.upt_type` / `data.user.upt_id`, bukan `data.upt_type`/`data.upt_id`. Field ini juga baru bisa auto-select dengan benar kalau bug #1 di atas juga sudah ditangani (kalau daftar opsi `upt_type` kosong, value yang benar pun tidak akan ketemu pasangannya di dropdown).
> 3. Field **"27. Kesimpulan awal"** (`temporary_diagnosis_id`) gagal tersimpan meski sudah dipilih — akibat langsung dari bug #1 (opsi `case_types` kosong). Filter `id < 3` pada `case_types` juga rapuh secara independen — **Untuk Flutter:** kalau perlu membatasi ke 2 opsi pertama, terapkan fallback (tampilkan semua opsi bila hasil filter kosong) supaya field wajib ini tidak pernah "tidak bisa dipilih".
> 4. Upload foto (`file`/`file_verification`/`file_investigation` salah destructure) — diperbaiki di `generalReportSlice.js`. Endpoint `general-reports/uploadPhoto` sekarang benar-benar terpanggil untuk ketiga tahap yang punya field foto (Investigasi, Verifikasi, Investigasi Lanjutan).
> 5. **[Regresi dari fix #4, ketahuan saat testing submit sungguhan]** Field foto SELALU punya default value truthy (array kosong `[]` untuk media yang belum ada), jadi cek `if (file) { upload... }` yang naif akan SELALU memicu upload — termasuk saat user tidak pilih foto sama sekali — dan menyebabkan submit gagal total (backend menolak payload foto kosong/tidak valid). **Untuk Flutter:** jangan cek "field foto ada isinya" saja untuk memutuskan perlu upload atau tidak — cek eksplisit apakah user benar-benar memilih file BARU (mis. path lokal / bytes baru), terpisah dari data foto lama yang sekadar ditampilkan untuk preview.

---

## 0. Persiapan (shared, dipakai kedua halaman)

- [ ] Setup HTTP client (dio/http) dengan base URL dari config (`SERVER_URL`, contoh `.env`: `VITE_SERVER_URL`).
- [ ] Interceptor: semua request `POST`, header `Content-Type: application/json`, `Accept: application/json`, `Authorization: Bearer {access_token}` (token dari hasil login, simpan di secure storage).
- [ ] Buat helper `postJson(path, body)` → return `{success, data}`. Kalau HTTP non-OK → treat sebagai `{success:false}` (ikuti perilaku web, jangan asumsikan backend selalu kirim error message terstruktur).
- [ ] Buat helper `postMultipart(path, fields, filePath)` untuk endpoint upload (`Content-Type: multipart/form-data`, tanpa header manual selain Authorization).
- [ ] Model `GeneralReport` dengan sub-object: `species`, `diagnoses`, `reporter`, `location`, `upt`, `verification`, `lab`, `investigation`, `media` (list), `user`, `report_code`, `id`.
- [ ] Repository/service `GeneralReportService` dengan method:
  - `getOne(id)` → `POST general-reports/getOne {id}`
  - `save(data)` → `POST general-reports/save {...}`
  - `saveVerify(data)` → `POST general-reports/saveVerify {...}`
  - `saveLab(data)` → `POST general-reports/saveLab {...}`
  - `saveInvestigation(data)` → `POST general-reports/saveInvestigation {...}`
  - `uploadPhoto(id, filePath)` → `POST general-reports/uploadPhoto` multipart `{id, file}`
- [ ] Service pendukung dropdown (fetch sekali & cache in-memory selama sesi):
  - `MasterService.getAll()` → `POST masterss` (null body) → **ambil dari `response.data.options`** (bukan `response.data` langsung — lihat catatan bug #1 di atas), cache seluruh object; ambil per-key: `species_category`, `animal_types`, `age_groups`, `clinical_signs`, `follow_ups`, `case_types`, `genders`, `verification_actions`, `lab_actions`, `conservation_types`, `conservation_institutions`, `upt_type`.
  - `SpeciesService.getAll()` → `POST species/getAll {}`
  - `DiseaseService.getAll()` → `POST diseases/getAll {}`
  - `UptService.getAll()` → `POST upts/getAll {}`
  - `LocationService.getAll()` → `POST locations` (null body) — data wilayah berjenjang (province/district/subdistrict/village), cache lama (mis. 30 hari, boleh disederhanakan jadi cache selama sesi app).

---

## 1. Halaman `laporan-umum/cepat/new` — Form Laporan Cepat

Tujuan: form pendek untuk pelaporan awal di lapangan, submit sekali, lalu **auto-navigate ke halaman lengkap** dengan id hasil create.

### 1.1 UI Form

- [ ] Field `report_date` — date picker, wajib.
- [ ] Field `location` — textarea, max 180 char, wajib.
- [ ] Field `protected` — toggle/switch "Apakah hewan/satwa dilindungi?", wajib, default `false`.
- [ ] Kondisional berdasarkan `protected`:
  - jika `false` → tampilkan `species_name` (text, wajib).
  - jika `true` → tampilkan `species_id` (dropdown searchable dari `SpeciesService.getAll()`, wajib).
- [ ] Field `dead` — number, wajib (jumlah hewan ditemukan mati).
- [ ] Field `live` — number, wajib (jumlah hewan ditemukan sakit/hidup).
- [ ] Field `description` — textarea, max 180 char, wajib.
- [ ] Tombol Simpan (submit) + Batal.

### 1.2 Validasi

- [ ] Semua field wajib di atas tidak boleh kosong sebelum submit.
- [ ] `species_name` wajib hanya jika `protected == false`; `species_id` wajib hanya jika `protected == true` (samakan dengan logika `yup` di web — jangan wajibkan keduanya sekaligus).

### 1.3 Submit flow

- [ ] Saat masuk halaman dengan mode "new": **tidak ada fetch API**, langsung state kosong (`{}`) — jangan panggil `getOne`.
- [ ] Saat submit: panggil `GeneralReportService.save(formData)` → `POST general-reports/save`.
  - Body = data form saja (untuk create baru tidak ada data lama yang perlu digabung).
- [ ] Jika `success == true`:
  - Tampilkan notifikasi sukses ("Data berhasil disimpan").
  - **Navigate ke halaman lengkap**: `app/laporan-umum/semua/{result.data.id}` (bukan kembali ke list). Ini best-practice flow di web — pertahankan agar user langsung lanjut isi tahap investigasi.
- [ ] Jika `success == false`: tampilkan notifikasi error ("Error, data belum disimpan"), tetap di halaman form (jangan hilangkan data yang sudah diisi user).

---

## 2. Halaman `laporan-umum/semua/{id}` — Form Laporan Lengkap (4 Tahap)

Tujuan: form lengkap berbasis tab, tiap tab punya endpoint save sendiri (tidak ada 1 tombol submit besar untuk semua tahap).

### 2.1 Init halaman

- [ ] Jika `id == "new"` → state kosong (`{}`), tidak fetch API.
- [ ] Jika `id` berupa angka → panggil `GeneralReportService.getOne(id)` → `POST general-reports/getOne {id}`, simpan hasil sebagai `currentReport` (termasuk seluruh sub-object: `species`, `diagnoses`, `reporter`, `location`, `upt`, `verification`, `lab`, `investigation`, `media`).
- [ ] Tampilkan header: `KODE LAPORAN: {report_code}`.
- [ ] Buat 4 tab: **1. Investigasi**, **2. Verifikasi Dokter Hewan**, **3. Konfirmasi Dari Hasil Lab**, **4. Investigasi Lanjutan**. Semua tab dirender dari `currentReport` yang sama (state di level halaman, bukan per-tab).
- [ ] Setelah save di tab manapun sukses → tampilkan notifikasi sukses → navigate kembali ke list `app/laporan-umum`.

### 2.2 Tab 1 — Investigasi

Gabungan 3 bagian dalam satu form (submit sekaligus):

**Data Species** (`data.species`):

- [ ] `protected` toggle, default `true`.
- [ ] jika `true` → `protected_species` dropdown dari `SpeciesService` (default dari `species.protected_species` atau fallback `species_id`).
- [ ] jika `false` → `category` dropdown (master `species_category`), `species_name` (text, wajib), `species_latin_name` (text), `species_family` dropdown (master `animal_types`).
- [ ] `species_age` radio (master `age_groups`).
- [ ] `population` number.

**Tahap Investigasi / Diagnose** (`data.diagnoses`):

- [ ] `report_date` date, wajib.
- [ ] `live` number, wajib; jika `> 0` tampilkan `live_sign` (multi-select tags dari master `clinical_signs` filter `type == "Live"`) + `live_sign_other` (textarea).
- [ ] `dead` number, wajib; jika `> 0` tampilkan `dead_sign` (multi-select tags master `clinical_signs` filter `type == "Dead"`) + `dead_sign_other` (textarea).
- [ ] `chronological` textarea.
- [ ] `sampling` textarea.
- [ ] `follow_up` dropdown/text dari master `follow_ups`.
- [ ] `temporary_diagnosis_id` radio wajib, master `case_types` filter `id < 3` — **dengan fallback**: jika hasil filter kosong (data master tidak punya id < 3), tampilkan semua opsi `case_types` agar field wajib ini selalu bisa dipilih.
- [ ] `diagnosis` textarea.
- [ ] `file` — multi image picker (kamera/galeri). Field key harus **`file`** (jangan diganti nama lain, ini yang dipakai backend upload untuk tahap Investigasi).

**Data Administrasi — Reporter** (`data.reporter`, fallback `data.user`):

- [ ] `name` text wajib (default dari user login jika reporter belum ada).
- [ ] `gender` radio wajib (master `genders`).
- [ ] `occupation` text.
- [ ] `phone` text wajib.
- [ ] `address` textarea (fallback `data.upt.address`).

**Data Administrasi — Lokasi** (`data.location`, fallback `data.upt`):

- [ ] `upt_type` — dropdown master `upt_type`, **read-only/disabled**, auto-isi dari user login. Ambil dari field `upt_type` pada object user hasil login (kemungkinan bersarang, mis. `loginResult.user.upt_type` — cek response asli `auth/login`, jangan asumsikan flat).
- [ ] `upt_id` — dropdown `UptService`, difilter `type == upt_type`, **read-only/disabled**, auto-isi dari `upt_id` pada object user hasil login (sama seperti `upt_type`, kemungkinan bersarang).
- [ ] `location_name` text.
- [ ] `location_description` textarea.
- [ ] `conservation_type` radio (master `conservation_types`), default `1`.
  - jika `1` → `insitu_conservation` (multi-checkbox master `conservation_institutions` filter `conservation_type == "IS"`) + `insitu_other` text.
  - jika `2` → `exsitu_conservation` (multi-checkbox master `conservation_institutions` filter `conservation_type == "ES"`) + `exsitu_other` text.
- [ ] `latitude`, `longitude` — idealnya diisi otomatis dari GPS device (nilai tetap bisa diedit manual), fallback `data.upt.latitude/longitude`.
- [ ] `province_id` dropdown wajib (`LocationService`, `provinces`).
- [ ] `district_id` dropdown wajib, muncul setelah `province_id` terisi, filter by `province_id` (`districts`).
- [ ] `subdistrict_id` dropdown wajib, muncul setelah `district_id` terisi, filter by `district_id` (`subdistricts`).
- [ ] `village_id` dropdown wajib, muncul setelah `subdistrict_id` terisi, filter by `subdistrict_id` (`villages`).

**Submit tab 1:**

- [ ] Gabungkan seluruh field di atas + data lama (`currentReport`) jadi satu payload flat (samakan struktur key seperti di web — field-field ini di top-level body, bukan bersarang dalam `species`/`diagnoses`/dst saat dikirim; hanya response `getOne` yang bersarang).
- [ ] Pisahkan field `file` dari payload JSON sebelum kirim (`file` tidak boleh ikut di-JSON-kan).
- [ ] `POST general-reports/save` dengan payload tanpa `file`.
- [ ] Jika sukses **dan** ada `file` (gambar dipilih user) → panggil `GeneralReportService.uploadPhoto(result.data.id, file)` → `POST general-reports/uploadPhoto` multipart `{id, file}`.
- [ ] Setelah itu → sukses notif → navigate ke list.

### 2.3 Tab 2 — Verifikasi Dokter Hewan (`data.verification`)

- [ ] `id` — hidden, isi dari `currentReport.id` (ikut dikirim di body, sesuai perilaku web).
- [ ] `verified_date` date wajib.
- [ ] `verification` textarea wajib.
- [ ] `verified` toggle (suspek penyakit).
- [ ] jika `verified == true` → `temporary_disease_id` dropdown dari `DiseaseService`.
- [ ] `sampling` textarea.
- [ ] `action` textarea/dropdown master `verification_actions`.
- [ ] `doctor_information` textarea.
- [ ] `involved_doctors` — list dinamis (repeater), tiap item: `name`, `occupation`, `date`, `sign` (boolean). User bisa tambah/hapus baris.
- [ ] `file_verification` — multi image picker. **Field key harus `file_verification`** (nama field ini penting untuk backend, jangan disamakan dengan tab lain).

**Submit tab 2:**

- [ ] Pisahkan `file_verification` dari payload JSON.
- [ ] `POST general-reports/saveVerify` dengan payload tanpa `file_verification`.
- [ ] Jika sukses **dan** ada `file_verification` → `POST general-reports/uploadPhoto` multipart `{id: result.data.id, file: file_verification}`.
- [ ] Sukses notif → navigate ke list.

### 2.4 Tab 3 — Konfirmasi Dari Hasil Lab (`data.lab`)

- [ ] `final_disease_id` dropdown dari `DiseaseService` (opsional).
- [ ] `final_diagnosis` textarea wajib.
- [ ] `follow_up` textarea/dropdown master `lab_actions`, wajib.
- [ ] Tidak ada field upload foto di tab ini.

**Submit tab 3:**

- [ ] `POST general-reports/saveLab` dengan payload gabungan (tidak perlu pisah file).
- [ ] Sukses notif → navigate ke list.

### 2.5 Tab 4 — Investigasi Lanjutan (`data.investigation`)

- [ ] `investigation_date_from`, `investigation_date_to` — date range, keduanya wajib.
- [ ] `inspection_method` textarea wajib.
- [ ] `evidence` — list dinamis (repeater), tiap item: `type_of_evidence`, `amount`, `description`. Wajib minimal 1 item (samakan validasi web: field ini required sebagai array).
- [ ] `file_investigation` — multi image picker. **Field key harus `file_investigation`**.
- [ ] `follow_up_carried_out` textarea wajib.
- [ ] `additional_information` textarea wajib.
- [ ] `data_investigation` — list dinamis (repeater), tiap item: `date`, `name`, `occupation`, `sign` (boolean).

**Submit tab 4:**

- [ ] Pisahkan `file_investigation` dari payload JSON.
- [ ] `POST general-reports/saveInvestigation` dengan payload tanpa `file_investigation`.
- [ ] Jika sukses **dan** ada `file_investigation` → `POST general-reports/uploadPhoto` multipart `{id: result.data.id, file: file_investigation}`.
- [ ] Sukses notif → navigate ke list.

### 2.6 Tampilkan foto existing

- [ ] Untuk tiap tab yang punya field foto, jika `currentReport.media` (atau sub-object terkait) sudah berisi data, tampilkan sebagai thumbnail/preview (pakai `original_url` dari tiap item media) sebelum user upload foto baru — jangan blokir submit walau tidak ada foto baru dipilih (foto opsional).

---

## 3. Hal-hal umum yang perlu konsisten di kedua halaman

- [ ] Loading state saat fetch detail (`getOne`) dan saat proses submit (`processing`), disable tombol submit ketika sedang processing untuk cegah double-submit.
- [ ] Semua endpoint pakai method `POST` walau secara semantik ada yang "get" — jangan diganti ke `GET` walaupun terasa lebih RESTful, backend memang didesain begitu.
- [ ] Response gagal (`success:false` atau HTTP non-OK) → tampilkan pesan generik ("Error, data belum disimpan" / "Gagal memuat data"), backend tidak selalu mengembalikan pesan error spesifik.
- [ ] Setelah submit sukses di tab manapun pada halaman "semua/{id}", app langsung kembali ke list laporan (`app/laporan-umum`) — bukan tetap di form atau pindah tab otomatis.
- [ ] Simpan token & data user login (untuk auto-isi `upt_type`, `upt_id`, `name`, `gender`, dst di form reporter/lokasi).

---

## 4. Out of scope (jangan dikerjakan dalam task ini)

- Halaman list `app/laporan-umum` (list & filter laporan).
- Modul `species`, `disease`, `upt`, `user` CRUD penuh — cukup endpoint `getAll` untuk kebutuhan dropdown di atas.
- Modul community reports / dashboard.
