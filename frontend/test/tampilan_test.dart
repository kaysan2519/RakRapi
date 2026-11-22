import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rakrapi/api.dart';
import 'package:rakrapi/dashboard_pengelola.dart';
import 'package:rakrapi/katalog.dart';
import 'package:rakrapi/keranjang.dart';
import 'package:rakrapi/lowongan.dart';
import 'package:rakrapi/main.dart';
import 'package:rakrapi/pengelolaan_toko.dart';
import 'package:rakrapi/theme/app_theme.dart';

// Fixture hanya untuk tes widget. Tidak menghubungi API atau mengisi MySQL.
class ApiTampilanUji extends RakRapiApi {
  List<Json> barang = [
    {
      'id': 2,
      'nama': 'Barang uji botol',
      'kategori_id': 1,
      'nama_kategori': 'Minyak',
      'harga_rupiah': 19000,
      'stok': '12',
      'satuan': 'botol',
      'deskripsi': 'Minyak goreng uji',
      'foto_url': '/api/barang/2/foto',
    },
    {
      'id': 3,
      'nama': 'Barang uji kg',
      'kategori_id': 2,
      'nama_kategori': 'Beras',
      'harga_rupiah': 15000,
      'stok': '10',
      'satuan': 'kg',
      'deskripsi': 'Beras uji',
      'foto_url': '/api/barang/3/foto',
    },
  ];
  List<Json> kategoriList = [
    {'id': 1, 'nama': 'Minyak', 'jumlah_produk': 1},
    {'id': 2, 'nama': 'Beras', 'jumlah_produk': 1},
  ];
  List<Json> pekerjaan = [
    {
      'id': 1,
      'judul': 'Lowongan uji',
      'deskripsi': 'Deskripsi uji',
      'info_tambahan': 'Penuh waktu',
      'aktif': true,
      'is_pinned': true,
    },
  ];
  final fotoDiminta = <String>[];
  int permintaanDaftar = 0;
  List<Json> pegawaiList = [
    {
      'id': 10,
      'nama': 'Pegawai Aktif Uji',
      'email': 'staf@uji.test',
      'role': 'pegawai',
      'status': 'aktif',
      'alasan_pemberhentian': null,
      'diberhentikan_pada': null,
    },
  ];

  @override
  Future<List<Json>> daftarPegawai() async => pegawaiList;

  @override
  Future<Json> detailPegawai(int id) async =>
      pegawaiList.firstWhere((p) => p['id'] == id);

  @override
  Future<Json> berhentikanPegawai(int id, String alasan) async {
    final idx = pegawaiList.indexWhere((p) => p['id'] == id);
    final updated = {
      ...pegawaiList[idx],
      'status': 'diberhentikan',
      'alasan_pemberhentian': alasan,
      'diberhentikan_pada': '2026-11-22 18:10:00',
    };
    pegawaiList[idx] = updated;
    return updated;
  }

  @override
  Future<List<Json>> daftarBarang({String? q, int? kategoriId}) async {
    permintaanDaftar++;
    return barang;
  }

  @override
  Future<List<Json>> kategori() async => kategoriList;

  @override
  Future<Json> detail(int id) async => barang.firstWhere((b) => b['id'] == id);

  @override
  Future<List<Json>> lowongan() async => pekerjaan;

  @override
  Future<List<Json>> lamaranSaya() async => [];

  @override
  Future<List<Json>> semuaLamaran() async => [];

  @override
  Future<List<Json>> daftarPin({bool semua = false}) async => [
    {
      'sumber': 'lowongan',
      'id': 1,
      'jenis': 'Lowongan',
      'judul': 'Lowongan uji',
      'deskripsi': 'Deskripsi uji',
      'is_pinned': true,
    },
  ];

  @override
  Future<Json> infoToko() async => {
    'nama_toko': 'Toko Sembako RakRapi (Demo)',
    'jam_operasional': 'Buka setiap hari · 07.00–21.00 (Demo)',
    'alamat': '',
    'kontak': '',
    'info_pengambilan': 'Ambil di kasir toko.',
    'rekening_tersedia': false,
  };

