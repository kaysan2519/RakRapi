import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rakrapi/api.dart';
import 'package:rakrapi/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Pegawai membaca katalog utama, pemilik menyimpan di katalog uji',
    (tester) async {
      // Helper lokal memasukkan konfigurasi privat ke direktori internal APK debug.
      final file = File(
        '/data/user/0/com.example.rakrapi/files/rakrapi-qa.json',
      );
      final siap = File('${file.path}.siap');
      await siap.writeAsString('');
      final batas = DateTime.now().add(const Duration(minutes: 2));
      while (!await file.exists() && DateTime.now().isBefore(batas)) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      final uji = jsonDecode(await file.readAsString()) as Json;
      await file.delete();
      await siap.delete();

      Future<void> tunggu(Finder widget, {int detik = 45}) async {
        final akhir = DateTime.now().add(Duration(seconds: detik));
        while (widget.evaluate().isEmpty && DateTime.now().isBefore(akhir)) {
          await tester.pump(const Duration(milliseconds: 150));
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        expect(widget, findsWidgets);
      }

      Future<void> tekan(Finder widget) async {
        await tunggu(widget);
        await tester.ensureVisible(widget.first);
        await tester.tap(widget.first);
        await tester.pump();
      }

      Future<void> masuk(String role) async {
        await tunggu(find.text('Masuk'));
        await tester.enterText(
          find.byType(TextField).first,
          '$role.uji@rakrapi.test',
        );
        await tester.enterText(find.byType(TextField).last, uji[role]);
        await tekan(find.text('Masuk'));
        await tunggu(find.text('Daftar barang'));
      }

      final utama = RakRapiApi(alamat: 'http://127.0.0.1:3000/api');
      await tester.pumpWidget(RakRapi(api: utama));
      await tester.pumpAndSettle();
      if (find.text('Keluar').evaluate().isNotEmpty) {
        await tekan(find.text('Keluar'));
      }
      await masuk('pegawai');
      await tekan(find.text('Minyak goreng 1 L'));
      await tunggu(find.bySemanticsLabel('Foto barang'));
      expect(find.text('Rp19.000'), findsOneWidget);
      expect(find.text('12 botol'), findsOneWidget);
      expect(find.text('Minyak Goreng'), findsOneWidget);
      expect(find.text('Hapus barang'), findsNothing);
      expect(find.text('Ubah barang'), findsNothing);
      debugPrint(
        'UI pegawai: detail ID 2, harga, stok dan foto privat tampil.',
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Tambah barang'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(RakRapi(api: RakRapiApi(alamat: utama.alamat)));
      await tunggu(find.text('Minyak goreng 1 L'));
      await tekan(find.text('Keluar'));
      await tunggu(find.text('Masuk'));

      final port = uji['portUji'] as int;
      expect(port, isNot(3000));
      final terpisah = RakRapiApi(alamat: 'http://127.0.0.1:$port/api');
      await tester.pumpWidget(RakRapi(key: UniqueKey(), api: terpisah));
      await masuk('pemilik');
      await tunggu(find.text('Belum ada barang.'));
      // Kategori penanda unik hanya dibuat oleh runner di schema MySQL sementara.
      expect((await terpisah.kategori()).single['nama'], uji['penanda']);
      await tekan(find.text('Tambah barang'));
      await tunggu(find.text('Pilih foto'));
      await tester.enterText(find.byType(TextFormField).at(0), 'Produk UI');
      await tekan(find.text('Tambah kategori'));
      await tunggu(find.text('Nama kategori'));
      final namaKategori = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(namaKategori, 'Kategori UI');
      await tekan(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Simpan'),
        ),
      );
      await tunggu(find.text('Kategori UI'));
      await tester.enterText(find.byType(TextFormField).at(1), '24500');
      await tester.enterText(find.byType(TextFormField).at(2), '7');
      await tekan(find.text('Pilih foto'));
      // Pemilih Android dibuka sungguhan. Pilih gambar uji dari galeri emulator.
      await tunggu(find.bySemanticsLabel('Pratinjau foto'), detik: 240);
      await tekan(find.text('Simpan'));
      await tunggu(find.text('Detail barang'));
      await tunggu(find.bySemanticsLabel('Foto barang'));
      expect(find.text('Produk UI'), findsOneWidget);
      expect(find.text('Rp24.500'), findsOneWidget);
      expect(find.text('7 botol'), findsOneWidget);
      expect(find.text('Kategori UI'), findsOneWidget);
      expect(find.text('Ubah barang'), findsOneWidget);
      final barang = (await terpisah.daftarBarang()).single;
      debugPrint(
        'UI pemilik: kategori langsung terpilih, unggah dan detail ID ${barang['id']} lulus.',
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tekan(find.text('Keluar'));
      await masuk('pegawai');
      await tekan(find.text('Produk UI'));
      await tunggu(find.bySemanticsLabel('Foto barang'));
      expect(find.text('Ubah barang'), findsNothing);
      debugPrint('UI pegawai: barang dan foto baru dari API uji terbuka.');
    },
    timeout: const Timeout(Duration(minutes: 9)),
  );
}
