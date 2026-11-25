abstract class ApiEndpoints {
  // Server root (no `api/` segment) — also the base for relative media paths
  // such as user photos, which are served outside the `api/` prefix.
  static const String hostUrl = 'https://sehatsatli.ksdae.kehutanan.go.id/api-v4/';

  // Production API root. Every endpoint path below is relative to this, so
  // none of them carry an `api/` prefix.
  static const String baseUrl = '${hostUrl}api/';

  // Backend v4 — 2-step OTP login (docs-new-versions/login.md). Replaces the
  // old 1-step md5-hash `login-app` endpoint, which no longer exists on this
  // host.
  static const String authLogin = 'auth/login';
  static const String authOtpVerify = 'auth/otp/verify';
  static const String userMe = 'user';

  // Backend v4 — self-service UPT staff registration
  // (docs-new-versions/register-upt.md).
  static const String registrasiStatus = 'registrasi/status';
  static const String uptGetAll = 'upt';
  static const String registrasiUpt = 'registrasi/upt';
  static String uptUnitOrganisasi(String uptId) =>
      'upt/$uptId/unit-organisasi';

  static const String logout = 'auth/logout';
  // Named "forgot-password" server-side, but per API_ENDPOINTS.md §1 this is
  // actually "change password while logged in" (body: { password }), not a
  // classic OTP/email reset flow.
  static const String changePassword = 'auth/forgot-password';
  // Guest "lupa password" flow — docs/reset-password.md. Unauthenticated,
  // email-based OTP reset, distinct from `changePassword` above (which
  // requires an existing session).
  static const String passwordOtpRequest = 'auth/password/otp/request';
  static const String passwordOtpVerify = 'auth/password/otp/verify';
  static const String passwordOtpReset = 'auth/password/otp/reset';

  // Master data / lookups — API_ENDPOINTS.md §2. All Bearer-token, cached
  // locally (master_cache table) since payloads are large and mostly static.
  static const String masters = 'masters';
  // Lighter than /locations — scoped to the logged-in user's UPT province.
  static const String locationUser = 'location-user';
  static const String diseasesGetAll = 'diseases/getAll';
  static const String speciesGetAll = 'species/getAll';
  static const String uptsGetAll = 'upts/getAll';

  // Case report module — API_ENDPOINTS.md §3. Use the *Mobile variants only,
  // they support offline-first sync via client_id; never the legacy
  // unscoped duplicates.
  static const String saveGeneralReportMobile =
      'general-reports/saveGeneralReportMobile';
  // CORRECTED 2026-08-12 — the documented `deleteGeneralReportMobile` (body
  // `{client_id}`) was never actually wired into anything on the backend;
  // confirmed against the live web app (`sehatsatli-v2-extranet`,
  // `generalReportSlice.js`'s `deleteGeneralReport`) that the real endpoint
  // is the plain `general-reports/delete` taking `{id: <numeric server id>}`
  // — same "*Mobile-suffixed docs are wrong, plain web-style endpoint is
  // right" pattern already found for `generalReportsSave` above.
  static const String generalReportsDelete = 'general-reports/delete';
  static const String getGeneralReportMobile =
      'general-reports/getGeneralReportMobile';
  // Confirmed live 2026-08-08 against production: returns a much broader/
  // more complete report list than `getGeneralReportMobile` did (surfaced
  // years of historical records `getGeneralReportMobile` never returned).
  // `fetchReports()` uses this now. NOTE: this did NOT fix the original
  // "my new report doesn't show up" symptom — that turned out to be a
  // separate, more serious problem upstream at create time, not a list-
  // endpoint choice. See the doc comment on `generalReportsSave` below.
  static const String generalReportsGetAll = 'general-reports/getAll';
  static const String getOne = 'general-reports/getOne';
  // Per docs/general-report-field.md — a distinct, flat-payload "create new
  // report" endpoint (not the nested reporter/locations/species/diagnoses
  // shape `saveGeneralReportMobile` uses). Used by both the Quick Report
  // create form and Full Report Tab 1 (Investigasi) update — see
  // revisi.md.
  //
  // ⚠️ ROOT CAUSE FOUND AND FIXED (2026-08-12): the 2026-08-08 "confirmed
  // live bug" note below (kept for history) misdiagnosed this as a backend
  // problem. It was actually the client sending an explicit `id: 0` on
  // *create* (no report on the server yet) — isolated by replaying the
  // live web app's (`sehatsatli-v2-extranet`) exact minimal working payload
  // via the browser console, then re-adding Flutter's extra fields one at a
  // time: `general-reports/save` responds `success: true, data: null`
  // whenever the request body includes an `id` key at all when there's no
  // real report yet, and creates correctly the moment that key is omitted
  // — every other extra field Flutter sends (`creator`/`updater`/`training`/
  // `status`/`user_id`/`report_code`/`reporter_id`/`protected_species`) was
  // confirmed harmless in isolation. Both `quick_report_widget.dart` and
  // `full_report_widget.dart`'s Tab 1 submit now omit `id` entirely unless
  // a real `_serverId` already exists. Tabs 2-4 use the three per-section
  // endpoints below instead of resubmitting the whole report.
  //
  // Original (2026-08-08) note, kept for context: a successful create
  // (`success: true`) responded with `"data": null` — no `id`, no
  // `report_code` — and the created report never appeared in
  // `generalReportsGetAll` either, by id or by search, which at the time
  // looked like the backend silently not persisting anything.
  static const String generalReportsSave = 'general-reports/save';
  // Full Report Tab 2/3/4 — per-section save endpoints (revisi.md §2),
  // verified live against production. Each takes a flat payload (not
  // nested) plus a hidden `id` = the report's server id.
  static const String saveVerify = 'general-reports/saveVerify';
  static const String saveLab = 'general-reports/saveLab';
  static const String saveInvestigation = 'general-reports/saveInvestigation';

  // Public vet lookup for the verification stage's involved_doctors field.
  static const String dokterGetAll = 'dokter/getAll';

  // Community reports (Laporan Masyarakat) — API_ENDPOINTS.md §4. `save` and
  // `getAll` are public (no login needed — the "Lapor Cepat" entry point off
  // the login screen relies on this); `getOne` needs a Bearer token. Never
  // wire up the documented `delete` from mobile — it's a hard delete with no
  // soft-delete safety net and no task requires it.
  static const String communityReportsSave = 'community-reports/save';
  static const String communityReportsGetAll = 'community-reports/getAll';
  static const String communityReportsGetOne = 'community-reports/getOne';

  // User profile — API_ENDPOINTS.md §5.
  static const String usersGetOne = 'users/getOne';
  // Body: { id, file: "<base64>" } — not multipart. See §5, distinct from
  // the web-only `/users/uploadPhoto` multipart variant.
  static const String usersUploadPhotoMobile = 'users/uploadPhotoMobile';
  // Per docs/update-profile.md — a distinct, newer "save own profile"
  // endpoint. Not in API_ENDPOINTS.md §5, and not the same as the
  // documented-broken `/update-user` (which always no-ops, see that doc's
  // §5 warning) — don't conflate the two.
  static const String usersSave = 'users/save';

  // In-app notification inbox — API_ENDPOINTS.md §5.
  static const String userInboxGetAll = 'user-inbox/getAll';
  static const String userInboxSave = 'user-inbox/save';

  // Dashboard/statistics — API_ENDPOINTS.md §7. Unlike every other group
  // above, none of these have a documented response sample anywhere, and
  // design-system.md calls the whole group "likely web-only, optional for
  // mobile" — only the one this app actually surfaces (this-month report
  // count on Beranda) is wired up; the rest (map, suspek/non-suspek/lab
  // breakdowns) are deferred until a live response can be captured.
  static const String dashboardGetTotalLaporan = 'dashboard/get-totalLaporan';

  // Health check — API_ENDPOINTS.md §8. Used by the sync worker to check
  // real reachability before attempting to drain the outbox.
  static const String ping = 'ping';
}