  @override
  Future<Json> ringkasanDashboard() async => {
    'jumlah_produk': barang.length,
    'jumlah_kategori': kategoriList.length,
    'jumlah_pegawai': 1,
    'stok_menipis': 0,
    'pesanan_masuk': 0,
    'pesanan_diproses': 0,
    'pesanan_selesai': 0,
    'jumlah_pin_aktif': 1,
    'lamaran_menunggu': 0,
    'bansos_menunggu': 0,
  };

  @override
  Future<Uint8List> fotoDariPath(String path, {bool paksaMuat = false}) async {
    fotoDiminta.add(path);
    return base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/2XkAAAAASUVORK5CYII=',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final font = FontLoader('PlusJakartaSans');
    for (final bobot in [
      'Regular',
      'Medium',
      'SemiBold',
      'Bold',
      'ExtraBold',
    ]) {
      font.addFont(rootBundle.load('assets/fonts/PlusJakartaSans-$bobot.ttf'));
    }
    await font.load();
    final ikon = FontLoader('MaterialIcons');
    ikon.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await ikon.load();
    temaRakRapi();
    await GoogleFonts.pendingFonts();
  });

  Future<void> buka(
    WidgetTester tester,
    Widget layar, {
    double lebar = 393,
    double skala = 1,
  }) async {
    tester.view.physicalSize = Size(lebar, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: temaRakRapi(),
        debugShowCheckedModeBanner: false,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(skala)),
          child: child!,
        ),
        home: layar,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Masuk memakai desain V3, password dapat dilihat, register tanpa pilihan role',
    (tester) async {
      String? namaDaftar, emailDaftar, sandiDaftar;
      await buka(
        tester,
        LayarMasuk(
          masuk: (_, _) async =>
              throw const KesalahanApi('Email atau sandi salah.'),
          daftar: (n, e, s) async {
            namaDaftar = n;
            emailDaftar = e;
            sandiDaftar = s;
          },
        ),
      );
      expect(find.text('Masuk ke Akun'), findsOneWidget);
      expect(find.text('Belum punya akun? '), findsOneWidget);
      expect(find.text('Daftar'), findsOneWidget);
      expect(find.text('Daftar sebagai pembeli'), findsNothing);
      expect(find.text('Pilih role'), findsNothing);

      await tester.enterText(
        find.widgetWithText(TextField, 'Email'),
        'uji@example.test',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Password'),
        'sandi-uji',
      );
      await tester.tap(find.byTooltip('Tampilkan password'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Password'))
            .obscureText,
        isFalse,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
      await tester.pumpAndSettle();
      expect(find.text('Email atau sandi salah.'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Daftar'));
      await tester.pumpAndSettle();
      expect(find.text('Daftar Akun'), findsOneWidget);
      expect(find.text('Sudah punya akun? '), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Nama Lengkap'), findsOneWidget);
      expect(find.text('Pilih role'), findsNothing);

      await tester.enterText(
        find.widgetWithText(TextField, 'Nama Lengkap'),
        'Pembeli Uji',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Email'),
        'pembeli@example.test',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Password'),
        'sandi1234',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Daftar'));
      await tester.pumpAndSettle();
      expect(namaDaftar, 'Pembeli Uji');
      expect(emailDaftar, 'pembeli@example.test');
      expect(sandiDaftar, 'sandi1234');
      expect(find.text('Akun berhasil dibuat. Silakan masuk.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Warga melihat katalog V3, filter kategori bekerja, detail menambah ke keranjang',
    (tester) async {
      final api = ApiTampilanUji();
      final keranjang = Keranjang();
      await buka(
        tester,
        DaftarBarang(
          api: api,
          role: 'warga',
          keluar: () {},
          keranjang: keranjang,
        ),
      );
      expect(find.text('Tambah produk'), findsNothing);
      expect(find.text('Barang uji botol'), findsOneWidget);
      expect(api.fotoDiminta, contains('/api/barang/2/foto'));
      await tester.tap(find.widgetWithText(ChoiceChip, 'Minyak'));
      await tester.pumpAndSettle();
      expect(find.text('Barang uji kg'), findsNothing);
      await tester.tap(find.text('Barang uji botol'));
      await tester.pumpAndSettle();
      expect(find.text('Edit produk & stok'), findsNothing);
      expect(find.text('Hapus produk'), findsNothing);
      await tester.ensureVisible(find.byTooltip('Tambah jumlah'));
      await tester.tap(find.byTooltip('Tambah jumlah'));
      await tester.ensureVisible(find.text('Tambah ke keranjang'));
      await tester.tap(find.text('Tambah ke keranjang'));
      await tester.pumpAndSettle();
      expect(keranjang.item[2]!.jumlah, 2000);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Pegawai boleh edit produk, hapus hanya untuk pemilik', (
    tester,
  ) async {
    final api = ApiTampilanUji();
    await buka(tester, DetailBarang(api: api, id: 2, role: 'pegawai'));
    expect(find.text('Edit produk & stok'), findsOneWidget);
    expect(find.text('Hapus produk'), findsNothing);
    await buka(tester, DetailBarang(api: api, id: 2, role: 'pemilik'));
    await tester.scrollUntilVisible(find.text('Hapus produk'), 100);
    expect(find.text('Hapus produk'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Dashboard Pemilik menampilkan tombol Pin informasi ke beranda di atas', (
    tester,
  ) async {
    final api = ApiTampilanUji();
    await buka(
      tester,
      ShellPengelola(
        api: api,
        pengguna: const {
          'id': 3,
          'nama': 'Pemilik Uji',
          'email': 'pemilik@uji.test',
          'role': 'pemilik',
        },
        keluar: () {},
      ),
    );
    expect(find.text('Pin informasi ke beranda'), findsOneWidget);
    expect(find.text('Ringkasan toko'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Lowongan yang ditutup hilang setelah respons muat ulang', (
    tester,
  ) async {
    final api = ApiTampilanUji();
    await buka(tester, LayarLowongan(api: api, pemilik: false));
    expect(find.text('Lowongan uji'), findsOneWidget);
    api.pekerjaan = [];
    await tester.tap(find.byTooltip('Muat ulang'));
    await tester.pumpAndSettle();
    expect(find.text('Lowongan uji'), findsNothing);
    expect(find.text('Belum ada data'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Layar sempit dan ukuran teks besar tidak meluap', (
    tester,
  ) async {
    final api = ApiTampilanUji();
    await buka(
      tester,
      DaftarBarang(api: api, role: 'pemilik', keluar: () {}),
      lebar: 320,
      skala: 1.4,
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, -350));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Pemilik melihat detail pegawai, dialog konfirmasi wajib alasan, lalu status berubah diberhentikan',
    (tester) async {
      final api = ApiTampilanUji();
      await buka(tester, LayarPegawai(api: api));
      expect(find.text('Aktif (1)'), findsOneWidget);
      expect(find.text('Diberhentikan (0)'), findsOneWidget);
      expect(find.text('Pegawai Aktif Uji'), findsOneWidget);

      await tester.tap(find.text('Pegawai Aktif Uji'));
      await tester.pumpAndSettle();
      expect(find.text('Detail pegawai'), findsOneWidget);
      expect(find.text('Berhentikan Pegawai'), findsOneWidget);

      await tester.tap(find.text('Berhentikan Pegawai'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('kehilangan akses aplikasi'),
        findsOneWidget,
      );

      // Coba kirim tanpa alasan -> harus muncul pesan validasi
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Berhentikan Pegawai'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Alasan pemberhentian wajib diisi.'), findsOneWidget);

      // Isi alasan dan konfirmasi
      await tester.enterText(
        find.widgetWithText(TextField, 'Alasan pemberhentian'),
        'Kontrak kerja selesai.',
      );
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Berhentikan Pegawai'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Diberhentikan'), findsOneWidget);
      expect(find.text('Kontrak kerja selesai.'), findsOneWidget);
      expect(find.text('Berhentikan Pegawai'), findsNothing);

      // Kembali ke daftar -> pindah ke tab Diberhentikan
      await tester.tap(find.byTooltip('Kembali'));
      await tester.pumpAndSettle();
      expect(find.text('Aktif (0)'), findsOneWidget);
      expect(find.text('Diberhentikan (1)'), findsOneWidget);
      await tester.tap(find.text('Diberhentikan (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Pegawai Aktif Uji'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
