# CLAUDE.md — SehatSatli Flutter Project Guide

> **SehatSatli (Sistem Informasi Kesehatan Satwa Liar)**  
> Mobile Application Architecture, Offline-First Guidelines, API Specifications & Design Tokens.

---

# Workspace Project Folder

| Project                   | Path                                                    |
| ------------------------- | ------------------------------------------------------- |
| Backend API (Laravel, v4) | `/Users/henrisaragi/Herd/sehatsatli-v4`                 |
| Frontend web (React)      | `/Users/henrisaragi/Development/sehatsatli-v2-frontend` |

- **Production API base URL**: `https://sehatsatli.ksdae.kehutanan.go.id/api-v4/api/` (`ApiEndpoints.baseUrl`). Endpoint paths are relative to it and carry **no** `api/` prefix (e.g. `auth/login`).
- Local backend (Herd): `http://sehatsatli-v4.test/api`
- See the `project-paths` skill for when and how to check the backend and web code.

---

## 1. Project Overview & Architecture Principles

SehatSatli is a mobile application used by field officers, wildlife veterinarians, and conservation agencies (KLHK, BKSDA, Taman Nasional, LU/LK) for wildlife health surveillance, reporting, and case investigation.

### Key Architectural Guidelines

1. **Offline-First Priority**: Field officers operate in remote conservation areas without network coverage. Form entry, offline photo handling, and geolocation tracking **must work 100% offline**. Data synchronization occurs automatically in the background when network reachability is restored.
2. **Idempotency via `client_uuid`**: Every report created on the device gets a persistent UUID (`local_reports.client_id`, sent as `client_uuid`). `POST laporan` returns the existing laporan (200) when the same user retries with the same `client_uuid`, so retries never duplicate records.
3. **FlutterFlow Compatibility**: Keep components, custom data types, API group mappings, and custom actions compatible with FlutterFlow export standards while allowing clean native Flutter maintenance.
4. **Single Source of Visual Truth**: Adhere strictly to the design tokens derived from the SehatSatli logo (`#17B273` Primary Green, `#E67E22` Secondary Orange).

---

## 2. Tech Stack & Core Dependencies

| Layer                  | Component / Package                                       | Description & Usage                                                      |
| ---------------------- | --------------------------------------------------------- | ------------------------------------------------------------------------ |
| **Framework**          | Flutter 3.x (Dart 3.x)                                    | Core mobile app framework                                                |
| **State Management**   | App State / Provider / Bloc                               | Ephemeral state, user session, connectivity flags                        |
| **Local Database**     | `sqflite` / `drift`                                       | Relational local storage for reports, sync queue, photos & master cache  |
| **Secure Storage**     | `flutter_secure_storage`                                  | Encrypted storage for OAuth Passport Bearer tokens                       |
| **Networking**         | `http` / `dio` (API Group)                                | REST API client for backend communication                                |
| **Connectivity**       | `connectivity_plus`                                       | Real-time network status monitoring                                      |
| **UUID Generator**     | `uuid`                                                    | Device-side `client_id` generation                                       |
| **Media Handling**     | `image_picker`, `path_provider`, `flutter_image_compress` | Offline image capture, storage, and compression prior to base64 encoding |
| **Location Services**  | `geolocator`                                              | Automatic GPS coordinate capturing for report locations                  |
| **Push Notifications** | `firebase_messaging`                                      | Handling FCM push notifications for critical alerts                      |

---

## 3. Directory & File Structure

