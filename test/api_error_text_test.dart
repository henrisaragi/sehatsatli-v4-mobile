import 'package:flutter_test/flutter_test.dart';

import 'package:sehat_satli/core/network/api_client.dart';
import 'package:sehat_satli/core/network/api_error_text.dart';

void main() {
  test('Laravel 422 errors become labelled Indonesian lines', () {
    final response = ApiResponse(422, {
      'message': 'The given data was invalid.',
      'errors': {
        'kronologi': ['The kronologi field is required.'],
        'barang_bukti.0.jumlah': ['The barang_bukti.0.jumlah field is required.'],
        'tanggal_kejadian': ['The tanggal kejadian field must be a date before or equal to today.'],
      },
    });
    expect(
      response.message,
      'Kronologi: wajib diisi\n'
      'Barang bukti #1 – Jumlah: wajib diisi\n'
      'Tanggal kejadian: tidak boleh setelah hari ini',
    );
  });

  test('5xx hides Laravel\'s "Server Error"', () {
    expect(ApiResponse(500, {'message': 'Server Error'}).message, serverErrorText(500));
  });

  test('generic 403/404 are reworded, specific messages kept', () {
    expect(ApiResponse(403, {'message': 'This action is unauthorized.'}).message,
        'Anda tidak memiliki akses untuk tindakan ini.');
    expect(ApiResponse(404, {'message': 'Email tidak terdaftar.'}).message,
        'Email tidak terdaftar.');
  });

  test('date rules name the other field, not its key', () {
    expect(
      translateValidation('The periode investigasi selesai field must be a date after or equal to periode_investigasi_mulai.'),
      'tidak boleh sebelum periode investigasi mulai',
    );
  });

  test('unknown validation text is shown as sent', () {
    expect(translateValidation('Tahap laporan tidak sesuai.'), 'Tahap laporan tidak sesuai.');
  });
}
