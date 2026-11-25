/// Option lists and labels for the v4 laporan wizard — mirrors the web app's
/// `src/features/laporan-investigasi/utils/laporanFields.js` and the backend
/// Form Request `Rule::in(...)` values.
library;

/// Wizard stages in order. `selesai` means every stage is filled.
const List<String> tahapOrder = [
  'investigasi',
  'verifikasi_dokter',
  'hasil_lab',
  'selesai',
];

const Map<String, String> tahapLabels = {
  'investigasi': 'Investigasi',
  'verifikasi_dokter': 'Verifikasi Dokter',
  'hasil_lab': 'Hasil Lab',
  'selesai': 'Selesai',
};

/// List titles for reports still waiting at a stage (dashboard shortcuts).
const Map<String, String> tahapPendingLabels = {
  'investigasi': 'Belum Diinvestigasi',
  'verifikasi_dokter': 'Belum Diverifikasi Dokter',
};

/// The stage that follows [tahap] once its form is submitted.
String nextTahap(String tahap) {
  final index = tahapOrder.indexOf(tahap);
  if (index < 0 || index >= tahapOrder.length - 1) return 'selesai';
  return tahapOrder[index + 1];
}

const List<Map<String, String>> kelompokUmurOptions = [
  {'id': 'tidak_diketahui', 'label': 'Tidak Diketahui'},
  {'id': 'anakan', 'label': 'Anakan'},
  {'id': 'remaja', 'label': 'Remaja'},
  {'id': 'dewasa', 'label': 'Dewasa'},
];

const List<Map<String, String>> kesimpulanAwalOptions = [
  {'id': 'non_penyakit', 'label': 'Non Penyakit'},
  {'id': 'suspek_penyakit', 'label': 'Suspek Penyakit'},
];

String? optionLabelFor(List<Map<String, String>> options, dynamic id) {
  for (final option in options) {
    if (option['id'] == id?.toString()) return option['label'];
  }
  return null;
}

/// Display name of a laporan: master species (local, then scientific name)
/// or the manually typed local species name.
String jenisLabel(Map<String, dynamic> laporan) {
  final spesies = laporan['spesies'];
  if (spesies is Map) {
    final local = spesies['local_name']?.toString();
    if (local != null && local.isNotEmpty) return local;
    final scientific = spesies['scientific_name']?.toString();
    if (scientific != null && scientific.isNotEmpty) return scientific;
  }
  final manual = laporan['nama_jenis_lokal']?.toString();
  if (manual != null && manual.isNotEmpty) return manual;
  return 'Spesies tidak diketahui';
}
