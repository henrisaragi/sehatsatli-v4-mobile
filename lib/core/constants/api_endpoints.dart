abstract class ApiEndpoints {
  static const String baseUrl = 'https://apisatli.biodiversity.id/';

  static const String loginApp = 'api/auth/login-app';
  static const String logout = 'api/auth/logout';
  // Named "forgot-password" server-side, but per API_ENDPOINTS.md §1 this is
  // actually "change password while logged in" (body: { password }), not a
  // classic OTP/email reset flow.
  static const String changePassword = 'api/auth/forgot-password';

  // Master data / lookups — API_ENDPOINTS.md §2. All Bearer-token, cached
  // locally (master_cache table) since payloads are large and mostly static.
  static const String masters = 'api/masters';
  // Lighter than /locations — scoped to the logged-in user's UPT province.
  static const String locationUser = 'api/location-user';
  static const String diseasesGetAll = 'api/diseases/getAll';
  static const String speciesGetAll = 'api/species/getAll';
  static const String uptsGetAll = 'api/upts/getAll';

  // Case report module — API_ENDPOINTS.md §3. Use the *Mobile variants only,
  // they support offline-first sync via client_id; never the legacy
  // unscoped duplicates.
  static const String saveGeneralReportMobile =
      'api/general-reports/saveGeneralReportMobile';
  static const String deleteGeneralReportMobile =
      'api/general-reports/deleteGeneralReportMobile';
  static const String getGeneralReportMobile =
      'api/general-reports/getGeneralReportMobile';
  static const String getOne = 'api/general-reports/getOne';
  // Per docs/general-report-field.md — a distinct, flat-payload "create new
  // report" endpoint (not the nested reporter/locations/species/diagnoses
  // shape `saveGeneralReportMobile` uses). Used by both the Quick Report
  // create form and Full Report Tab 1 (Investigasi) update — see
  // revisi.md. Tabs 2-4 use the three per-section endpoints below instead of
  // resubmitting the whole report.
  static const String generalReportsSave = 'api/general-reports/save';
  // Full Report Tab 2/3/4 — per-section save endpoints (revisi.md §2),
  // verified live against production. Each takes a flat payload (not
  // nested) plus a hidden `id` = the report's server id.
  static const String saveVerify = 'api/general-reports/saveVerify';
  static const String saveLab = 'api/general-reports/saveLab';
  static const String saveInvestigation = 'api/general-reports/saveInvestigation';

  // Public vet lookup for the verification stage's involved_doctors field.
  static const String dokterGetAll = 'api/dokter/getAll';

  // Community reports (Laporan Masyarakat) — API_ENDPOINTS.md §4. `save` and
  // `getAll` are public (no login needed — the "Lapor Cepat" entry point off
  // the login screen relies on this); `getOne` needs a Bearer token. Never
  // wire up the documented `delete` from mobile — it's a hard delete with no
  // soft-delete safety net and no task requires it.
  static const String communityReportsSave = 'api/community-reports/save';
  static const String communityReportsGetAll = 'api/community-reports/getAll';
  static const String communityReportsGetOne = 'api/community-reports/getOne';

  // User profile — API_ENDPOINTS.md §5.
  static const String usersGetOne = 'api/users/getOne';
  // Body: { id, file: "<base64>" } — not multipart. See §5, distinct from
  // the web-only `/users/uploadPhoto` multipart variant.
  static const String usersUploadPhotoMobile = 'api/users/uploadPhotoMobile';
  // Per docs/update-profile.md — a distinct, newer "save own profile"
  // endpoint. Not in API_ENDPOINTS.md §5, and not the same as the
  // documented-broken `/update-user` (which always no-ops, see that doc's
  // §5 warning) — don't conflate the two.
  static const String usersSave = 'api/users/save';

  // In-app notification inbox — API_ENDPOINTS.md §5.
  static const String userInboxGetAll = 'api/user-inbox/getAll';
  static const String userInboxSave = 'api/user-inbox/save';

  // Dashboard/statistics — API_ENDPOINTS.md §7. Unlike every other group
  // above, none of these have a documented response sample anywhere, and
  // design-system.md calls the whole group "likely web-only, optional for
  // mobile" — only the one this app actually surfaces (this-month report
  // count on Beranda) is wired up; the rest (map, suspek/non-suspek/lab
  // breakdowns) are deferred until a live response can be captured.
  static const String dashboardGetTotalLaporan = 'api/dashboard/get-totalLaporan';

  // Health check — API_ENDPOINTS.md §8. Used by the sync worker to check
  // real reachability before attempting to drain the outbox.
  static const String ping = 'api/ping';
}
