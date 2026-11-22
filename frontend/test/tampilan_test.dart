import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rakrapi/api.dart';
import 'package:rakrapi/katalog.dart';
import 'package:rakrapi/keranjang.dart';
import 'package:rakrapi/lowongan.dart';
import 'package:rakrapi/main.dart';
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
    },
    {
      'id': 3,
      'nama': 'Barang uji kg',
      'kategori_id': 2,
      'nama_kategori': 'Beras',
      'harga_rupiah': 15000,
      'stok': '10',
      'satuan': 'kg',
    },
  ];
  List<Json> pekerjaan = [
    {'id': 1, 'judul': 'Lowongan uji', 'aktif': true},
  ];
  final fotoDiminta = <int>[];
  int permintaanDaftar = 0;
  @override
  Future<List<Json>> daftarBarang() async {
    permintaanDaftar++;
    return barang;
  }

  @override
  Future<Json> detail(int id) async => barang.firstWhere((b) => b['id'] == id);
  @override
  Future<List<Json>> lowongan() async => pekerjaan;
  @override
  Future<Uint8List> foto(int id) async {
    fotoDiminta.add(id);
    return base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/2XkAAAAASUVORK5CYII=',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final gambar = GlobalKey();

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
      RepaintBoundary(
        key: gambar,
        child: MaterialApp(
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
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> simpanPratinjau(WidgetTester tester, String nama) async {
    if (!const bool.fromEnvironment('SIMPAN_PRATINJAU')) return;
    await tester.runAsync(() async {
      final batas =
          gambar.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final hasil = await batas.toImage(pixelRatio: 2);
      final png = await hasil.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/pratinjau/$nama.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(png!.buffer.asUint8List());
      hasil.dispose();
    });
  }

  testWidgets(
    'Masuk memakai tema lokal, password dapat dilihat, register pembeli tanpa pilih role',
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
      await simpanPratinjau(tester, 'masuk');
      expect(find.text('Belum punya akun? '), findsOneWidget);
      expect(find.text('Daftar sebagai pembeli'), findsOneWidget);
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

      await tester.tap(find.text('Daftar sebagai pembeli'));
      await tester.pumpAndSettle();
      await simpanPratinjau(tester, 'daftar');
      expect(find.widgetWithText(TextField, 'Nama Lengkap'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Email'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Password'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Daftar'), findsOneWidget);
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
      expect(find.text('Akun pembeli dibuat. Silakan masuk.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Warga melihat data API, filter bekerja, detail menambah jumlah ke keranjang',
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
      expect(find.text('Tambah barang'), findsNothing);
      expect(find.text('Barang uji botol'), findsOneWidget);
      expect(api.fotoDiminta, contains(2));
      await simpanPratinjau(tester, 'katalog-fixture');
      await tester.tap(find.widgetWithText(ChoiceChip, 'Minyak'));
      await tester.pumpAndSettle();
      expect(find.text('Barang uji kg'), findsNothing);
      await tester.tap(find.text('Barang uji botol'));
      await tester.pumpAndSettle();
      expect(find.text('Ubah barang'), findsNothing);
      expect(find.text('Hapus barang'), findsNothing);
      await tester.ensureVisible(find.byTooltip('Tambah jumlah'));
      await tester.tap(find.byTooltip('Tambah jumlah'));
      await tester.ensureVisible(find.text('Tambah ke keranjang'));
      await tester.tap(find.text('Tambah ke keranjang'));
      await tester.pumpAndSettle();
      expect(keranjang.item[2]!.jumlah, 2000);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Pegawai boleh mengubah, tombol hapus hanya untuk pemilik', (
    tester,
  ) async {
    final api = ApiTampilanUji();
    await buka(tester, DetailBarang(api: api, id: 2, role: 'pegawai'));
    expect(find.text('Ubah barang'), findsOneWidget);
    expect(find.text('Hapus barang'), findsNothing);
    await buka(tester, DetailBarang(api: api, id: 2, role: 'pemilik'));
    await tester.scrollUntilVisible(find.text('Hapus barang'), 100);
    expect(find.text('Hapus barang'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Katalog kosong tetap bisa dimuat ulang dan tidak diberi produk contoh',
    (tester) async {
      final api = ApiTampilanUji()..barang = [];
      await buka(tester, BerandaWarga(api: api, nama: 'Kaysan', keluar: () {}));
      expect(find.text('Belum ada barang.'), findsOneWidget);
      await simpanPratinjau(tester, 'katalog-kosong');
      await tester.drag(find.byType(ListView).first, const Offset(0, 350));
      await tester.pumpAndSettle();
      expect(api.permintaanDaftar, greaterThan(1));
      await tester.tap(find.text('Bansos'));
      await tester.pumpAndSettle();
      expect(find.text('Layanan bansos sedang disiapkan'), findsOneWidget);
      expect(find.text('Ajukan bansos'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

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
    expect(find.text('Belum ada lowongan aktif.'), findsOneWidget);
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
      skala: 1.5,
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, -350));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Keranjang kg mempertahankan pecahan dan total sesudah edit', (
    tester,
  ) async {
    final api = ApiTampilanUji();
    final keranjang = Keranjang()..atur(api.barang[1], 1250);
    await buka(tester, LayarKeranjang(api: api, keranjang: keranjang));
    expect(find.text('Rp18.750'), findsOneWidget);
    await tester.tap(find.byTooltip('Ubah jumlah Barang uji kg'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '2,125');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(keranjang.item[3]!.jumlah, 2125);
    expect(find.text('Rp31.875'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
