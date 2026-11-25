# Changelog

All notable changes to the SehatSatli mobile app are documented in this file.
Versioning follows `pubspec.yaml`'s `versionName+versionCode` (Android `versionCode` must
strictly increase between Play Store uploads). Full Indonesian release notes for Play Console,
signing details, and known issues per release live in `docs/upload-playstore.md`'s Release Notes
section — this file is a shorter technical summary per version.

## [4.2.0] - build 5 - unreleased

Full migration to backend v4 (`sehatsatli-v4`). Requires that backend's
`feature/mobile-v4-support` changes to be deployed first.

### Changed
- **Base URL** `https://sehatsatli.ksdae.kehutanan.go.id/api-v4/api/`. Every endpoint now follows
  backend v4's `routes/api.php`. v4 uses real HTTP status codes and bare JSON bodies;
  `ApiClient.request()` returns an `ApiResponse` (`isSuccess`, `isTransient`, `message`), and the
  `isApiSuccess` helper is gone.
- **2-step OTP login**, token-revoking logout (`POST auth/logout`), and a forgot-password flow on
  `reset_token` (it always failed against v4 before). The minimum password length is now 8, matching
  the backend.
- **Laporan wizard rewritten to the v4/web flow.** "Laporan Baru" covers species + age group and
  then investigation + GPS + photos. The detail page shows completed stages read-only, with the
  form for the next stage (doctor verification, then lab results with evidence).
- **Sync engine rewritten.** It queues `POST laporan` (with `client_uuid`) and the
  `PUT laporan/{laporan}/<stage>` jobs in order, filling in the server UUID once the create
  succeeds. 5xx and network errors are retried later. Other 4xx responses mark the report failed
  and block its later stages until "Kirim ulang".
- **Photos** upload straight to MinIO through backend-issued presigned URLs instead of base64.
- Master cache is now `spesies` + `penyakit` (all pages). The dashboard uses `dashboard/ringkasan`.

### Added
- Self-service UPT staff registration and registration status page.
- "Sinkron" tab (the Sync Manager) in place of Notifikasi.

### Removed
- Features with no v4 endpoint: community reports, notification inbox, profile edit/photo upload,
  in-session password change, and deleting reports that already reached the server.
  They can be restored from tag `v1.1.1`.

### Migration
- SQLite schema v1 → v2. Unsynced old-format reports are kept as read-only `legacy` rows, never
  deleted. Old queue jobs are marked failed. Old synced snapshots and the old master cache are
  cleared.

### Notes
- `flutter analyze`: 0 errors. `flutter test`: 18/18 passing.
- The mobile request contract was verified end to end against the local v4 backend and the real
  MinIO bucket. The UI was not exercised on an emulator against production.

## [1.1.1] - build 4 - 2026-08-25

### Fixed
- **Status bar / notch overlap on Dashboard, Laporan, Notifikasi, and Profil headers.** These
  screens' top headers were not wrapped in `SafeArea`, so on devices with a display cutout the
  header text collided with the system status bar. Wrapped each header in `SafeArea(bottom:
  false, ...)`.
- **Edge-to-edge display enforcement restored on Android 15+ (`targetSdkVersion 36`).** Removed
  `android:windowOptOutEdgeToEdgeEnforcement="true"` from all four `styles.xml` variants
  (`values`, `values-night`, `values-v31`, `values-night-v31`) — this flag was silently opting the
  app out of Android's edge-to-edge enforcement instead of fixing the underlying layout, which is
  the same root cause as the status-bar overlap above.
- **`general-reports/save` returning `success: true, data: null` no longer gets marked as
  synced.** Previously a report could receive a "success" response with no confirmed server `id`
  and still be marked `synced` locally, which hid it from the drafts fallback view while it was
  never actually queryable server-side — the report would silently disappear. Both
  `ReportRepository.submit()` and `SyncRepository.runSyncQueue()` now treat this response shape as
  a failure instead, so the report stays visible in the app and retryable. Covered by 2 new tests
  in `test/sync_repository_test.dart`.

### Notes
- `flutter analyze`: 0 errors (pre-existing lint infos only). `flutter test`: 20/20 passing.
- No API contract or payload shape changes — this is a UI/reliability patch release, no new
  features.
- Signed with the existing `android/upload-keystore.jks` upload key (SHA1
  `CB:2A:8A:B9:31:15:86:3E:DC:DC:11:54:CF:E2:5E:06:4B:36:19:60`), verified against
  `build/app/outputs/bundle/release/app-release.aab` before this entry was written.

## [1.1.0] - build 3 - 2026-08-20

### Added
- "Lupa Password" (forgot password) flow: a public 3-step wizard (email → OTP → new password +
  confirm) reachable from the login screen without an existing session. See
  `docs/reset-password.md` for the endpoint spec.

### Notes
- Live-verified end-to-end on a real Android emulator against a production account.
- Known issue carried over: the Laporan tab could still show "Server Error" on some filters when
  the server fetch fails, instead of falling back fully to local drafts (not yet fixed as of this
  release).

## [1.0.0] - build 2 - first Closed Testing release

Initial Closed Testing release. Offline-first wildlife case reporting (draft locally, sync when
online), master species/disease search with autofill, automatic GPS location capture, local
storage/sync status management, and report verification/investigation/acknowledgement stages for
`is_doctor`/`heads_upt` accounts.
