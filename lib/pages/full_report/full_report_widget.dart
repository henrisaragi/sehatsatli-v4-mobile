import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '/components/date_field/date_field_widget.dart';
import '/components/repeater_list/repeater_list_widget.dart';
import '/components/search_select/search_select_widget.dart';
import '/components/text_field/text_field_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '../../backend/sqlite/sqlite_manager.dart';
import '../../core/network/api_client.dart';
import '../../data/models/laporan_fields.dart';
import '../../data/models/report_list_item.dart';
import '../../data/repositories/master_repository.dart';
import '../../data/repositories/report_repository.dart';
import '../quick_report/quick_report_widget.dart';
import '../report_form/investigasi_form.dart';
import '../report_form/report_form_fields.dart';

/// Laporan detail + the form of its current wizard stage (web:
/// `LaporanInvestigasiWizardPage`). Opens by [clientId] (local row, works
/// offline) or [reportId] (server UUID, needs a connection the first time).
/// Completed stages are read-only; the next stage can be filled and queued
/// offline even while earlier stages are still waiting to be sent.
class FullReportWidget extends StatefulWidget {
  const FullReportWidget({super.key, this.clientId, this.reportId});

  final String? clientId;
  final String? reportId;

  static String routeName = 'FullReport';
  static String routePath = '/fullReport';

  @override
  State<FullReportWidget> createState() => _FullReportWidgetState();
}

class _FullReportWidgetState extends State<FullReportWidget> {
  final _repository = ReportRepository();

  bool _isLoading = true;
  String? _loadError;
  String? _clientId;
  String? _serverId;
  String _syncStatus = 'synced';
  String? _lastError;
  Map<String, dynamic> _laporan = {};
  List<Map<String, dynamic>> _penyakitOptions = [];

  bool _isSaving = false;
  bool _isRetrying = false;

  // Forms of the stages that can still be filled.
  final InvestigasiFormData _investigasi = InvestigasiFormData();
  final _VerifikasiFormData _verifikasi = _VerifikasiFormData();
  final _HasilLabFormData _hasilLab = _HasilLabFormData();

  /// Next form to fill; advances as soon as a stage is queued (even offline).
  String get _tahap => _laporan['tahap'] as String? ?? 'investigasi';

  /// Stage the server has confirmed — null until the laporan reaches it.
  String? get _serverTahap {
    if (_serverId == null) return null;
    return _laporan['tahap_server'] as String? ??
        (_syncStatus == 'synced' ? _tahap : null);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    _penyakitOptions = await MasterRepository().getCachedPenyakit();

    var clientId = widget.clientId;
    var local = clientId != null ? await SQLiteManager.instance.getLocalReport(clientId) : null;

    if (local?.syncStatus == 'draft') {
      if (!mounted) return;
      context.pushReplacementNamed(
        QuickReportWidget.routeName,
        queryParameters: {'clientId': serializeParam(clientId, ParamType.String)}.withoutNulls,
      );
      return;
    }

    // Refresh from the server when possible; the local copy covers offline.
    final serverId = local?.serverId ?? widget.reportId;
    final token = FFAppState().accessToken;
    if (serverId != null && token != null && local?.syncStatus != 'legacy') {
      try {
        final remote = await _repository.fetchOne(id: serverId, token: token);
        if (remote != null) {
          clientId = await _repository.ensureLocalRow(remote);
          local = await SQLiteManager.instance.getLocalReport(clientId);
        }
      } on ApiNetworkException {
        // Offline — fall through to whatever is stored locally.
      }
    }

    if (!mounted) return;
    if (local == null) {
      setState(() {
        _isLoading = false;
        _loadError = widget.reportId != null
            ? 'Tidak tersedia offline — sambungkan ke internet untuk membuka laporan ini.'
            : 'Laporan tidak ditemukan.';
      });
      return;
    }

    setState(() {
      _clientId = clientId;
      _serverId = local!.serverId;
      _syncStatus = local.syncStatus;
      _lastError = local.lastError;
      _laporan = jsonDecode(local.payloadJson ?? '{}') as Map<String, dynamic>;
      _isLoading = false;
    });
  }

