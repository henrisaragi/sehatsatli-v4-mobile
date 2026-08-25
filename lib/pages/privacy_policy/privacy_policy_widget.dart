import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';

class PrivacyPolicyWidget extends StatelessWidget {
  const PrivacyPolicyWidget({super.key});

  static String routeName = 'PrivacyPolicy';
  static String routePath = '/privacyPolicy';

  static const String _effectiveDate = '13 Agustus 2026';
  static const String _orgName =
      'Direktorat Jenderal Konservasi Sumber Daya Alam dan Ekosistem (Ditjen KSDAE), Kementerian Kehutanan Republik Indonesia';
  static const String _contactEmail = 'dit.ksg@kehutanan.go.id';
  static const String _address =
      'Gedung Manggala Wanabakti Blok I Lt. 8, Jl. Jenderal Gatot Subroto, Jakarta 10270, PO BOX 6505';

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    return Scaffold(
      backgroundColor: theme.primaryBackground,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              color: theme.secondaryBackground,
              border: Border(bottom: BorderSide(color: theme.alternate)),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsetsDirectional.fromSTEB(8.0, 22.0, 20.0, 20.0),
                child: Row(
                  children: [
                    FlutterFlowIconButton(
                      borderRadius: 8.0,
                      buttonSize: 40.0,
                      icon: Icon(LucideIcons.arrowLeft, color: theme.primaryText),
                      onPressed: () => context.safePop(),
                    ),
                    SizedBox(width: 4.0),
                    Text(
                      'Kebijakan Privasi',
                      style: theme.titleLarge.override(
                        font: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                        color: theme.primaryText,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(20.0),
              children: [
                Text(
                  'SehatSatli — Sistem Informasi Kesehatan Satwa Liar',
                  style: theme.bodyMedium.override(
                    color: theme.secondaryText,
                  ),
                ),
                SizedBox(height: 4.0),
                Text(
                  'Terakhir diperbarui: $_effectiveDate',
                  style: theme.bodySmall.override(
                    color: theme.secondaryText,
                  ),
                ),
                SizedBox(height: 20.0),
                _intro(theme),
                SizedBox(height: 24.0),
                _section(
                  theme,
                  '1. Pengendali Data',
                  'Aplikasi SehatSatli dikembangkan dan dioperasikan oleh $_orgName '
                      '("Ditjen KSDAE", "kami"). Ditjen KSDAE bertindak sebagai pengendali data '
                      'atas informasi yang dikumpulkan melalui aplikasi ini, sesuai dengan tugas dan '
                      'fungsi pengawasan kesehatan dan konservasi satwa liar di Indonesia.',
                ),
                _section(
                  theme,
                  '2. Data yang Kami Kumpulkan',
                  'Karena SehatSatli dirancang untuk digunakan petugas lapangan, dokter hewan, dan '
                      'kepala UPT (BKSDA/Taman Nasional/LU-LK) di lokasi konservasi yang sering tanpa '
                      'sinyal internet, sebagian data disimpan sementara di perangkat sebelum '
                      'dikirim ke server. Kategori data yang kami kumpulkan:',
                ),
                _bulletList(theme, [
                  _Bullet('Data akun',
                      'Email atau nomor telepon, kata sandi (tersimpan dalam bentuk terenkripsi), nama pengguna, jabatan/peran, dan Unit Pelaksana Teknis (UPT) tempat Anda bertugas.'),
                  _Bullet('Data pelapor',
                      'Saat membuat laporan, kami mengumpulkan nama, jenis kelamin, pekerjaan, nomor telepon, dan alamat pelapor (bisa berupa data Anda sendiri atau data masyarakat yang Anda laporkan atas nama mereka).'),
                  _Bullet('Data lokasi',
                      'Koordinat GPS (lintang/bujur) serta wilayah administratif (provinsi, kabupaten/kota, kecamatan, desa) tempat kejadian satwa dilaporkan — diambil otomatis lewat GPS perangkat atau dipilih manual jika GPS tidak tersedia.'),
                  _Bullet('Foto/media',
                      'Foto satwa, kondisi lapangan, atau dokumen pendukung yang Anda ambil lewat kamera atau pilih dari galeri sebagai lampiran laporan.'),
                  _Bullet('Data kesehatan satwa liar',
                      'Spesies, status dilindungi, jumlah individu (hidup/mati), gejala, diagnosis sementara, hasil investigasi lanjutan, verifikasi dokter hewan, hasil laboratorium, dan catatan pengesahan kepala UPT — data ini tentang satwa, bukan data pribadi Anda.'),
                  _Bullet('Data teknis aplikasi',
                      'Token akses (OAuth Passport, tersimpan terenkripsi di perangkat), status sinkronisasi laporan, dan riwayat aktivitas login untuk keperluan keamanan dan audit.'),
                ]),
                _section(
                  theme,
                  '3. Bagaimana Kami Menggunakan Data',
                  'Data yang dikumpulkan digunakan untuk:',
                ),
                _bulletList(theme, [
                  _Bullet('Surveilans kesehatan satwa liar',
                      'Mencatat, memverifikasi, dan menindaklanjuti kasus kesehatan satwa liar di seluruh wilayah kerja Ditjen KSDAE.'),
                  _Bullet('Autentikasi & kontrol akses',
                      'Memastikan hanya petugas berwenang yang dapat membuat, melihat, atau menyetujui laporan sesuai peran (UPT, dokter hewan, kepala UPT).'),
                  _Bullet('Koordinasi lintas unit',
                      'Membagikan status laporan antar UPT dan Pusat (KLHK) untuk penanganan kasus, termasuk notifikasi ke pihak berwenang terkait.'),
                  _Bullet('Statistik & pelaporan',
                      'Menyusun ringkasan dan statistik kasus kesehatan satwa liar secara agregat untuk kebutuhan kebijakan dan konservasi.'),
                ]),
                _section(
                  theme,
                  '4. Penyimpanan Offline & Sinkronisasi',
                  'Karena aplikasi ini dirancang "offline-first" untuk area konservasi tanpa sinyal, '
                      'laporan yang Anda buat — termasuk data pelapor, lokasi, dan foto — disimpan '
                      'lebih dulu di penyimpanan lokal perangkat (database SQLite). Foto disimpan '
                      'sebagai berkas lokal dan baru diunggah (dienkode) ke server saat aplikasi '
                      'berhasil terhubung ke internet. Data ini tetap berada di perangkat Anda sampai '
                      'proses sinkronisasi ke server kami berhasil.',
                ),
                _section(
                  theme,
                  '5. Berbagi Data dengan Pihak Lain',
                  'Kami tidak menjual atau menyewakan data pribadi Anda kepada pihak ketiga. Data '
                      'laporan dan data akun hanya diakses oleh:',
                ),
                _bulletList(theme, [
                  _Bullet('Instansi internal',
                      'Petugas UPT terkait, dokter hewan, kepala UPT, dan pusat data Ditjen KSDAE — sesuai kewenangan akses (RBAC) masing-masing peran, dan dibatasi pada UPT tempat laporan dibuat kecuali untuk pengguna Pusat.'),
                  _Bullet('Penyedia infrastruktur',
                      'Server dan basis data resmi milik/dikelola untuk Ditjen KSDAE, yang menyimpan data untuk keperluan operasional sistem ini.'),
                  _Bullet('Kewajiban hukum',
                      'Bila diwajibkan oleh peraturan perundang-undangan yang berlaku di Indonesia.'),
                ]),
                _section(
                  theme,
                  '6. Keamanan Data',
                  'Token akses login disimpan dalam penyimpanan terenkripsi perangkat (secure '
                      'storage), bukan di penyimpanan biasa. Komunikasi antara aplikasi dan server '
                      'menggunakan koneksi terenkripsi (HTTPS). Akses ke data laporan dibatasi sesuai '
                      'peran pengguna (lihat bagian RBAC pada dokumentasi teknis aplikasi).',
                ),
                _section(
                  theme,
                  '7. Penyimpanan & Retensi Data',
                  'Laporan yang tersimpan di server kami disimpan selama diperlukan untuk keperluan '
                      'surveilans, arsip, dan kebijakan konservasi satwa liar, sesuai ketentuan '
                      'kearsipan instansi pemerintah yang berlaku. Draf laporan yang belum '
                      'tersinkron di perangkat Anda tetap tersimpan secara lokal walaupun Anda keluar '
                      '(logout) dari akun, agar data lapangan yang sudah dikumpulkan tidak hilang.',
                ),
                _section(
                  theme,
                  '8. Hak Anda',
                  'Sebagai pengguna terdaftar, Anda dapat meminta koreksi data profil melalui menu '
                      'Profil dalam aplikasi, atau menghubungi kami menggunakan kontak pada bagian 11 '
                      'untuk permintaan akses, koreksi, atau penghapusan data pribadi Anda, sepanjang '
                      'tidak bertentangan dengan kewajiban pengarsipan data instansi pemerintah.',
                ),
                _section(
                  theme,
                  '9. Laporan Cepat Tanpa Akun',
                  'Aplikasi ini menyediakan fitur "Laporan Cepat" yang dapat digunakan masyarakat '
                      'umum tanpa login. Data yang Anda isi pada fitur ini (nama, kontak, lokasi, '
                      'foto, dan uraian kejadian) dikirim langsung ke Ditjen KSDAE untuk ditindaklanjuti '
                      'dan diperlakukan dengan standar perlindungan data yang sama seperti laporan dari '
                      'petugas terdaftar.',
                ),
                _section(
                  theme,
                  '10. Privasi Anak',
                  'Aplikasi ini ditujukan untuk petugas lapangan, dokter hewan, dan pegawai instansi '
                      'konservasi yang sudah dewasa, bukan untuk anak-anak. Kami tidak dengan sengaja '
                      'mengumpulkan data pribadi anak di bawah umur.',
                ),
                _section(
                  theme,
                  '11. Perubahan Kebijakan Ini',
                  'Kami dapat memperbarui Kebijakan Privasi ini dari waktu ke waktu mengikuti '
                      'perubahan fitur aplikasi atau ketentuan perundang-undangan. Tanggal pembaruan '
                      'terakhir akan selalu tertera di bagian atas halaman ini.',
                ),
                SizedBox(height: 8.0),
                _contactCard(theme),
                SizedBox(height: 24.0),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _intro(FlutterFlowTheme theme) {
    return Text(
      'Kebijakan Privasi ini menjelaskan bagaimana aplikasi SehatSatli mengumpulkan, '
      'menggunakan, menyimpan, dan melindungi data yang Anda masukkan saat menggunakan '
      'aplikasi ini untuk pelaporan dan investigasi kesehatan satwa liar. Dengan menggunakan '
      'aplikasi ini, Anda menyetujui praktik yang dijelaskan di bawah.',
      style: theme.bodyLarge,
    );
  }

  Widget _section(FlutterFlowTheme theme, String title, String body) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.titleMedium.override(
              font: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              color: theme.primaryText,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6.0),
          Text(
            body,
            style: theme.bodyMedium.override(
              color: theme.secondaryText,
              lineHeight: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bulletList(FlutterFlowTheme theme, List<_Bullet> items) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items
            .map((b) => Padding(
                  padding: EdgeInsets.only(bottom: 10.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(top: 7.0, right: 10.0),
                        child: Container(
                          width: 5.0,
                          height: 5.0,
                          decoration: BoxDecoration(
                            color: theme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: '${b.label}. ',
                                style: theme.bodyMedium.override(
                                  color: theme.primaryText,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              TextSpan(
                                text: b.description,
                                style: theme.bodyMedium.override(
                                  color: theme.secondaryText,
                                  lineHeight: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _contactCard(FlutterFlowTheme theme) {
    return Container(
      padding: EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: theme.accent1,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: theme.alternate),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '12. Hubungi Kami',
            style: theme.titleMedium.override(
              font: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              color: theme.primaryText,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8.0),
          Text(
            'Untuk pertanyaan, keluhan, atau permintaan terkait data pribadi Anda, silakan '
            'hubungi:',
            style: theme.bodyMedium.override(color: theme.secondaryText),
          ),
          SizedBox(height: 12.0),
          _contactRow(theme, LucideIcons.house, _orgName),
          SizedBox(height: 8.0),
          _contactRow(theme, LucideIcons.mail, _contactEmail),
          SizedBox(height: 8.0),
          _contactRow(theme, LucideIcons.mapPin, _address),
        ],
      ),
    );
  }

  Widget _contactRow(FlutterFlowTheme theme, IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18.0, color: theme.primary),
        SizedBox(width: 10.0),
        Expanded(
          child: Text(
            text,
            style: theme.bodyMedium.override(color: theme.primaryText),
          ),
        ),
      ],
    );
  }
}

class _Bullet {
  final String label;
  final String description;
  const _Bullet(this.label, this.description);
}
