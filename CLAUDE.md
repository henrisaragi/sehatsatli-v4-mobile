# CLAUDE.md — SehatSatli Flutter Project Guide

> **SehatSatli (Sistem Informasi Kesehatan Satwa Liar)**  
> Mobile Application Architecture, Offline-First Guidelines, API Specifications & Design Tokens.

---

# Workspace Project Folder

### Backend project folder

```

```

---

## 1. Project Overview & Architecture Principles

SehatSatli is a mobile application used by field officers, wildlife veterinarians, and conservation agencies (KLHK, BKSDA, Taman Nasional, LU/LK) for wildlife health surveillance, reporting, and case investigation.

### Key Architectural Guidelines

1. **Offline-First Priority**: Field officers operate in remote conservation areas without network coverage. Form entry, offline photo handling, and geolocation tracking **must work 100% offline**. Data synchronization occurs automatically in the background when network reachability is restored.
2. **Idempotency via `client_id`**: Every report record generated on the device must assign a persistent UUID (`client_id`). Server backend controllers (`GeneralReportSourceMobileController`) use `client_id` for idempotent creation/updates (`firstOrCreate`), ensuring retry safety without duplicate records.
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
│   │   └── api_response_helper.dart  # Helper for custom HTTP 200 { success: false }
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
  server_id       INTEGER,                -- Populated after first successful sync
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
  endpoint        TEXT NOT NULL,          -- e.g. 'general-reports/saveGeneralReportMobile'
  method          TEXT NOT NULL DEFAULT 'POST',
  payload_json    TEXT NOT NULL,          -- Operation payload snapshot
  status          TEXT NOT NULL DEFAULT 'pending', -- pending | in_progress | done | failed
  retry_count     INTEGER DEFAULT 0,
  last_error      TEXT,
  created_at      TEXT NOT NULL
);

-- 3. Offline Photos Management
CREATE TABLE local_photos (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  client_id       TEXT NOT NULL,
  field_target    TEXT NOT NULL,          -- 'file' | 'verification.file_verification' | 'investigation.file_investigation'
  local_path      TEXT NOT NULL,          -- Device storage path
  remote_media_id INTEGER,                -- Remote Spatie media library ID
  is_deleted      INTEGER DEFAULT 0,      -- Set to 1 if user removes photo offline
  uploaded        INTEGER DEFAULT 0
);

