import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '/components/date_field/date_field_widget.dart';
import '/components/multi_image_picker/multi_image_picker_widget.dart';
import '/components/search_select/search_select_widget.dart';
import '/components/simple_dropdown/simple_dropdown_widget.dart';
import '/components/text_field/text_field_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '../../data/models/laporan_fields.dart';
import 'report_form_fields.dart';

/// State of the "Investigasi" stage form — fields and rules of the backend's
/// `UpdateLaporanInvestigasiRequest`.
class InvestigasiFormData {
  DateTime? tanggalKejadian = DateTime.now();
  String jumlahSakit = '';
  String jumlahMati = '';
  String kondisiJikaMati = '';
  String kronologi = '';
  String tindakLanjut = '';
  String? kesimpulanAwal;
  String? idPenyakit;
  String? penyakitLabel;
  double? latitude;
  double? longitude;
  List<String> photoPaths = [];

  /// What still blocks submitting, worded for the user.
  List<String> get missingFields => [
        if (tanggalKejadian == null) 'Tanggal kejadian',
        if ((int.tryParse(jumlahSakit) ?? -1) < 0) 'Jumlah sakit (angka 0 atau lebih)',
        if (jumlahMati.isNotEmpty && (int.tryParse(jumlahMati) ?? -1) < 0)
          'Jumlah mati (angka 0 atau lebih)',
        if (kronologi.trim().isEmpty) 'Kronologi',
        if (tindakLanjut.trim().isEmpty) 'Tindak lanjut',
        if (kesimpulanAwal == null) 'Kesimpulan awal',
        if (latitude == null || longitude == null) 'Lokasi GPS (latitude & longitude)',
      ];

  bool get isValid => missingFields.isEmpty;

  Map<String, dynamic> toPayload() => {
        'tanggal_kejadian': dateTimeFormat('yyyy-MM-dd', tanggalKejadian!),
        'jumlah_sakit': int.parse(jumlahSakit),
        if (jumlahMati.isNotEmpty) 'jumlah_mati': int.parse(jumlahMati),
        if ((int.tryParse(jumlahMati) ?? 0) > 0 && kondisiJikaMati.trim().isNotEmpty)
          'kondisi_jika_mati': kondisiJikaMati.trim(),
        'kronologi': kronologi.trim(),
        'tindak_lanjut': tindakLanjut.trim(),
        'kesimpulan_awal': kesimpulanAwal,
        if (idPenyakit != null) 'id_penyakit': idPenyakit,
        'latitude': latitude,
        'longitude': longitude,
      };

  /// Local-only extras kept next to the payload so the detail page can show
  /// names without a network call.
  Map<String, dynamic> toDisplay() => {
        if (penyakitLabel != null) 'dugaan_penyakit': penyakitLabel,
      };

  Map<String, dynamic> toDraft() => {
        ...toDisplay(),
        'tanggal_kejadian': tanggalKejadian?.toIso8601String(),
        'jumlah_sakit': jumlahSakit,
        'jumlah_mati': jumlahMati,
        'kondisi_jika_mati': kondisiJikaMati,
        'kronologi': kronologi,
        'tindak_lanjut': tindakLanjut,
        'kesimpulan_awal': kesimpulanAwal,
        'id_penyakit': idPenyakit,
        'latitude': latitude,
        'longitude': longitude,
        'photo_paths': photoPaths,
      };

  void loadDraft(Map<String, dynamic> draft) {
    tanggalKejadian = DateTime.tryParse(draft['tanggal_kejadian']?.toString() ?? '') ??
        tanggalKejadian;
    jumlahSakit = draft['jumlah_sakit']?.toString() ?? '';
    jumlahMati = draft['jumlah_mati']?.toString() ?? '';
    kondisiJikaMati = draft['kondisi_jika_mati']?.toString() ?? '';
    kronologi = draft['kronologi']?.toString() ?? '';
    tindakLanjut = draft['tindak_lanjut']?.toString() ?? '';
    kesimpulanAwal = draft['kesimpulan_awal'] as String?;
    idPenyakit = draft['id_penyakit'] as String?;
    penyakitLabel = draft['dugaan_penyakit'] as String?;
    latitude = (draft['latitude'] as num?)?.toDouble();
    longitude = (draft['longitude'] as num?)?.toDouble();
    photoPaths = [...?(draft['photo_paths'] as List?)?.whereType<String>()];
  }
}

/// Investigasi stage fields. Fetches GPS automatically when no coordinates
/// are set yet; latitude/longitude stay editable as a manual fallback.
class InvestigasiFormFields extends StatefulWidget {
  const InvestigasiFormFields({
    super.key,
    required this.data,
    required this.penyakitOptions,
    required this.onChanged,
  });

  final InvestigasiFormData data;
  final List<Map<String, dynamic>> penyakitOptions;
  final VoidCallback onChanged;

  @override
  State<InvestigasiFormFields> createState() => _InvestigasiFormFieldsState();
}

class _InvestigasiFormFieldsState extends State<InvestigasiFormFields> {
  bool _fetchingGps = false;

  // Bumped after a GPS fix so the coordinate fields rebuild with new values.
  int _coordinateRevision = 0;

  InvestigasiFormData get _data => widget.data;

