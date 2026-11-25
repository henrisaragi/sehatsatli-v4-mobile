# Changelog

All notable changes to the SehatSatli mobile app are documented in this file.
Versioning follows `pubspec.yaml`'s `versionName+versionCode` (Android `versionCode` must
strictly increase between Play Store uploads). Full Indonesian release notes for Play Console,
signing details, and known issues per release live in `docs/upload-playstore.md`'s Release Notes
section — this file is a shorter technical summary per version.

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
