import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

typedef Json = Map<String, dynamic>;

class KesalahanApi implements Exception {
  const KesalahanApi(this.pesan);
  final String pesan;
  @override
  String toString() => pesan;
}

class RakRapiApi {
  RakRapiApi({
    this.alamat = const String.fromEnvironment(
      'API_URL',
      defaultValue: 'http://127.0.0.1:3000/api',
    ),
  });

  final String alamat;
  String? token;
  void Function()? saatSesiHabis;

  Future<http.Response> _kirim(
    http.BaseRequest request, {
    bool privat = true,
  }) async {
    final tokenPermintaan = token;
    if (privat && tokenPermintaan != null) {
      request.headers['Authorization'] = 'Bearer $tokenPermintaan';
    }
    final http.Response respons;
    try {
      respons = await request
          .send()
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 40));
    } on TimeoutException {
      throw const KesalahanApi(
        'API belum merespons. Periksa daftar sebelum mengulangi penyimpanan.',
      );
    } on http.ClientException {
      throw const KesalahanApi(
        'API tidak dapat dihubungi. Periksa koneksi ke backend.',
      );
    }
    if (respons.statusCode >= 200 && respons.statusCode < 300) return respons;

    if (privat && respons.statusCode == 401 && tokenPermintaan == token) {
      saatSesiHabis?.call();
    }
    var pesan = 'Permintaan gagal (HTTP ${respons.statusCode}).';
    try {
      final body = jsonDecode(utf8.decode(respons.bodyBytes));
      if (body is Json && body['pesan'] is String) pesan = body['pesan'];
    } on FormatException {
      // Bila respons bukan JSON, tampilkan status HTTP.
    }
    throw KesalahanApi(pesan);
  }

  Future<Json> _json(
    String metode,
    String jalur, {
    Json? isi,
    bool privat = true,
  }) async {
    final request = http.Request(metode, Uri.parse('$alamat$jalur'));
    if (isi != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(isi);
    }
    final respons = await _kirim(request, privat: privat);
    if (respons.bodyBytes.isEmpty) return {};
    return jsonDecode(utf8.decode(respons.bodyBytes)) as Json;
  }

  Future<void> cekKoneksi() async {
    final data = await _json('GET', '/health', privat: false);
    if (data['status'] != 'ok' || data['nama_database'] != 'rakrapi') {
      throw const KesalahanApi('Database RakRapi belum siap.');
    }
  }

  Future<Json> masuk(String email, String sandi) async {
    await cekKoneksi();
    return _json(
      'POST',
      '/auth/login',
      privat: false,
      isi: {'email': email, 'password': sandi},
    );
  }

  Future<Json> profil() async =>
      (await _json('GET', '/auth/me'))['user'] as Json;

  Future<void> daftarWarga(String nama, String email, String sandi) async {
    await _json(
      'POST',
      '/auth/register',
      privat: false,
      isi: {'nama': nama, 'email': email, 'password': sandi},
    );
  }

  Future<void> tambahPegawai(String nama, String email, String sandi) async {
    await _json(
      'POST',
      '/auth/pegawai',
      isi: {'nama': nama, 'email': email, 'password': sandi},
    );
  }

  Future<List<Json>> daftarBarang() async =>
      ((await _json('GET', '/barang'))['data'] as List).cast<Json>();
  Future<Json> detail(int id) async =>
      (await _json('GET', '/barang/$id'))['data'] as Json;
  Future<Uint8List> foto(int id) async {
    final request = http.Request('GET', Uri.parse('$alamat/barang/$id/foto'));
    return (await _kirim(request)).bodyBytes;
  }

  Future<List<Json>> kategori() async =>
      ((await _json('GET', '/kategori'))['data'] as List).cast<Json>();
  Future<Json> tambahKategori(String nama) async =>
      (await _json('POST', '/kategori', isi: {'nama': nama}))['data'] as Json;

  Future<Json> detailKategori(int id) async =>
      (await _json('GET', '/kategori/$id'))['data'] as Json;

  Future<Json> ubahKategori(int id, String nama) async =>
      (await _json('PATCH', '/kategori/$id', isi: {'nama': nama}))['data']
          as Json;

  Future<void> hapusKategori(int id) async {
    await _json('DELETE', '/kategori/$id');
  }

  Future<void> hapus(int id) async {
    await _json('DELETE', '/barang/$id');
  }

  Future<List<Json>> lowongan() async =>
      ((await _json('GET', '/lowongan'))['data'] as List).cast<Json>();

  Future<void> bukaLowongan(String judul) async {
    await _json('POST', '/lowongan', isi: {'judul': judul});
  }

  Future<void> tutupLowongan(int id) async {
    await _json('PATCH', '/lowongan/$id/tutup');
  }

  Future<int> simpanBarang(
    Map<String, String> isian, {
    int? id,
    Uint8List? gambar,
  }) async {
    final jalur = id == null ? '/barang' : '/barang/$id';
    final metode = id == null ? 'POST' : 'PATCH';
    if (gambar == null) {
      if (id == null) {
        throw const KesalahanApi('Pilih foto barang terlebih dahulu.');
      }
      return (await _json(metode, jalur, isi: isian))['data']['id'] as int;
    }
    final png = gambar.length >= 8 && gambar[0] == 137 && gambar[1] == 80;
    final jpg = gambar.length >= 3 && gambar[0] == 255 && gambar[1] == 216;
    if (!png && !jpg) throw const KesalahanApi('Pilih foto JPEG atau PNG.');
    final request = http.MultipartRequest(metode, Uri.parse('$alamat$jalur'));
    request.fields.addAll(isian);
    request.files.add(
      http.MultipartFile.fromBytes(
        'foto',
        gambar,
        filename: png ? 'barang.png' : 'barang.jpg',
        contentType: http.MediaType('image', png ? 'png' : 'jpeg'),
      ),
    );
    final respons = await _kirim(request);
    return (jsonDecode(utf8.decode(respons.bodyBytes)) as Json)['data']['id']
        as int;
  }
}

String hargaRupiah(int nilai) {
  final angka = nilai.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  return 'Rp$angka';
}

String stokTampil(Json barang) {
  var jumlah = barang['stok'].toString();
  if (jumlah.contains('.')) {
    jumlah = jumlah
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
  return '${jumlah.replaceAll('.', ',')} ${barang['satuan']}';
}