```
lib/
├── main.dart
├── core/
│   ├── constants/
│   │   ├── app_colors.dart        # Design tokens & color palettes
│   │   ├── app_typography.dart    # Poppins & Inter typography styles
│   │   └── api_endpoints.dart     # Endpoint paths (auth:api group)
│   ├── network/
│   │   ├── api_client.dart        # API Group wrapper & header interceptor
│   │   ├── connectivity_service.dart # Network reachability monitor
│   │   └── api_error_text.dart    # User-facing error wording (network/429/5xx, 422 field labels)
│   ├── storage/
│   │   ├── secure_storage.dart    # Passport bearer token management
│   │   └── local_database.dart    # SQLite initialization & schema definitions
│   └── utils/
│       ├── uuid_generator.dart
│       └── image_compressor.dart
├── data/
│   ├── models/                    # Custom Data Types & API Models
│   │   ├── general_report_model.dart
│   │   ├── reporter_model.dart
│   │   ├── location_model.dart
│   │   ├── species_model.dart
│   │   ├── diagnosis_model.dart
│   │   ├── investigation_model.dart
│   │   ├── verification_model.dart
│   │   ├── lab_model.dart
│   │   ├── acknowledgement_model.dart
│   │   └── master_options_model.dart
│   ├── local/                     # Offline storage DAOs
│   │   ├── report_dao.dart
│   │   ├── sync_queue_dao.dart
│   │   ├── photo_dao.dart
│   │   └── master_cache_dao.dart
│   └── repositories/
│       ├── auth_repository.dart
│       ├── report_repository.dart
│       ├── sync_repository.dart
│       └── master_repository.dart
├── logic/                         # State management / Sync Engine
│   ├── sync_engine.dart           # FIFO Queue sync engine logic
│   ├── auth_cubit/provider.dart
│   └── report_form_cubit/provider.dart
└── presentation/
    ├── common_widgets/
    │   ├── status_chip.dart       # Sync & report status badges
    │   ├── offline_banner.dart    # Sticky offline mode banner
    │   └── training_banner.dart   # Training mode warning banner
    ├── screens/
    │   ├── auth/                  # Login & Password Change screens
    │   ├── dashboard/             # Home summary & quick statistics
    │   ├── reports/               # Report listing (Tabs: All, Draft, Pending, Failed)
    │   ├── report_form/           # Multi-step report form stepper
    │   ├── report_detail/         # Accordion/Tab detailed report view
    │   ├── reference/             # Master species & disease lookup
    │   └── profile/               # User profile, FCM status, manual sync trigger
    └── routes/
```

---

## 4. Design Tokens & Visual Guidelines

### 4.1 Theme Colors (FlutterFlow Theme Settings Mapping)

| FlutterFlow Slot      | Hex Code  | Purpose & Application                                                        |
| --------------------- | --------- | ---------------------------------------------------------------------------- |
| `primary`             | `#17B273` | Logo Primary Green — Main buttons, AppBar, active indicators, selected icons |
| `secondary`           | `#E67E22` | Logo Secondary Orange — Accents, "Protected/Priority" badges, Report FAB     |
| `tertiary`            | `#2980B9` | Information blue — Links, secondary dashboard chart elements                 |
| `alternate`           | `#E5E7EB` | Neutral borders & dividers                                                   |
| `primaryText`         | `#1F2937` | Headings & primary body text                                                 |
| `secondaryText`       | `#555555` | Captions, subtitles, secondary label text                                    |
| `primaryBackground`   | `#FFFFFF` | Default page background                                                      |
| `secondaryBackground` | `#F8F9FA` | Card & section background (`$light`)                                         |
| `accent1`             | `#E7F7F1` | `primary-light` — Background badge for "Verified / Synced"                   |
| `accent2`             | `#FDEDDF` | `secondary-light` — Background badge for "Priority / Pending Sync"           |
| `accent3`             | `#EBF5FB` | `info-light` — Background badge for "Local Draft / Info"                     |
| `accent4`             | `#FDEDEC` | `danger-light` — Background badge for "Sync Error / Rejected"                |
| `success`             | `#17B273` | Status: Report synced, verification complete                                 |
| `warning`             | `#E67E22` | Status: Pending sync, awaiting verification, training mode                   |
| `error`               | `#C0392B` | Status: Sync failed, validation error, critical alert                        |
| `info`                | `#2980B9` | Status: Local draft, general notification                                    |

**Custom Utility Colors:**

- `dark`: `#343A40` (Text on dark overlays / map markers)
- `offlineBannerBg`: `#343A40` at 92% opacity
- `trainingModeBg`: `#FDEDDF`

### 4.2 Typography System

| Style Token    | Font Family      | Size / Weight | Usage                               |
| -------------- | ---------------- | ------------- | ----------------------------------- |
| `displaySmall` | Poppins SemiBold | 22pt / 600    | Main page titles, dashboard headers |
| `titleLarge`   | Poppins Medium   | 18pt / 500    | Card titles, form section titles    |
| `bodyLarge`    | Inter Regular    | 15pt / 400    | Main body copy, input form labels   |
| `bodyMedium`   | Inter Regular    | 13pt / 400    | Description copy, table content     |
| `bodySmall`    | Inter Regular    | 11pt / 400    | Timestamps, metadata, helper text   |
| `labelLarge`   | Inter Medium     | 13pt / 500    | Button text                         |

