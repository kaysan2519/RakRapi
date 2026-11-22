import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rakrapi/api.dart';
import 'package:rakrapi/form_akun.dart';
import 'package:rakrapi/main.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Daftar warga, tambah pegawai, dan pulihkan sesi tiga peran',
    (tester) async {
      const kode = String.fromEnvironment('KODE_UJI');
      expect(kode, matches(RegExp(r'^[0-9a-f]{16}$')));
      final folder = Directory.systemTemp.parent.path;
      final file = File('$folder/files/rakrapi-uji-akun-$kode');
      final siap = File('${file.path}.siap');
      await siap.writeAsString('');
      final batas = DateTime.now().add(const Duration(minutes: 2));
      while (!await file.exists() && DateTime.now().isBefore(batas)) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      final data = jsonDecode(await file.readAsString()) as Json;
      await file.delete();
      await siap.delete();
      final port = data['port'] as int;
      expect(port, isNot(3000));
      final url = 'http://127.0.0.1:$port/api';
      final emailPemilik = 'pemilik.$kode@rakrapi.test';
      expect(data['emailPemilik'], emailPemilik);
      // Pastikan ini server fixture sebelum membuat akun melalui tampilan.
      final cek = await RakRapiApi(
        alamat: url,
      ).masuk(emailPemilik, data['password']);
      expect(cek['user']['role'], 'pemilik');

      Future<void> tunggu(Finder f) async {
        final akhir = DateTime.now().add(const Duration(seconds: 45));
        while (f.evaluate().isEmpty && DateTime.now().isBefore(akhir)) {
          await tester.pump(const Duration(milliseconds: 150));
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        expect(f, findsWidgets);
      }

      Future<void> tekan(Finder f, {bool gulir = false}) async {
        // Form panjang perlu keyboard ditutup dan digulir seperti saat dipakai pengguna.
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        if (gulir) {
          await tester.scrollUntilVisible(
            f,
            250,
            scrollable: find
                .descendant(
                  of: find.byType(ListView),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
        }
        await tunggu(f);
        await tester.ensureVisible(f.first);
        await tester.pumpAndSettle();
        await tester.tap(f.first);
        await tester.pumpAndSettle();
      }

      Future<void> bukaLagi() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(
          RakRapi(
            key: UniqueKey(),
            api: RakRapiApi(alamat: url),
          ),
        );
        await tester.pumpAndSettle();
      }

      Future<void> simpanBukti(String nama) async {
        if (data['bukti'] != true) return;
        await tester.pumpAndSettle();
        final bytes = await binding.takeScreenshot(nama);
        await File('${file.path}-$nama.png').writeAsBytes(bytes, flush: true);
      }

      Future<void> masuk(String email, String sandi, String halaman) async {
        await tunggu(find.text('Masuk'));
        await tester.enterText(find.byType(TextField).at(0), email);
        await tester.enterText(find.byType(TextField).at(1), sandi);
        await tekan(find.text('Masuk'));
        await tunggu(find.text(halaman));
      }

      Future<void> isiForm(
        String nama,
        String email, {
        String tombol = 'Simpan akun',
      }) async {
        final kolom = find.descendant(
          of: find.byType(FormAkun),
          matching: find.byType(TextField),
        );
        await tunggu(kolom);
        await tester.enterText(kolom.at(0), nama);
        await tester.enterText(kolom.at(1), email);
        await tester.enterText(kolom.at(2), data['sandiBaru']);
        await tekan(find.text(tombol));
      }

      await bukaLagi();
      if (find.byTooltip('Keluar').evaluate().isNotEmpty) {
        await tekan(find.byTooltip('Keluar'));
      }
      await tekan(find.text('Daftar sebagai pembeli'));
      await isiForm(
        'Warga emulator',
        'warga.emulator@rakrapi.test',
        tombol: 'Daftar',
      );
      await masuk(
        'warga.emulator@rakrapi.test',
        data['sandiBaru'],
        'Katalog Barang',
      );
      await tunggu(find.text('Katalog'));
      expect(find.text('Tambah barang'), findsNothing);
      await tekan(find.text('Bansos'));
      await tunggu(find.text('Layanan bansos sedang disiapkan'));
      await bukaLagi();
      await tunggu(find.text('Katalog Barang'));
      await tekan(find.byTooltip('Keluar'));

      await masuk(emailPemilik, data['password'], 'Katalog Barang');
      await bukaLagi();
      await tekan(find.byTooltip('Menu pemilik'));
      await tekan(find.text('Tambah pegawai'));
      await isiForm('Pegawai emulator', 'pegawai.emulator@rakrapi.test');
      await tunggu(
        find.text('Akun pegawai pegawai.emulator@rakrapi.test dibuat.'),
      );
      await tekan(find.byTooltip('Menu pemilik'));
      await tekan(find.text('Kelola lowongan'));
      await tester.enterText(find.byType(TextField), 'Penjaga toko uji');
      await tekan(find.text('Buka lowongan'));
      await tunggu(find.text('Penjaga toko uji'));
      await tester.pageBack();
      await tester.pumpAndSettle();
      final apiPemilik = RakRapiApi(alamat: url)..token = cek['token'];
      await apiPemilik.tambahKategori('Sembako uji');
      await tekan(find.byTooltip('Keluar'));

      await masuk(
        'pegawai.emulator@rakrapi.test',
        data['sandiBaru'],
        'Katalog Barang',
      );
      await bukaLagi();
      await tunggu(find.text('Katalog Barang'));
      expect(find.byTooltip('Menu pemilik'), findsNothing);
      await tekan(find.text('Tambah barang'));
      expect(find.text('Tambah kategori'), findsNothing);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nama barang'),
        'Beras uji',
      );
      await tekan(find.byType(DropdownButtonFormField<int>));
      await tekan(find.text('Sembako uji').last);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Harga per satuan'),
        '25000',
      );
      await tester.enterText(find.widgetWithText(TextFormField, 'Stok'), '8');
      await tekan(find.byType(DropdownButtonFormField<String>));
      await tekan(find.text('kg').last);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      // Hanya pilihan berkas Android yang disimulasikan. Form, upload, API dan MySQL berjalan asli.
      final fotoUji = File('${Directory.systemTemp.path}/barang-uji.png');
      final gambar = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAIAAAD8GO2jAAAAO0lEQVR4nO3RQREAMAjEwKNCq7laUFAJ4cMvK+CYCdXvZtNZXY8HBvwBMhEyETIRMhEyETIRMhEyUcgHUgkCYJsgX6IAAAAASUVORK5CYII=',
      );
      await fotoUji.writeAsBytes(gambar);
      const kanal =
          'dev.flutter.pigeon.image_picker_android.ImagePickerApi.pickImages';
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMessageHandler(
        kanal,
        (_) async => const StandardMessageCodec().encodeMessage([
          [fotoUji.path],
        ]),
      );
      addTearDown(() => messenger.setMockMessageHandler(kanal, null));
      await tekan(find.text('Pilih foto'));
      await tunggu(find.bySemanticsLabel('Pratinjau foto'));
      if (data['bukti'] == true) {
        await binding.convertFlutterSurfaceToImage();
        await tester.pumpAndSettle();
        final bytes = await binding.takeScreenshot('form-pegawai');
        await File('${file.path}.png').writeAsBytes(bytes, flush: true);
      }
      await tekan(find.text('Simpan'), gulir: true);
      await tunggu(find.text('Detail barang'));
      await tunggu(find.bySemanticsLabel('Foto barang'));
      expect(find.text('Hapus barang'), findsNothing);
      await tekan(find.text('Ubah barang'));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Harga per satuan'),
        '26000',
      );
      await tekan(find.text('Simpan'), gulir: true);
      await tunggu(find.text('Rp26.000'));
      final barang = (await apiPemilik.daftarBarang()).single;
      expect(barang['harga_rupiah'], 26000);
      expect(await apiPemilik.foto(barang['id']), orderedEquals(gambar));
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tekan(find.byTooltip('Keluar'));
      await masuk(
        'warga.emulator@rakrapi.test',
        data['sandiBaru'],
        'Katalog Barang',
      );
      await tunggu(find.text('Beras uji'));
      await simpanBukti('katalog-warga');
      await tekan(find.text('Beras uji'));
      await tunggu(find.bySemanticsLabel('Foto barang'));
      await tester.enterText(find.byType(TextFormField), '2,125');
      FocusManager.instance.primaryFocus?.unfocus();
      await tekan(find.text('Tambah ke keranjang'), gulir: true);
      await tunggu(find.text('Katalog Barang'));
      await tekan(find.byTooltip('Keranjang'));
      await tunggu(find.text('Rp55.250'));
      await simpanBukti('keranjang-warga');
      await tekan(find.text('Kirim pesanan'));
      await tunggu(find.text('Menunggu konfirmasi'));
      final pesanan = (await apiPemilik.pesanan()).single;
      expect(pesanan['total_rupiah'].toString(), '55250');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tekan(find.byTooltip('Keluar'));
      await masuk(
        'pegawai.emulator@rakrapi.test',
        data['sandiBaru'],
        'Katalog Barang',
      );
      await tekan(find.byTooltip('Pesanan masuk'));
      await tunggu(find.text('Pesanan #${pesanan['id']}'));
      await simpanBukti('pesanan-masuk');
      await tekan(find.text('Pesanan #${pesanan['id']}'));
      await tekan(find.text('Konfirmasi pesanan'));
      await tunggu(find.text('Dikonfirmasi'));
      expect((await apiPemilik.detail(barang['id']))['stok'], '5.875');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tekan(find.byTooltip('Keluar'));
      await masuk(
        'warga.emulator@rakrapi.test',
        data['sandiBaru'],
        'Katalog Barang',
      );
      await bukaLagi();
      await tekan(find.byTooltip('Pesanan saya'));
      await tunggu(find.text('Dikonfirmasi'));
      await tester.pageBack();
      await tester.pumpAndSettle();
      debugPrint(
        'UI pesanan: Rp55.250, dikonfirmasi pegawai, stok uji 8 menjadi 5.875 kg.',
      );
      await tekan(find.text('Lowongan'));
      await tunggu(find.text('Penjaga toko uji'));
      await tekan(find.text('Katalog'));
      await tekan(find.byTooltip('Keluar'));
      await masuk(emailPemilik, data['password'], 'Katalog Barang');
      await tekan(find.byTooltip('Menu pemilik'));
      await tekan(find.text('Kelola lowongan'));
      await tekan(find.text('Tutup'));
      await tunggu(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Penjaga toko uji'),
          matching: find.text('Ditutup'),
        ),
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tekan(find.byTooltip('Keluar'));
      await masuk(
        'warga.emulator@rakrapi.test',
        data['sandiBaru'],
        'Katalog Barang',
      );
      await tekan(find.text('Lowongan'));
      await tekan(find.byTooltip('Muat ulang'));
      await tunggu(find.text('Belum ada lowongan aktif.'));
      expect(find.text('Penjaga toko uji'), findsNothing);
      await apiPemilik.bukaLowongan('Kurir uji');
      await tekan(find.byTooltip('Muat ulang'));
      await tunggu(find.text('Kurir uji'));
      final kurir = (await apiPemilik.lowongan()).singleWhere(
        (l) => l['judul'] == 'Kurir uji',
      );
      await apiPemilik.tutupLowongan(kurir['id']);
      await tekan(find.byTooltip('Muat ulang'));
      await tunggu(find.text('Belum ada lowongan aktif.'));
      expect(find.text('Kurir uji'), findsNothing);
      await tekan(find.text('Katalog'));
      await tekan(find.byTooltip('Keluar'));
      await tunggu(find.text('Masuk'));

      // Akun utama hanya untuk baca. Seluruh percobaan tulis di atas memakai API uji.
      if (data['pegawaiUtama'] != null) {
        final utama = RakRapiApi(alamat: 'http://127.0.0.1:3000/api');
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(RakRapi(key: UniqueKey(), api: utama));
        await masuk(
          'pegawai.uji@rakrapi.test',
          data['pegawaiUtama'],
          'Katalog Barang',
        );
        await tekan(find.text('Minyak goreng 1 L'));
        await tunggu(find.bySemanticsLabel('Foto barang'));
        expect(find.text('Rp19.000'), findsOneWidget);
        expect(find.text('12 botol'), findsOneWidget);
        expect(find.text('Minyak Goreng'), findsOneWidget);
        await simpanBukti('detail-id2-laragon');
        debugPrint(
          'UI Laragon utama: ID 2, Rp19.000, 12 botol dan foto privat tampil.',
        );
      }
      if (data['bukti'] == true) {
        // Tunggu runner menyalin PNG sebelum Flutter melepas APK uji.
        await File('${file.path}.bukti-siap').writeAsString('');
        final tersalin = File('${file.path}.bukti-selesai');
        final batasSalin = DateTime.now().add(const Duration(seconds: 45));
        while (!await tersalin.exists() &&
            DateTime.now().isBefore(batasSalin)) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
        expect(
          await tersalin.exists(),
          isTrue,
          reason: 'Screenshot tersalin ke laptop',
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
