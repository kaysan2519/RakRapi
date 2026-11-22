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
  final Map<String, Uint8List> _cacheFoto = {};

  void bersihkanCacheFoto() => _cacheFoto.clear();
  void hapusCacheFoto(String path) => _cacheFoto.remove(path);

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
        'API belum merespons. Periksa koneksi lalu coba lagi.',
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

  Uri _uriFoto(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Uri.parse(path);
    }
    if (path.startsWith('/api/')) {
      final base = alamat.endsWith('/api')
          ? alamat.substring(0, alamat.length - 4)
          : alamat;
      return Uri.parse('$base$path');
    }
    return Uri.parse('$alamat$path');
  }

  Future<Uint8List> fotoDariPath(String path, {bool paksaMuat = false}) async {
    if (!paksaMuat && _cacheFoto.containsKey(path)) {
      return _cacheFoto[path]!;
    }
    final request = http.Request('GET', _uriFoto(path));
    final bytes = (await _kirim(request)).bodyBytes;
    if (_cacheFoto.length > 80) _cacheFoto.clear();
    _cacheFoto[path] = bytes;
    return bytes;
  }

  Future<Json> _kirimMultipart(
    String metode,
    String jalur,
    Map<String, String> isian,
    Uint8List? gambar,
  ) async {
    if (gambar == null) {
      return _json(metode, jalur, isi: isian);
    }
    final deteksi = deteksiJenisGambar(gambar);
    if (deteksi == null) {
      throw const KesalahanApi('Pilih foto JPG, PNG, atau WebP.');
    }
    final request = http.MultipartRequest(metode, Uri.parse('$alamat$jalur'));
    request.fields.addAll(isian);
    request.files.add(
      http.MultipartFile.fromBytes(
        'foto',
        gambar,
        filename: 'foto.${deteksi.$1}',
        contentType: http.MediaType('image', deteksi.$2),
      ),
    );
    final respons = await _kirim(request);
    if (respons.bodyBytes.isEmpty) return {};
    return jsonDecode(utf8.decode(respons.bodyBytes)) as Json;
  }

  // --- Health & Auth ---
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

  Future<List<Json>> daftarPegawai() async =>
      ((await _json('GET', '/auth/pegawai'))['data'] as List).cast<Json>();

  Future<void> tambahPegawai(String nama, String email, String sandi) async {
    await _json(
      'POST',
      '/auth/pegawai',
      isi: {'nama': nama, 'email': email, 'password': sandi},
    );
  }

  // --- Barang & Kategori ---
  Future<List<Json>> daftarBarang({String? q, int? kategoriId}) async {
    final params = <String, String>{};
    if (q != null && q.trim().isNotEmpty) params['q'] = q.trim();
    if (kategoriId != null) params['kategori_id'] = kategoriId.toString();
    final query = params.isEmpty
        ? ''
        : '?${Uri(queryParameters: params).query}';
    return ((await _json('GET', '/barang$query'))['data'] as List).cast<Json>();
  }

  Future<Json> detail(int id) async =>
      (await _json('GET', '/barang/$id'))['data'] as Json;

  Future<Uint8List> foto(int id) => fotoDariPath('/api/barang/$id/foto');

  Future<int> simpanBarang(
    Map<String, String> isian, {
    int? id,
    Uint8List? gambar,
  }) async {
    final jalur = id == null ? '/barang' : '/barang/$id';
    final metode = id == null ? 'POST' : 'PATCH';
    if (gambar == null && id == null) {
      throw const KesalahanApi('Pilih foto barang terlebih dahulu.');
    }
    final hasil = await _kirimMultipart(metode, jalur, isian, gambar);
    final idBaru = hasil['data']['id'] as int;
    hapusCacheFoto('/api/barang/$idBaru/foto');
    return idBaru;
  }

  Future<void> hapus(int id) async {
    await _json('DELETE', '/barang/$id');
    hapusCacheFoto('/api/barang/$id/foto');
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

  // --- Pesanan & Pembayaran ---
  Future<Json> kirimPesanan(
    String kunci,
    List<Json> item, {
    String metodePembayaran = 'Bayar di kasir',
  }) async =>
      (await _json(
            'POST',
            '/pesanan',
            isi: {
              'kunci_kirim': kunci,
              'metode_pembayaran': metodePembayaran,
              'item': item,
            },
          ))['data']
          as Json;

  Future<List<Json>> pesanan() async =>
      ((await _json('GET', '/pesanan'))['data'] as List).cast<Json>();

  Future<Json> detailPesanan(int id) async =>
      (await _json('GET', '/pesanan/$id'))['data'] as Json;

  Future<Json> konfirmasiPesanan(int id) async =>
      (await _json('PATCH', '/pesanan/$id/konfirmasi'))['data'] as Json;

  Future<Json> siapDiambilPesanan(int id) async =>
      (await _json('PATCH', '/pesanan/$id/siap'))['data'] as Json;

  Future<Json> verifikasiPembayaranPesanan(int id) async =>
      (await _json('PATCH', '/pesanan/$id/bayar'))['data'] as Json;

  Future<Json> selesaikanPesanan(int id) async =>
      (await _json('PATCH', '/pesanan/$id/selesai'))['data'] as Json;

  // --- Lowongan & Lamaran ---
  Future<List<Json>> lowongan() async =>
      ((await _json('GET', '/lowongan'))['data'] as List).cast<Json>();

  Future<void> bukaLowongan(String judul) async {
    await _json('POST', '/lowongan', isi: {'judul': judul});
  }

  Future<Json> simpanLowongan(
    Map<String, String> isian, {
    int? id,
    Uint8List? gambar,
  }) async {
    final jalur = id == null ? '/lowongan' : '/lowongan/$id';
    final metode = id == null ? 'POST' : 'PATCH';
    final res = await _kirimMultipart(metode, jalur, isian, gambar);
    final data = res['data'] as Json;
    hapusCacheFoto('/api/lowongan/${data['id']}/foto');
    return data;
  }

  Future<void> tutupLowongan(int id) async {
    await _json('PATCH', '/lowongan/$id/tutup');
  }

  Future<Json> pinLowongan(int id, bool pinned) async =>
      (await _json(
            'PATCH',
            '/lowongan/$id/pin',
            isi: {'is_pinned': pinned},
          ))['data']
          as Json;

  Future<void> hapusLowongan(int id) async {
    await _json('DELETE', '/lowongan/$id');
    hapusCacheFoto('/api/lowongan/$id/foto');
  }

  Future<Json> ajukanLamaran(
    int lowonganId,
    String namaPelamar,
    String keterangan,
  ) async =>
      (await _json(
            'POST',
            '/lowongan/$lowonganId/lamar',
            isi: {'nama_pelamar': namaPelamar, 'keterangan': keterangan},
          ))['data']
          as Json;

  Future<List<Json>> lamaranSaya() async =>
      ((await _json('GET', '/lowongan/lamaran/saya'))['data'] as List)
          .cast<Json>();

  Future<List<Json>> semuaLamaran() async =>
      ((await _json('GET', '/lowongan/lamaran'))['data'] as List).cast<Json>();

  Future<Json> tinjauLamaran(int id, String status) async =>
      (await _json(
            'PATCH',
            '/lowongan/lamaran/$id',
            isi: {'status': status},
          ))['data']
          as Json;

  // --- Bansos & Pengajuan ---
  Future<List<Json>> daftarBansos() async =>
      ((await _json('GET', '/bansos'))['data'] as List).cast<Json>();

  Future<Json> simpanBansos(
    Map<String, String> isian, {
    int? id,
    Uint8List? gambar,
  }) async {
    final jalur = id == null ? '/bansos' : '/bansos/$id';
    final metode = id == null ? 'POST' : 'PATCH';
    final res = await _kirimMultipart(metode, jalur, isian, gambar);
    final data = res['data'] as Json;
    hapusCacheFoto('/api/bansos/${data['id']}/foto');
    return data;
  }

  Future<Json> pinBansos(int id, bool pinned) async =>
      (await _json(
            'PATCH',
            '/bansos/$id/pin',
            isi: {'is_pinned': pinned},
          ))['data']
          as Json;

  Future<void> hapusBansos(int id) async {
    await _json('DELETE', '/bansos/$id');
    hapusCacheFoto('/api/bansos/$id/foto');
  }

  Future<Json> ajukanBansos(
    int programId,
    String namaPemohon,
    String keterangan,
  ) async =>
      (await _json(
            'POST',
            '/bansos/$programId/ajukan',
            isi: {'nama_pemohon': namaPemohon, 'keterangan': keterangan},
          ))['data']
          as Json;

  Future<List<Json>> pengajuanBansosSaya() async =>
      ((await _json('GET', '/bansos/pengajuan/saya'))['data'] as List)
          .cast<Json>();

  Future<List<Json>> semuaPengajuanBansos() async =>
      ((await _json('GET', '/bansos/pengajuan'))['data'] as List).cast<Json>();

  Future<Json> tinjauPengajuanBansos(int id, String status) async =>
      (await _json(
            'PATCH',
            '/bansos/pengajuan/$id',
            isi: {'status': status},
          ))['data']
          as Json;

  // --- Pengumuman & Diskon ---
  Future<List<Json>> daftarPengumuman() async =>
      ((await _json('GET', '/pengumuman'))['data'] as List).cast<Json>();

  Future<Json> simpanPengumuman(
    Map<String, String> isian, {
    int? id,
    Uint8List? gambar,
  }) async {
    final jalur = id == null ? '/pengumuman' : '/pengumuman/$id';
    final metode = id == null ? 'POST' : 'PATCH';
    final res = await _kirimMultipart(metode, jalur, isian, gambar);
    final data = res['data'] as Json;
    hapusCacheFoto('/api/pengumuman/${data['id']}/foto');
    return data;
  }

  Future<Json> pinPengumuman(int id, bool pinned) async =>
      (await _json(
            'PATCH',
            '/pengumuman/$id/pin',
            isi: {'is_pinned': pinned},
          ))['data']
          as Json;

  Future<void> hapusPengumuman(int id) async {
    await _json('DELETE', '/pengumuman/$id');
    hapusCacheFoto('/api/pengumuman/$id/foto');
  }

  // --- Pin Prioritas, Info Toko, Dashboard ---
  Future<List<Json>> daftarPin({bool semua = false}) async {
    final query = semua ? '?semua=1' : '';
    return ((await _json('GET', '/pin$query'))['data'] as List).cast<Json>();
  }

  Future<Json> infoToko() async =>
      (await _json('GET', '/toko'))['data'] as Json;

  Future<Json> perbaruiInfoToko(Json isian) async =>
      (await _json('PATCH', '/toko', isi: isian))['data'] as Json;

  Future<Json> ringkasanDashboard() async =>
      (await _json('GET', '/dashboard'))['data'] as Json;
}

(String, String)? deteksiJenisGambar(Uint8List bytes) {
  if (bytes.length >= 8 &&
      bytes[0] == 137 &&
      bytes[1] == 80 &&
      bytes[2] == 78 &&
      bytes[3] == 71) {
    return ('png', 'png');
  }
  if (bytes.length >= 3 && bytes[0] == 255 && bytes[1] == 216) {
    return ('jpg', 'jpeg');
  }
  if (bytes.length >= 12 &&
      bytes[0] == 82 &&
      bytes[1] == 73 &&
      bytes[2] == 70 &&
      bytes[3] == 70 &&
      bytes[8] == 87 &&
      bytes[9] == 69 &&
      bytes[10] == 66 &&
      bytes[11] == 80) {
    return ('webp', 'webp');
  }
  return null;
}

String hargaRupiah(Object nilai) {
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