### 4.3 Layout Metrics & Radius

- **Spacing Scale**: 4pt grid (`xs: 4`, `s: 8`, `m: 16`, `l: 24`, `xl: 32`)
- **Border Radius**: Card `12px`, Button `10px`, Input `8px`, Chip `999px (Pill)`
- **Elevation**: Use flat/subtle elevation (`elevation: 1`, shadow blur 8, opacity 6%) to match web admin interface.

---

## 5. Offline-First Architecture & Sync Engine

### 5.1 SQLite Schema (`sqflite`/`drift`)

```sql
-- 1. Full report JSON storage (Local Drafts + Synced Snapshots)
CREATE TABLE local_reports (
  client_id       TEXT PRIMARY KEY,       -- Device-generated UUID
  server_id       INTEGER,                -- Server laporan UUID (stored as TEXT), set by the create's response
  report_code     TEXT,                   -- Populated after server generates code
  payload_json    TEXT NOT NULL,          -- Complete nested payload structure
  sync_status     TEXT NOT NULL,          -- draft | pending | syncing | synced | failed
  last_error      TEXT,
  retry_count     INTEGER DEFAULT 0,
  created_at      TEXT NOT NULL,
  updated_at      TEXT NOT NULL
);

-- 2. FIFO Sync Operations Queue
CREATE TABLE sync_queue (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  client_id       TEXT NOT NULL,          -- FK to local_reports.client_id
  endpoint        TEXT NOT NULL,          -- e.g. 'laporan' or 'laporan/{laporan}/investigasi' ({laporan} resolved at sync time)
  method          TEXT NOT NULL DEFAULT 'POST', -- POST | PUT | UPLOAD (photo job)
  payload_json    TEXT NOT NULL,          -- Operation payload snapshot
  status          TEXT NOT NULL DEFAULT 'pending', -- pending | in_progress | done | failed
  retry_count     INTEGER DEFAULT 0,
  last_error      TEXT,
  created_at      TEXT NOT NULL
);

-- 3. Photos have no table of their own: pending paths live in
--    local_reports.payload_json.foto_lokal, each with an 'UPLOAD' sync_queue job.

-- 4. Read-Only Master Cache
CREATE TABLE master_cache (
  cache_key       TEXT PRIMARY KEY,       -- 'spesies' | 'penyakit'
  data_json       TEXT NOT NULL,
  fetched_at      TEXT NOT NULL
);
```

### 5.2 Synchronization Engine Execution Flow (`runSyncQueue`, `lib/data/repositories/sync_repository.dart`)

Every write is saved to `local_reports` (a flat snapshot shaped like `GET laporan/{id}`) and queued in `sync_queue` first; `ReportRepository` then drains the queue immediately when online. There is no separate "send now" path.

