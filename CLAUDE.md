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

## 2. Visual Guidelines

Theme tokens (FlutterFlow slots, Poppins/Inter type scale) live in `lib/flutter_flow/flutter_flow_theme.dart`. Status badge mapping: synced/verified = `accent1`/`success`, pending/priority = `accent2`/`warning`, local draft/info = `accent3`/`info`, failed/rejected = `accent4`/`error`.

- **Spacing Scale**: 4pt grid (`xs: 4`, `s: 8`, `m: 16`, `l: 24`, `xl: 32`)
- **Border Radius**: Card `12px`, Button `10px`, Input `8px`, Chip `999px (Pill)`
- **Elevation**: Use flat/subtle elevation (`elevation: 1`, shadow blur 8, opacity 6%) to match web admin interface.

---

## 3. Offline-First Architecture & Sync Engine

Schema: `lib/backend/sqlite/init.dart` (`local_reports`, `sync_queue`, `master_cache`). Photos have no table: pending paths live in `local_reports.payload_json.foto_lokal`, each with an `UPLOAD` `sync_queue` job.

### 3.1 Synchronization Engine Execution Flow (`runSyncQueue`, `lib/data/repositories/sync_repository.dart`)

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

### 3.2 Photo Handling Guidelines

- Photos are compressed on capture (`flutter_image_compress`, quality ~70%, 1280px) and kept as local files; `local_reports.payload_json.foto_lokal` lists paths still waiting to upload.
- Upload happens only during sync, straight to MinIO via a presigned URL issued by the backend (`laporan/{id}/foto/sign-upload`). The bucket is private; `GET laporan/{id}` returns `foto[].url` as 10-minute signed download URLs. Never base64 photos into JSON.

---

## 4. API Specifications & Backend Conventions

Backend v4 (Laravel, `/Users/henrisaragi/Herd/sehatsatli-v4`) is the source of truth: `routes/api.php` + the Form Requests in `app/Http/Requests/Api/`. Check there before writing API code (see the `project-paths` skill).

### 4.1 Authentication, Headers & Responses

- **Base URL**: `https://sehatsatli.ksdae.kehutanan.go.id/api-v4/api/` (`ApiEndpoints.baseUrl`); endpoint paths carry no `api/` prefix.
- **Login**: 2 steps — `auth/login {email, password}` → `login_token`; `auth/otp/verify {login_token, otp}` → `access_token` (Passport). Profile: `GET user`. Logout: `POST auth/logout` (revokes the token).
- **Authorization**: `Authorization: Bearer <access_token>`, stored in `flutter_secure_storage`.
- **Responses**: real HTTP status codes and bare JSON — no `success` field. 2xx = success; 422 = `{message, errors: {field: [..]}}`; 429 = throttled (`auth/*`: 6/minute). Use `ApiClient.request()` → `ApiResponse` (`isSuccess`, `isTransient`, `message`).

### 4.2 Mobile Endpoints

The endpoint table lives in the `project-paths` skill.

There is **no** delete endpoint for laporan: only reports that never reached the server can be removed (locally).

### 4.3 Laporan Wizard Payloads

`tahap`: `investigasi → verifikasi_dokter → hasil_lab → selesai`.

Option values (`kelompok_umur`, `kesimpulan_awal`) live in `lib/data/models/laporan_fields.dart`, mirroring the web app.

---

## 5. Role-Based Access Control (RBAC)

Backend v4 does not gate the `laporan` wizard: any logged-in user can fill every stage. `GET user` returns `roles` and `permissions` (Spatie); the old `is_doctor` / `heads_upt` / `training_mode` / `upt_id` flags no longer exist. A user whose UPT registration isn't `terverifikasi` is routed to the registration status page after login.

---

## 6. Form Lifecycle

1. **Laporan Baru** (`quick_report_widget.dart`): step 1 jenis satwa (P.106 species from cache, or a manual local name) + kelompok umur; step 2 investigasi + GPS + photos. "Lanjut" saves a local draft (`sync_status = 'draft'`); "Kirim Laporan" queues create + investigasi + photos and drains the queue.
2. **Detail** (`full_report_widget.dart`): completed stages read-only, plus the form for the current `tahap` (verifikasi dokter, then hasil lab). The next stage can be queued offline even while earlier ones are still pending.
3. **Rejected stage** (4xx on a stage `PUT`): the detail page swaps the next-stage form for "Perbaiki <tahap>", prefilled with the rejected request and showing the server's errors. "Simpan & Kirim Ulang" (`ReportRepository.resubmitRejectedStage`) replaces that `sync_queue` job's payload in place, so stage order is kept. A rejected create or photo has no form: "Kirim ulang", or delete it locally and create it again.

---


## 7. Development Conventions & Checklist

1. **Never Make Direct Network Calls in UI**: Always route network requests through repository classes and API helper functions.
2. **Use `ApiClient.request()` / `ApiResponse`**: backend v4 signals success with HTTP status codes; never look for a `success` field.
3. **Always Check Local DB First**: Dropdowns for forms must fetch options from `master_cache` in SQLite to ensure functionality in zero-signal areas.
4. **Secure Token Storage**: Always store Passport Bearer tokens in `flutter_secure_storage`. Do not persist auth tokens in plain `SharedPreferences`.
5. **Preserve Unsynced Drafts on Logout**: Logging out must clear session tokens, but **must not wipe** `local_reports` or `sync_queue` table data to avoid losing field data gathered offline.
