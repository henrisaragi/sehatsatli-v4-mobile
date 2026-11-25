/// Backend v4 (`sehatsatli-v4`, Laravel). Source of truth for every path and
/// payload is the backend's `routes/api.php` + Form Requests — see the
/// `project-paths` skill.
abstract class ApiEndpoints {
  // Server root (no `api/` segment) — Laravel's `/up` health route lives here.
  static const String hostUrl = 'https://sehatsatli.ksdae.kehutanan.go.id/api-v4/';

  // Production API root. Every endpoint path below is relative to this, so
  // none of them carry an `api/` prefix.
  static const String baseUrl = '${hostUrl}api/';

  // Health check used by the sync engine before draining the queue.
  static const String healthUrl = '${hostUrl}up';

  // Auth — 2-step OTP login (docs-new-versions/login.md).
  static const String authLogin = 'auth/login';
  static const String authOtpVerify = 'auth/otp/verify';
  static const String authLogout = 'auth/logout';
  static const String userMe = 'user';

  // Guest "lupa password" flow (docs-new-versions/forgot-password.md).
  static const String passwordOtpRequest = 'auth/password/otp/request';
  static const String passwordOtpVerify = 'auth/password/otp/verify';
  static const String passwordOtpReset = 'auth/password/otp/reset';

  // Self-service UPT staff registration (docs-new-versions/register-upt.md).
  static const String registrasiStatus = 'registrasi/status';
  static const String uptGetAll = 'upt';
  static const String registrasiUpt = 'registrasi/upt';
  static String uptUnitOrganisasi(String uptId) => 'upt/$uptId/unit-organisasi';

  // Masters — paginated (`per_page` max 100), cached in `master_cache`.
  static const String spesies = 'spesies';
  static const String penyakit = 'penyakit';

  // Laporan wizard. `{laporan}` is a placeholder the sync engine replaces
  // with the server UUID once the report's create has synced, so stage
  // updates can be queued offline before that UUID exists.
  static const String laporanPlaceholder = '{laporan}';
  static const String laporan = 'laporan';
  static const String laporanSaya = 'laporan/saya';
  static const String laporanEntitas = 'laporan/entitas';
  static String laporanDetail(String id) => 'laporan/$id';
  static const String laporanInvestigasi = 'laporan/{laporan}/investigasi';
  static const String laporanVerifikasiDokter = 'laporan/{laporan}/verifikasi-dokter';
  static const String laporanHasilLab = 'laporan/{laporan}/hasil-lab';
  static const String laporanFoto = 'laporan/{laporan}/foto';

  static const String dashboardRingkasan = 'dashboard/ringkasan';

  // In-app notifications + FCM device registration.
  static const String notifikasi = 'notifikasi';
  static const String notifikasiBacaSemua = 'notifikasi/baca-semua';
  static const String notifikasiPerangkat = 'notifikasi/perangkat';
  static String notifikasiBaca(String id) => 'notifikasi/$id/baca';
}