  Future<void> _submitStage(String tahap, Map<String, dynamic> payload,
      {Map<String, dynamic> display = const {}, List<String> photos = const []}) async {
    setState(() => _isSaving = true);
    final result = await _repository.submitStage(
      clientId: _clientId!,
      tahap: tahap,
      payload: payload,
      display: display,
      photoPaths: photos,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);
    _showResult(result);
    await _load();
  }

  Future<void> _retry() async {
    setState(() => _isRetrying = true);
    final result = await _repository.retry(_clientId!);
    if (!mounted) return;
    setState(() => _isRetrying = false);
    _showResult(result);
    await _load();
  }

  void _showResult(ReportSubmitResult result) {
    showSnackbar(
      context,
      switch (result.status) {
        ReportSubmitStatus.sent => 'Terkirim ke server.',
        ReportSubmitStatus.queuedOffline => 'Tersimpan di perangkat — dikirim otomatis saat online.',
        ReportSubmitStatus.failed => 'Server menolak: ${result.message ?? '-'}',
      },
    );
  }

  Future<void> _deleteLocal() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus laporan dari perangkat?'),
        content: Text(
            'Laporan ini belum ada di server. Data yang dihapus tidak bisa dikembalikan.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('Batal')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text('Hapus')),
        ],
      ),
    );
    if (confirmed != true || _clientId == null) return;
    await _repository.deleteLocal(_clientId!);
    if (!mounted) return;
    showSnackbar(context, 'Laporan dihapus dari perangkat.');
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Scaffold(
      backgroundColor: theme.primaryBackground,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(theme),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _loadError != null
                    ? Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Text(_loadError!,
                              textAlign: TextAlign.center, style: theme.bodyMedium),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          padding: EdgeInsets.all(20.0),
                          children: _syncStatus == 'legacy'
                              ? [_legacyNotice(theme)]
                              : [
                                  _statusCard(theme),
                                  ..._completedSections(theme),
                                  if (_tahap != 'selesai') _currentStageCard(theme),
                                ].divide(SizedBox(height: 16.0)),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(FlutterFlowTheme theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        border: Border(bottom: BorderSide(color: theme.alternate)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(8.0, 16.0, 12.0, 16.0),
          child: Row(
            children: [
              FlutterFlowIconButton(
                borderRadius: 8.0,
                buttonSize: 40.0,
                icon: Icon(LucideIcons.arrowLeft, color: theme.primaryText),
                onPressed: () => context.pop(),
              ),
              Expanded(
                child: Text(
                  _isLoading || _loadError != null ? 'Laporan' : jenisLabel(_laporan),
                  overflow: TextOverflow.ellipsis,
                  style: theme.titleLarge.override(
                    font: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (!_isLoading && _clientId != null && _serverId == null)
                FlutterFlowIconButton(
                  borderRadius: 8.0,
                  buttonSize: 40.0,
                  icon: Icon(LucideIcons.trash2, color: theme.error),
                  onPressed: _deleteLocal,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _legacyNotice(FlutterFlowTheme theme) {
    return _card(
      theme,
      title: 'Laporan versi lama',
      children: [
        Text(
          'Laporan ini dibuat dengan aplikasi versi lama dan formatnya tidak didukung '
          'server baru, sehingga tidak bisa dikirim. Silakan buat ulang lewat "Laporan Baru", '
          'lalu hapus salinan ini.',
          style: theme.bodyMedium,
        ),
        SizedBox(height: 12.0),
        OutlinedButton.icon(
          onPressed: _deleteLocal,
          icon: Icon(LucideIcons.trash2, size: 16.0, color: theme.error),
          label: Text('Hapus dari perangkat'),
        ),
      ],
    );
  }

  Widget _statusCard(FlutterFlowTheme theme) {
    final serverTahap = _serverTahap;
    final stepIndex = serverTahap == null ? -1 : tahapOrder.indexOf(serverTahap);
    return _card(
      theme,
      title: serverTahap == null
          ? 'Belum diterima server'
          : 'Tahap: ${tahapLabels[serverTahap] ?? serverTahap}',
      children: [
        LinearProgressIndicator(
          value: (stepIndex + 1) / tahapOrder.length,
          color: theme.primary,
          backgroundColor: theme.alternate,
        ),
        SizedBox(height: 12.0),
        Row(
          children: [
            Icon(
              _syncStatus == 'synced'
                  ? LucideIcons.cloudCheck
                  : _syncStatus == 'failed'
                      ? LucideIcons.cloudAlert
                      : LucideIcons.cloudUpload,
              size: 18.0,
              color: _syncStatus == 'synced'
                  ? theme.success
                  : _syncStatus == 'failed'
                      ? theme.error
                      : theme.warning,
            ),
            SizedBox(width: 8.0),
            Expanded(
              child: Text(ReportListItem.syncStatusLabels[_syncStatus] ?? _syncStatus,
                  style: theme.bodyMedium),
            ),
            if (_syncStatus == 'failed' || _syncStatus == 'pending')
              TextButton(
                onPressed: _isRetrying ? null : _retry,
                child: Text(_syncStatus == 'failed' ? 'Kirim ulang' : 'Kirim sekarang'),
              ),
          ],
        ),
        if (_syncStatus == 'failed' && _lastError != null)
          Text(_lastError!, style: theme.bodySmall.override(color: theme.error)),
      ],
    );
  }

  List<Widget> _completedSections(FlutterFlowTheme theme) {
    final l = _laporan;
    final stepIndex = tahapOrder.indexOf(_tahap);
    final fotoRemote = [...?(l['foto'] as List?)].whereType<Map>().toList();
    final fotoLokal = [...?(l['foto_lokal'] as List?)].whereType<String>().toList();
    return [
      _card(theme, title: 'Jenis Satwa', children: [
        FormReadonlyRow(label: 'Jenis', value: jenisLabel(l)),
        FormReadonlyRow(
          label: 'Status Perlindungan',
          value: l['status_perlindungan'] == 'dilindungi' ? 'Dilindungi' : 'Tidak Dilindungi',
        ),
        FormReadonlyRow(
          label: 'Kelompok Umur',
          value: optionLabelFor(kelompokUmurOptions, l['kelompok_umur']),
        ),
      ]),
      if (stepIndex > 0)
        _card(theme, title: 'Investigasi', children: [
          FormReadonlyRow(label: 'Tanggal Kejadian', value: _date(l['tanggal_kejadian'])),
          FormReadonlyRow(label: 'Jumlah Sakit', value: l['jumlah_sakit']?.toString()),
          FormReadonlyRow(label: 'Jumlah Mati', value: l['jumlah_mati']?.toString()),
          if (l['kondisi_jika_mati'] != null)
            FormReadonlyRow(label: 'Kondisi Jika Mati', value: l['kondisi_jika_mati']?.toString()),
          FormReadonlyRow(label: 'Kronologi', value: l['kronologi']?.toString()),
          FormReadonlyRow(label: 'Tindak Lanjut', value: l['tindak_lanjut']?.toString()),
          FormReadonlyRow(
            label: 'Kesimpulan Awal',
            value: optionLabelFor(kesimpulanAwalOptions, l['kesimpulan_awal']),
          ),
          FormReadonlyRow(label: 'Dugaan Penyakit', value: l['dugaan_penyakit']?.toString()),
          FormReadonlyRow(label: 'Koordinat', value: '${l['latitude'] ?? '-'}, ${l['longitude'] ?? '-'}'),
        ]),
      if (stepIndex > 1)
        _card(theme, title: 'Verifikasi Dokter', children: [
          FormReadonlyRow(
            label: 'Verifikasi Suspek Penyakit',
            value: _isTrue(l['verifikasi_suspek_penyakit']) ? 'Ya' : 'Tidak',
          ),
          FormReadonlyRow(label: 'Aksi Dilakukan', value: l['aksi_dilakukan']?.toString()),
          FormReadonlyRow(label: 'Informasi Tambahan', value: l['informasi_tambahan']?.toString()),
        ]),
      if (stepIndex > 2)
        _card(theme, title: 'Hasil Lab', children: [
          FormReadonlyRow(label: 'Penyakit', value: _penyakitName(l)),
          FormReadonlyRow(label: 'Diagnosis Penyakit', value: l['diagnosis_penyakit']?.toString()),
          FormReadonlyRow(label: 'Aksi Lanjutan', value: l['aksi_lanjutan']?.toString()),
          FormReadonlyRow(
            label: 'Investigasi Lanjutan',
            value: _isTrue(l['investigasi_lanjutan']) ? 'Ya' : 'Tidak',
          ),
          FormReadonlyRow(
            label: 'Periode Investigasi',
            value: l['periode_investigasi_mulai'] == null
                ? null
                : '${_date(l['periode_investigasi_mulai'])} – ${_date(l['periode_investigasi_selesai'])}',
          ),
          for (final bukti in [...?(l['barang_bukti'] as List?)].whereType<Map>())
            FormReadonlyRow(
              label: 'Barang Bukti',
              value: '${bukti['jenis_barang_bukti']} (${bukti['jumlah']})'
                  '${bukti['keterangan'] != null ? ' — ${bukti['keterangan']}' : ''}',
            ),
          FormReadonlyRow(label: 'Tindakan Lanjutan', value: l['tindakan_lanjutan']?.toString()),
          FormReadonlyRow(label: 'Keterangan Tambahan', value: l['keterangan_tambahan']?.toString()),
        ]),
      if (fotoRemote.isNotEmpty || fotoLokal.isNotEmpty)
        _card(theme, title: 'Foto', children: [
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: [
              for (final foto in fotoRemote)
                if (foto['url'] is String) _thumb(Image.network(foto['url'], fit: BoxFit.cover)),
              for (final path in fotoLokal) _thumb(Image.file(File(path), fit: BoxFit.cover)),
            ],
          ),
          if (fotoLokal.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: Text('${fotoLokal.length} foto menunggu diunggah.',
                  style: theme.bodySmall.override(color: theme.secondaryText)),
            ),
        ]),
    ];
  }

  Widget _currentStageCard(FlutterFlowTheme theme) {
    switch (_tahap) {
      case 'investigasi':
        return _card(theme, title: 'Isi Investigasi', children: [
          InvestigasiFormFields(
            data: _investigasi,
            penyakitOptions: _penyakitOptions,
            onChanged: () => setState(() {}),
          ),
          SizedBox(height: 16.0),
          _submitButton(
            label: 'Simpan Investigasi',
            enabled: _investigasi.isValid,
            onPressed: () => _submitStage('investigasi', _investigasi.toPayload(),
                display: _investigasi.toDisplay(), photos: _investigasi.photoPaths),
          ),
        ]);
      case 'verifikasi_dokter':
        return _card(theme, title: 'Verifikasi Dokter', children: [
          FormSwitchRow(
            label: 'Verifikasi Suspek Penyakit',
            value: _verifikasi.suspekPenyakit,
            onChanged: (v) => setState(() => _verifikasi.suspekPenyakit = v),
          ),
          FormTextArea(
            label: 'Aksi Dilakukan',
            required: true,
            value: _verifikasi.aksiDilakukan,
            onChanged: (v) => setState(() => _verifikasi.aksiDilakukan = v),
          ),
          SizedBox(height: 16.0),
          FormTextArea(
            label: 'Informasi Tambahan',
            value: _verifikasi.informasiTambahan,
            onChanged: (v) => _verifikasi.informasiTambahan = v,
          ),
          SizedBox(height: 16.0),
          _submitButton(
            label: 'Simpan Verifikasi',
            enabled: _verifikasi.isValid,
            onPressed: () => _submitStage('verifikasi_dokter', _verifikasi.toPayload()),
          ),
        ]);
      default:
        return _card(theme, title: 'Hasil Lab', children: [
          SearchSelectWidget(
            label: 'Penyakit',
            hint: 'Cari penyakit...',
            options: _penyakitOptions,
            selectedId: _hasilLab.penyakitId,
            selectedLabel: _hasilLab.penyakitLabel,
            optionLabel: (o) => o['nama']?.toString() ?? '',
            optionId: (o) => o['id'],
            onSelected: (selected) => setState(() {
              _hasilLab.penyakitId = selected['id']?.toString();
              _hasilLab.penyakitLabel = selected['nama']?.toString();
            }),
          ),
          SizedBox(height: 16.0),
          FormSwitchRow(
            label: 'Investigasi Lanjutan',
            value: _hasilLab.investigasiLanjutan,
            onChanged: (v) => setState(() => _hasilLab.investigasiLanjutan = v),
          ),
          FormTextArea(
            label: 'Diagnosis Penyakit',
            value: _hasilLab.diagnosisPenyakit,
            onChanged: (v) => _hasilLab.diagnosisPenyakit = v,
          ),
          SizedBox(height: 16.0),
          FormTextArea(
            label: 'Aksi Lanjutan',
            value: _hasilLab.aksiLanjutan,
            onChanged: (v) => _hasilLab.aksiLanjutan = v,
          ),
          SizedBox(height: 16.0),
          FormLabel('Periode Investigasi'),
          SizedBox(height: 6.0),
          Row(
            children: [
              Expanded(
                child: DateFieldWidget(
                  label: 'Mulai',
                  date: _hasilLab.periodeMulai,
                  onChanged: (v) => setState(() => _hasilLab.periodeMulai = v),
                ),
              ),
              SizedBox(width: 12.0),
              Expanded(
                child: DateFieldWidget(
                  label: 'Selesai',
                  date: _hasilLab.periodeSelesai,
                  firstDate: _hasilLab.periodeMulai,
                  onChanged: (v) => setState(() => _hasilLab.periodeSelesai = v),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.0),
          FormLabel('Pengumpulan Barang Bukti'),
          SizedBox(height: 6.0),
          RepeaterListWidget<Map<String, String>>(
            items: _hasilLab.barangBukti,
            addLabel: 'Tambah Barang Bukti',
            onAdd: () => setState(() => _hasilLab.barangBukti
                .add({'jenis_barang_bukti': '', 'jumlah': '', 'keterangan': ''})),
            onRemove: (i) => setState(() => _hasilLab.barangBukti.removeAt(i)),
            rowBuilder: (context, i, item) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFieldWidget(
                  label: 'Jenis Barang Bukti *',
                  hint: 'mis. Sampel darah',
                  value: item['jenis_barang_bukti'] ?? '',
                  variant: 'outlined',
                  onChanged: (v) => setState(() => item['jenis_barang_bukti'] = v),
                ),
                TextFieldWidget(
                  label: 'Jumlah *',
                  hint: 'mis. 2 tabung',
                  value: item['jumlah'] ?? '',
                  variant: 'outlined',
                  onChanged: (v) => setState(() => item['jumlah'] = v),
                ),
                TextFieldWidget(
                  label: 'Keterangan',
                  hint: 'Keterangan',
                  value: item['keterangan'] ?? '',
                  variant: 'outlined',
                  onChanged: (v) => item['keterangan'] = v,
                ),
              ].divide(SizedBox(height: 8.0)),
            ),
          ),
          SizedBox(height: 16.0),
          FormTextArea(
            label: 'Tindakan Lanjutan',
            value: _hasilLab.tindakanLanjutan,
            onChanged: (v) => _hasilLab.tindakanLanjutan = v,
          ),
          SizedBox(height: 16.0),
          FormTextArea(
            label: 'Keterangan Tambahan',
            value: _hasilLab.keteranganTambahan,
            onChanged: (v) => _hasilLab.keteranganTambahan = v,
          ),
          SizedBox(height: 16.0),
          _submitButton(
            label: 'Simpan Hasil Lab',
            enabled: _hasilLab.isValid,
            onPressed: () => _submitStage('hasil_lab', _hasilLab.toPayload(),
                display: {
                  if (_hasilLab.penyakitLabel != null)
                    'penyakit': {'id': _hasilLab.penyakitId, 'nama': _hasilLab.penyakitLabel},
                }),
          ),
        ]);
    }
  }

  Widget _submitButton({
    required String label,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FormSubmitButton(
          label: label,
          isSaving: _isSaving,
          onPressed: enabled ? onPressed : null,
        ),
        if (!enabled) FormMissingHint(),
      ],
    );
  }

  Widget _card(FlutterFlowTheme theme, {required String title, required List<Widget> children}) {
    return Container(
      padding: EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: theme.alternate),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: theme.titleMedium.override(fontWeight: FontWeight.bold)),
          SizedBox(height: 8.0),
          ...children,
        ],
      ),
    );
  }

  Widget _thumb(Image image) => ClipRRect(
        borderRadius: BorderRadius.circular(8.0),
        child: SizedBox(width: 96.0, height: 96.0, child: image),
      );

  static bool _isTrue(dynamic v) => v == true || v == 1 || v == '1';

  static String? _date(dynamic raw) {
    final parsed = DateTime.tryParse(raw?.toString() ?? '');
    return parsed == null ? raw?.toString() : dateTimeFormat('d MMM yyyy', parsed.toLocal());
  }

  static String? _penyakitName(Map<String, dynamic> l) {
    final penyakit = l['penyakit'];
    return penyakit is Map ? penyakit['nama']?.toString() : null;
  }
}

/// Fields of the backend's `UpdateLaporanVerifikasiDokterRequest`.
class _VerifikasiFormData {
  bool suspekPenyakit = false;
  String aksiDilakukan = '';
  String informasiTambahan = '';

  bool get isValid => aksiDilakukan.trim().isNotEmpty;

  Map<String, dynamic> toPayload() => {
        'verifikasi_suspek_penyakit': suspekPenyakit,
        'aksi_dilakukan': aksiDilakukan.trim(),
        if (informasiTambahan.trim().isNotEmpty) 'informasi_tambahan': informasiTambahan.trim(),
      };
}

/// Fields of the backend's `UpdateLaporanHasilLabRequest`.
class _HasilLabFormData {
  String? penyakitId;
  String? penyakitLabel;
  String diagnosisPenyakit = '';
  String aksiLanjutan = '';
  bool investigasiLanjutan = false;
  DateTime? periodeMulai;
  DateTime? periodeSelesai;
  final List<Map<String, String>> barangBukti = [];
  String tindakanLanjutan = '';
  String keteranganTambahan = '';

  bool get isValid {
    if (periodeMulai != null && periodeSelesai != null && periodeSelesai!.isBefore(periodeMulai!)) {
      return false;
    }
    return barangBukti.every((b) =>
        (b['jenis_barang_bukti'] ?? '').trim().isNotEmpty && (b['jumlah'] ?? '').trim().isNotEmpty);
  }

  Map<String, dynamic> toPayload() => {
        'penyakit_id': penyakitId,
        'diagnosis_penyakit': _orNull(diagnosisPenyakit),
        'aksi_lanjutan': _orNull(aksiLanjutan),
        'investigasi_lanjutan': investigasiLanjutan,
        'periode_investigasi_mulai':
            periodeMulai == null ? null : dateTimeFormat('yyyy-MM-dd', periodeMulai!),
        'periode_investigasi_selesai':
            periodeSelesai == null ? null : dateTimeFormat('yyyy-MM-dd', periodeSelesai!),
        'barang_bukti': [
          for (final b in barangBukti)
            {
              'jenis_barang_bukti': b['jenis_barang_bukti']!.trim(),
              'jumlah': b['jumlah']!.trim(),
              'keterangan': _orNull(b['keterangan'] ?? ''),
            },
        ],
        'tindakan_lanjutan': _orNull(tindakanLanjutan),
        'keterangan_tambahan': _orNull(keteranganTambahan),
      };

  static String? _orNull(String v) => v.trim().isEmpty ? null : v.trim();
}