-- 4. Read-Only Master Cache
CREATE TABLE master_cache (
  cache_key       TEXT PRIMARY KEY,       -- 'masters' | 'locations' | 'species' | 'diseases' | 'upts'
  data_json       TEXT NOT NULL,
  fetched_at      TEXT NOT NULL
);
```

### 5.2 Synchronization Engine Execution Flow (`runSyncQueue`)

1. **Guard Check**: Verify `isSyncing == false`. If already running, skip execution.
2. **Reachability Check**: Perform active ping check to backend `ping` endpoint (5s timeout). If unreachable, halt.
3. **FIFO Fetch**: Retrieve pending jobs from `sync_queue` sorted by `created_at ASC`.
4. **Iterative Sync**:
   - Mark current item `status = 'in_progress'`.
   - Read associated photos from `local_photos`. Compress & base64 encode active photos; attach remote deletion flags `{ id: remote_media_id, deleted: true }` for deleted photos.
   - Dispatch POST request to endpoint via `SehatSatliAPI`.
   - **On Success (`success == true`)**:
     - Update `local_reports`: update `server_id`, `report_code`, set `sync_status = 'synced'`.
     - Update `local_photos`: set `uploaded = 1`.
     - Mark `sync_queue.status = 'done'`.
   - **On Network Failure (Timeout/No Signal)**:
     - Keep `sync_queue.status = 'pending'`, increment `retry_count`.
     - **Break queue loop** immediately to prevent burning retries on subsequent items.
   - **On Server Validation Error (`success == false`)**:
     - Set `sync_queue.status = 'failed'` and record `last_error`.
     - Set `local_reports.sync_status = 'failed'`.
     - **Continue to next queue item** (validation failure is specific to the record, not network state).
5. **Release Guard**: Set `isSyncing = false`.

### 5.3 Photo Handling Guidelines

- **Lazy Base64 Encoding**: Do **NOT** base64 encode photos upon taking them with camera. Store local file paths in filesystem using `path_provider`. Encode to base64 **only right before sending** HTTP payload during sync execution.
- **Image Compression**: Apply `flutter_image_compress` (target quality ~70%, max dimensions 1280px) before saving locally.

---

## 6. API Specifications & Backend Conventions

### 6.1 Authentication & Header Rules

- **Base URL**: Set per environment (Staging / Production).
- **Authorization**: `Authorization: Bearer <access_token>` (Passport OAuth2).
- **Login Credentials**: User logins accept **email or phone number** as username. The backend matches MD5 hash of input (`username = md5(email)` or `username1 = md5(phone)`).
- **Response Format Caveat**: Backend returns **HTTP 200** for failed authentication with `{ "success": false, "message": { ... } }`. **Never** rely strictly on HTTP status codes for error handling. Always check the `success` boolean field in responses.

### 6.2 Primary Mobile Endpoints (`auth:api` group)

| Function           | Endpoint Path                               | Notes                                                  |
| ------------------ | ------------------------------------------- | ------------------------------------------------------ |
| Login              | `auth/login-app`                            | Public endpoint, returns Passport token & user profile |
| Master Dropdowns   | `masters`                                   | Returns options, categories, user flags                |
| Location Master    | `locations` / `location-user`               | Administrative regions cached locally                  |
| Master Species     | `species/getAll`                            | Wildlife catalog with priority/protected flags         |
| Master Diseases    | `diseases/getAll`                           | Disease catalog with priority/zoonosis flags           |
| Get Reports List   | `general-reports/getGeneralReportMobile`    | **Paginated (10/page)**, auto-scoped to UPT            |
| Get Report Detail  | `general-reports/getOne`                    | Retrieves full nested relations & media                |
| **Save Report**    | `general-reports/saveGeneralReportMobile`   | Main nested create/update endpoint using `client_id`   |
| **Delete Report**  | `general-reports/deleteGeneralReportMobile` | Soft deletes report by **`client_id`**                 |
| Register FCM Token | `users/user/token`                          | Submit device push notification token                  |
| User Heartbeat     | `user-activities/track`                     | Track monthly active status + FCM token                |

> ⚠️ **Endpoint Warning**: Use **only** `*Mobile` endpoints in `auth:api` group. Avoid legacy un-scoped endpoints (e.g. `generalReport/getAll`, `locationss`).

### 6.3 Report Payload Structure (`GeneralReportSource`)

Mobile API expects nested parameters:

```json
{
  "client_id": "c7a8f9b2-3d4e-5f6a-7b8c-9d0e1f2a3b4c",
  "report_date": "2026-03-30 10:00:00",
  "species_id": 14,
  "protected": true,
  "dead": 1,
  "live": 0,
  "description": "Found dead in conservation area",
  "reporter": {
    "name": "Budi Santoso",
    "gender": "Laki-laki",
    "occupation": "Petugas Lapangan",
    "phone": "08123456789",
    "address": "BKSDA Region II",
    "case_found": "Patroli Rutin"
  },
  "locations": {
    "upt_id": 5,
    "province_id": 31,
    "district_id": 3171,
    "subdistrict_id": 317101,
    "village_id": 3171011001,
    "latitude": "-6.2088",
    "longitude": "106.8456"
  },
  "diagnoses": {
    "report_date": "2026-03-30",
    "dead": 1,
    "dead_sign": "Bintik merah pada kulit",
    "temporary_diagnosis_id": 3
  },
  "investigation": null,
  "verification": null,
  "lab": null,
  "acknowledgement": null,
  "file": ["data:image/jpeg;base64,/9j/4AAQSkZJRg..."]
}
```

---

## 7. Role-Based Access Control (RBAC) Rules

User roles and screen/feature gates are governed by attributes on the `User` object:

| User Attribute     | Scope & Feature Permissions                                                                                                                            |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `upt_id`           | If `upt_id > 2`, reports and master data are automatically filtered to the user's specific UPT. If `upt_id <= 2` (Pusat), user has global read access. |
| `is_doctor`        | Controls access to the **Veterinary Verification Stage** form (`verification.*` & `saveVerify`).                                                       |
| `heads_upt`        | Grants access to the **Head of UPT Approval/Sign-off Stage** (`acknowledgement.*`). Receives priority FCM notifications.                               |
| `training_mode`    | When `true`, automatically tags created reports as training data (`training = true`). Shows permanent orange training banner in UI.                    |
| `all_notification` | Receives all new report alerts for the user's UPT via FCM.                                                                                             |

---

## 8. Form Lifecycle & Stepper Strategy

The primary report creation form uses a multi-step stepper linear flow:

1. **Step 1: Pelapor (Reporter)** → `reporter.*`
2. **Step 2: Lokasi (Location)** → `locations.*` (Automatic GPS fetch via `geolocator`, manual fallback)
3. **Step 3: Spesies (Species)** → `species.*` (Lookup from cached `Species` table)
4. **Step 4: Diagnosis Awal (Initial Diagnosis)** → `diagnoses.*` + photo capture

**Draft Storage Rule**: Every time the user taps "Next" or moves between steps, immediately call `upsertLocalDraft()` to save current progress to SQLite with `sync_status = 'draft'`. Tapping "Save & Submit" on the final step marks `sync_status = 'pending'`, queues the item in `sync_queue`, and triggers `runSyncQueue()`.

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
2. **Strict Use of `isApiSuccess(response)` Helper**: Standardize API checks across all call sites to evaluate body `success == true` rather than HTTP status code alone.
3. **Always Check Local DB First**: Dropdowns for forms must fetch options from `master_cache` in SQLite to ensure functionality in zero-signal areas.
4. **Secure Token Storage**: Always store Passport Bearer tokens in `flutter_secure_storage`. Do not persist auth tokens in plain `SharedPreferences`.
5. **Preserve Unsynced Drafts on Logout**: Logging out must clear session tokens, but **must not wipe** `local_reports` or `sync_queue` table data to avoid losing field data gathered offline.
