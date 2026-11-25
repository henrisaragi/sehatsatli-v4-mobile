/// User-facing (Indonesian) wording for request failures, shared by every
/// screen so the same problem always reads the same way and says what the
/// user can do about it.
library;

const String networkErrorText =
    'Tidak dapat terhubung ke server. Periksa koneksi internet perangkat '
    '(data seluler/Wi-Fi), lalu coba lagi.';

const String rateLimitText =
    'Terlalu banyak percobaan. Tunggu sekitar 1 menit, lalu coba lagi.';

String serverErrorText(int statusCode) =>
    'Server sedang bermasalah (HTTP $statusCode). Coba lagi beberapa saat lagi.';

/// Labels for the request fields the app sends (Form Requests in backend v4).
const Map<String, String> _fieldLabels = {
  'client_uuid': 'ID laporan',
  'spesies_id': 'Jenis satwa',
  'nama_jenis_lokal': 'Nama jenis lokal',
  'kelompok_umur': 'Kelompok umur',
  'tanggal_kejadian': 'Tanggal kejadian',
  'jumlah_sakit': 'Jumlah sakit',
  'jumlah_mati': 'Jumlah mati',
  'kondisi_jika_mati': 'Kondisi jika mati',
  'kronologi': 'Kronologi',
  'tindak_lanjut': 'Tindak lanjut',
  'kesimpulan_awal': 'Kesimpulan awal',
  'id_penyakit': 'Dugaan penyakit',
  'latitude': 'Latitude',
  'longitude': 'Longitude',
  'verifikasi_suspek_penyakit': 'Verifikasi suspek penyakit',
  'aksi_dilakukan': 'Aksi dilakukan',
  'informasi_tambahan': 'Informasi tambahan',
  'penyakit_id': 'Penyakit',
  'diagnosis_penyakit': 'Diagnosis penyakit',
  'aksi_lanjutan': 'Aksi lanjutan',
  'investigasi_lanjutan': 'Investigasi lanjutan',
  'periode_investigasi_mulai': 'Periode investigasi mulai',
  'periode_investigasi_selesai': 'Periode investigasi selesai',
  'barang_bukti': 'Barang bukti',
  'jenis_barang_bukti': 'Jenis barang bukti',
  'jumlah': 'Jumlah',
  'keterangan': 'Keterangan',
  'tindakan_lanjutan': 'Tindakan lanjutan',
  'keterangan_tambahan': 'Keterangan tambahan',
  'object_key': 'Foto',
  'content_type': 'Format foto',
  'email': 'Email',
  'password': 'Password',
  'otp': 'Kode OTP',
};

/// `barang_bukti.0.jumlah` → `Barang bukti #1 – Jumlah`.
String fieldLabel(String key) {
  final parts = key.split('.');
  final labels = <String>[];
  for (var i = 0; i < parts.length; i++) {
    final index = int.tryParse(parts[i]);
    if (index != null && labels.isNotEmpty) {
      labels[labels.length - 1] = '${labels.last} #${index + 1}';
    } else {
      labels.add(_fieldLabels[parts[i]] ?? parts[i].replaceAll('_', ' '));
    }
  }
  return labels.join(' – ');
}

/// Backend v4 runs with `APP_LOCALE=en`, so validation messages arrive as
/// Laravel's English defaults ("The kronologi field is required."). The
/// common rules are reworded; anything else is shown as sent.
String translateValidation(String message) {
  final rules = <RegExp, String Function(Match)>{
    RegExp(r'field is required'): (_) => 'wajib diisi',
    RegExp(r'is required'): (_) => 'wajib diisi',
    RegExp(r'selected .* is invalid'): (_) => 'pilihan tidak valid',
    RegExp(r'must be a valid date|is not a valid date'): (_) =>
        'harus berupa tanggal yang valid',
    RegExp(r'must be a date before or equal to (.+?)\.?$'): (m) =>
        'tidak boleh setelah ${m[1]}',
    RegExp(r'must be a date after or equal to (.+?)\.?$'): (m) =>
        'tidak boleh sebelum ${m[1]}',
    RegExp(r'must be an integer'): (_) => 'harus berupa angka bulat',
    RegExp(r'must be a number|must be numeric'): (_) => 'harus berupa angka',
    RegExp(r'must be at least (\S+?)\.?( characters)?\.?$'): (m) =>
        'minimal ${m[1]}${m[2] != null ? ' karakter' : ''}',
    RegExp(r'must not be greater than (\S+?)\.?( characters)?\.?$'): (m) =>
        'maksimal ${m[1]}${m[2] != null ? ' karakter' : ''}',
    RegExp(r'must be between (\S+) and (\S+?)\.?$'): (m) =>
        'harus di antara ${m[1]} dan ${m[2]}',
    RegExp(r'must be a valid email'): (_) => 'harus berupa email yang valid',
    RegExp(r'has already been taken'): (_) => 'sudah digunakan',
    RegExp(r'must be true or false'): (_) => 'harus ya atau tidak',
    RegExp(r'must be an array'): (_) => 'format tidak valid',
  };
  for (final rule in rules.entries) {
    final match = rule.key.firstMatch(message);
    if (match != null) return _dateWords(rule.value(match));
  }
  return message;
}

/// Laravel's relative date words, as used in before/after rules.
String _dateWords(String text) => text
    .replaceAll(RegExp(r'\btoday\b'), 'hari ini')
    .replaceAll(RegExp(r'\btomorrow\b'), 'besok')
    .replaceAll(RegExp(r'\byesterday\b'), 'kemarin')
    .replaceAllMapped(RegExp(r'\b([a-z]+)_([a-z_]+)\b'),
        (m) => (fieldLabel(m[0]!)).toLowerCase());