  @override
  void initState() {
    super.initState();
    if (_data.latitude == null || _data.longitude == null) _fetchGps();
  }

  void _update(VoidCallback change) {
    setState(change);
    widget.onChanged();
  }

  Future<void> _fetchGps() async {
    setState(() => _fetchingGps = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission denied');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      _update(() {
        _data.latitude = position.latitude;
        _data.longitude = position.longitude;
        _coordinateRevision++;
      });
    } catch (_) {
      if (mounted) {
        showSnackbar(context, 'Tidak bisa mengambil lokasi GPS — isi koordinat manual.');
      }
    } finally {
      if (mounted) setState(() => _fetchingGps = false);
    }
  }

  String _penyakitLabel(Map<String, dynamic> option) => option['nama']?.toString() ?? '';

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final hasDead = (int.tryParse(_data.jumlahMati) ?? 0) > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DateFieldWidget(
          label: 'Tanggal Kejadian *',
          date: _data.tanggalKejadian,
          lastDate: DateTime.now(),
          onChanged: (v) => _update(() => _data.tanggalKejadian = v),
        ),
        Row(
          children: [
            Expanded(
              child: TextFieldWidget(
                label: 'Jumlah Sakit *',
                hint: '0',
                value: _data.jumlahSakit,
                keyboardType: TextInputType.number,
                variant: 'outlined',
                onChanged: (v) => _update(() => _data.jumlahSakit = v.trim()),
              ),
            ),
            SizedBox(width: 12.0),
            Expanded(
              child: TextFieldWidget(
                label: 'Jumlah Mati',
                hint: '0',
                value: _data.jumlahMati,
                keyboardType: TextInputType.number,
                variant: 'outlined',
                onChanged: (v) => _update(() => _data.jumlahMati = v.trim()),
              ),
            ),
          ],
        ),
        if (hasDead)
          FormTextArea(
            label: 'Kondisi Jika Mati',
            value: _data.kondisiJikaMati,
            onChanged: (v) => _update(() => _data.kondisiJikaMati = v),
          ),
        FormTextArea(
          label: 'Kronologi',
          required: true,
          value: _data.kronologi,
          onChanged: (v) => _update(() => _data.kronologi = v),
        ),
        FormTextArea(
          label: 'Tindak Lanjut',
          required: true,
          value: _data.tindakLanjut,
          onChanged: (v) => _update(() => _data.tindakLanjut = v),
        ),
        SimpleDropdownWidget(
          label: 'Kesimpulan Awal *',
          value: _data.kesimpulanAwal,
          options: kesimpulanAwalOptions,
          optionLabel: (o) => o['label'].toString(),
          optionId: (o) => o['id'],
          onChanged: (v) => _update(() => _data.kesimpulanAwal = v as String?),
        ),
        SearchSelectWidget(
          label: 'Dugaan Penyakit',
          hint: widget.penyakitOptions.isEmpty
              ? 'Daftar penyakit belum tersedia offline'
              : 'Cari penyakit...',
          options: widget.penyakitOptions,
          selectedId: _data.idPenyakit,
          selectedLabel: _data.penyakitLabel,
          optionLabel: _penyakitLabel,
          optionId: (o) => o['id'],
          onSelected: (selected) => _update(() {
            _data.idPenyakit = selected['id']?.toString();
            _data.penyakitLabel = _penyakitLabel(selected);
          }),
        ),
        Row(
          children: [
            Expanded(child: FormLabel('Lokasi Kejadian', required: true)),
            TextButton.icon(
              onPressed: _fetchingGps ? null : _fetchGps,
              icon: _fetchingGps
                  ? SizedBox(
                      width: 14.0,
                      height: 14.0,
                      child: CircularProgressIndicator(strokeWidth: 2.0),
                    )
                  : Icon(LucideIcons.locateFixed, size: 16.0, color: theme.primary),
              label: Text('Ambil GPS'),
            ),
          ],
        ),
        Row(
          key: ValueKey(_coordinateRevision),
          children: [
            Expanded(
              child: TextFieldWidget(
                label: 'Latitude *',
                hint: '-6.914744',
                value: _data.latitude?.toString() ?? '',
                keyboardType: TextInputType.numberWithOptions(signed: true, decimal: true),
                variant: 'outlined',
                onChanged: (v) => _update(() => _data.latitude = _inRange(v, 90)),
              ),
            ),
            SizedBox(width: 12.0),
            Expanded(
              child: TextFieldWidget(
                label: 'Longitude *',
                hint: '107.60981',
                value: _data.longitude?.toString() ?? '',
                keyboardType: TextInputType.numberWithOptions(signed: true, decimal: true),
                variant: 'outlined',
                onChanged: (v) => _update(() => _data.longitude = _inRange(v, 180)),
              ),
            ),
          ],
        ),
        MultiImagePickerWidget(
          label: 'Foto',
          existingMediaUrls: const [],
          newLocalPaths: _data.photoPaths,
          onLocalPathsChanged: (v) => _update(() => _data.photoPaths = v),
        ),
      ].divide(SizedBox(height: 16.0)),
    );
  }

  static double? _inRange(String raw, double limit) {
    final value = double.tryParse(raw.trim().replaceAll(',', '.'));
    if (value == null || value.abs() > limit) return null;
    return value;
  }
}