1. **Guard Check**: skip if `isSyncing`; skip without a token.
2. **Reachability Check**: `GET {hostUrl}up` (Laravel health route, 5s timeout). If unreachable, halt.
3. **FIFO Fetch**: pending jobs ordered by `created_at ASC, id ASC`. Reports with a `failed` job are **blocked** (their later jobs wait) until the user taps "Kirim ulang" (`retryFailed` resets them to pending).
4. **Iterative Sync**:
   - Endpoints containing `{laporan}` are resolved from `local_reports.server_id` (set by the create's response). No server id yet → block the report for this run.
   - `method = 'UPLOAD'` jobs are photos: `POST laporan/{id}/foto/sign-upload` → raw `PUT` of the file to the presigned MinIO URL → `POST laporan/{id}/foto {object_key}`.
   - **2xx**: job `done`; the create stores `server_id`; `tahap` only moves forward; report becomes `synced` when no open jobs remain.
   - **Network failure, 5xx/408**: keep `pending`, increment `retry_count`, **break** the loop.
   - **401**: break (session handling via `ApiClient.onUnauthorized`).
   - **Other 4xx (e.g. 422)**: job `failed` + `last_error` (Laravel `errors` flattened), report `failed`, **continue** with other reports.
5. **Release Guard**: `isSyncing = false`.

`local_reports.sync_status`: `draft | pending | synced | failed | legacy`. `legacy` = unsynced reports from the pre-v4 app (DB v1), kept read-only so the user can re-enter them; they can't be sent to v4.

### 5.3 Photo Handling Guidelines

- Photos are compressed on capture (`flutter_image_compress`, quality ~70%, 1280px) and kept as local files; `local_reports.payload_json.foto_lokal` lists paths still waiting to upload.
- Upload happens only during sync, straight to MinIO via a presigned URL issued by the backend (`laporan/{id}/foto/sign-upload`). The bucket is private; `GET laporan/{id}` returns `foto[].url` as 10-minute signed download URLs. Never base64 photos into JSON.

---

## 6. API Specifications & Backend Conventions

Backend v4 (Laravel, `/Users/henrisaragi/Herd/sehatsatli-v4`) is the source of truth: `routes/api.php` + the Form Requests in `app/Http/Requests/Api/`. Check there before writing API code (see the `project-paths` skill).

### 6.1 Authentication, Headers & Responses

- **Base URL**: `https://sehatsatli.ksdae.kehutanan.go.id/api-v4/api/` (`ApiEndpoints.baseUrl`); endpoint paths carry no `api/` prefix.
- **Login**: 2 steps — `auth/login {email, password}` → `login_token`; `auth/otp/verify {login_token, otp}` → `access_token` (Passport). Profile: `GET user`. Logout: `POST auth/logout` (revokes the token).
- **Authorization**: `Authorization: Bearer <access_token>`, stored in `flutter_secure_storage`.
- **Responses**: real HTTP status codes and bare JSON — no `success` field. 2xx = success; 422 = `{message, errors: {field: [..]}}`; 429 = throttled (`auth/*`: 6/minute). Use `ApiClient.request()` → `ApiResponse` (`isSuccess`, `isTransient`, `message`).

### 6.2 Mobile Endpoints

| Function                  | Endpoint                                                                   | Notes                                                       |
| ------------------------- | -------------------------------------------------------------------------- | ----------------------------------------------------------- |
| Login / OTP / logout      | `auth/login`, `auth/otp/verify`, `auth/logout`                             | throttled                                                   |
| Lupa password             | `auth/password/otp/request` → `/verify` → `/reset`                         | carries `reset_token`                                       |
| Registrasi UPT            | `upt`, `upt/{id}/unit-organisasi`, `registrasi/upt`, `registrasi/status`   | NIP/jabatan/UPT come from `registrasi/status`               |
| Master species / diseases | `spesies`, `penyakit`                                                      | paginated (`per_page` ≤ 100), cached in `master_cache`      |
| Laporan list              | `laporan` (all), `laporan/saya` (mine)                                     | paginated                                                   |
| Laporan detail            | `laporan/{id}`                                                             | includes `barang_bukti`, `foto` (signed URLs)               |
| Create laporan            | `POST laporan`                                                             | `client_uuid` makes retries idempotent (returns 200 + same) |
| Stage updates             | `PUT laporan/{id}/investigasi`, `/verifikasi-dokter`, `/hasil-lab`         | each advances `tahap`                                       |
| Photos                    | `POST laporan/{id}/foto/sign-upload`, `POST laporan/{id}/foto`, `DELETE …` | MinIO presigned PUT                                         |
| Dashboard                 | `dashboard/ringkasan`                                                      | `{nasional, entitas: [{nama_entitas, total}]}`              |
| Notifikasi                | `notifikasi`, `notifikasi/{id}/baca`, `notifikasi/baca-semua`              | `unread_count` for the bell badge                           |
| Push (FCM) device         | `POST` / `DELETE notifikasi/perangkat {token, platform}`                   | registered on login (`PushService`), removed on logout      |

There is **no** delete endpoint for laporan: only reports that never reached the server can be removed (locally).

### 6.3 Laporan Wizard Payloads

`tahap`: `investigasi → verifikasi_dokter → hasil_lab → selesai`.

```json
// POST laporan
{ "client_uuid": "c7a8f9b2-…", "spesies_id": "<uuid>", "kelompok_umur": "dewasa" }
// or, for species outside the P.106 master:
{ "client_uuid": "…", "nama_jenis_lokal": "Burung kutilang", "kelompok_umur": "anakan" }

// PUT laporan/{id}/investigasi
{ "tanggal_kejadian": "2026-11-20", "jumlah_sakit": 2, "jumlah_mati": 1,
  "kondisi_jika_mati": "…", "kronologi": "…", "tindak_lanjut": "…",
  "kesimpulan_awal": "suspek_penyakit", "id_penyakit": "<uuid>|null",
  "latitude": -6.9147, "longitude": 107.6098 }

// PUT laporan/{id}/verifikasi-dokter
{ "verifikasi_suspek_penyakit": true, "aksi_dilakukan": "…", "informasi_tambahan": "…" }

// PUT laporan/{id}/hasil-lab
{ "penyakit_id": "<uuid>|null", "diagnosis_penyakit": "…", "aksi_lanjutan": "…",
  "investigasi_lanjutan": false, "periode_investigasi_mulai": "2026-11-21",
  "periode_investigasi_selesai": "2026-11-25",
  "barang_bukti": [{ "jenis_barang_bukti": "Sampel darah", "jumlah": "2 tabung", "keterangan": null }],
  "tindakan_lanjutan": "…", "keterangan_tambahan": "…" }
```

Option values (`kelompok_umur`, `kesimpulan_awal`) live in `lib/data/models/laporan_fields.dart`, mirroring the web app.

---

## 7. Role-Based Access Control (RBAC)

Backend v4 does not gate the `laporan` wizard: any logged-in user can fill every stage. `GET user` returns `roles` and `permissions` (Spatie); the old `is_doctor` / `heads_upt` / `training_mode` / `upt_id` flags no longer exist. A user whose UPT registration isn't `terverifikasi` is routed to the registration status page after login.

---

## 8. Form Lifecycle

1. **Laporan Baru** (`quick_report_widget.dart`): step 1 jenis satwa (P.106 species from cache, or a manual local name) + kelompok umur; step 2 investigasi + GPS + photos. "Lanjut" saves a local draft (`sync_status = 'draft'`); "Kirim Laporan" queues create + investigasi + photos and drains the queue.
2. **Detail** (`full_report_widget.dart`): completed stages read-only, plus the form for the current `tahap` (verifikasi dokter, then hasil lab). The next stage can be queued offline even while earlier ones are still pending.
3. **Rejected stage** (4xx on a stage `PUT`): the detail page swaps the next-stage form for "Perbaiki <tahap>", prefilled with the rejected request and showing the server's errors. "Simpan & Kirim Ulang" (`ReportRepository.resubmitRejectedStage`) replaces that `sync_queue` job's payload in place, so stage order is kept. A rejected create or photo has no form: "Kirim ulang", or delete it locally and create it again.

---

## 9. Common Commands & Workflows

### Code Generation & Build Commands

```bash
# Get dependencies
flutter pub get

# Run build runner (if using Drift/Freezed/JsonSerializable)
flutter pub run build_runner build --delete-conflicting-outputs

# Watch build runner for continuous changes
flutter pub run build_runner watch

# Analyze code quality
flutter analyze

# Run unit and repository tests
flutter test
```

### Build Targets

```bash
# Build Android APK (Release)
flutter build apk --release

# Build Android App Bundle (AAB)
flutter build appbundle --release

# Build iOS Release
flutter build ios --release
```

---

## 10. Development Conventions & Checklist

1. **Never Make Direct Network Calls in UI**: Always route network requests through repository classes and API helper functions.
2. **Use `ApiClient.request()` / `ApiResponse`**: backend v4 signals success with HTTP status codes; never look for a `success` field.
3. **Always Check Local DB First**: Dropdowns for forms must fetch options from `master_cache` in SQLite to ensure functionality in zero-signal areas.
4. **Secure Token Storage**: Always store Passport Bearer tokens in `flutter_secure_storage`. Do not persist auth tokens in plain `SharedPreferences`.
5. **Preserve Unsynced Drafts on Logout**: Logging out must clear session tokens, but **must not wipe** `local_reports` or `sync_queue` table data to avoid losing field data gathered offline.
