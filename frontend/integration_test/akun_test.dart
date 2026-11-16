import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rakrapi/api.dart';
import 'package:rakrapi/form_akun.dart';
import 'package:rakrapi/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Daftar warga, tambah pegawai, dan pulihkan sesi tiga peran',
    (tester) async {
      const kode = String.fromEnvironment('KODE_UJI');
      expect(kode, matches(RegExp(r'^[0-9a-f]{16}$')));
      final file = File(
        '/data/user/0/com.example.rakrapi/files/rakrapi-uji-akun-$kode',
      );
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

      Future<void> tekan(Finder f) async {
        await tunggu(f);
        await tester.ensureVisible(f.first);
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

      Future<void> masuk(String email, String sandi, String halaman) async {
        await tunggu(find.text('Masuk'));
        await tester.enterText(find.byType(TextField).at(0), email);
        await tester.enterText(find.byType(TextField).at(1), sandi);
        await tekan(find.text('Masuk'));
        await tunggu(find.text(halaman));
      }

      Future<void> isiForm(String nama, String email) async {
        final kolom = find.descendant(
          of: find.byType(FormAkun),
          matching: find.byType(TextField),
        );
        await tunggu(kolom);
        await tester.enterText(kolom.at(0), nama);
        await tester.enterText(kolom.at(1), email);
        await tester.enterText(kolom.at(2), data['sandiBaru']);
        await tekan(find.text('Simpan akun'));
      }

      await bukaLagi();
      if (find.text('Keluar').evaluate().isNotEmpty) {
        await tekan(find.text('Keluar'));
      }
      await tekan(find.text('Daftar sebagai warga'));
      await isiForm('Warga emulator', 'warga.emulator@rakrapi.test');
      await masuk('warga.emulator@rakrapi.test', data['sandiBaru'], 'Bansos');
      await bukaLagi();
      await tunggu(find.text('Bansos'));
      expect(find.text('Daftar barang'), findsNothing);
      await tekan(find.text('Keluar'));

      await masuk(emailPemilik, data['password'], 'Daftar barang');
      await bukaLagi();
      await tekan(find.byTooltip('Menu pemilik'));
      await tekan(find.text('Tambah pegawai'));
      await isiForm('Pegawai emulator', 'pegawai.emulator@rakrapi.test');
      await tunggu(
        find.text('Akun pegawai pegawai.emulator@rakrapi.test dibuat.'),
      );
      await tekan(find.text('Keluar'));

      await masuk(
        'pegawai.emulator@rakrapi.test',
        data['sandiBaru'],
        'Daftar barang',
      );
      await bukaLagi();
      await tunggu(find.text('Daftar barang'));
      expect(find.byTooltip('Menu pemilik'), findsNothing);
      expect(find.text('Tambah barang'), findsNothing);
      await tekan(find.text('Keluar'));
      await tunggu(find.text('Masuk'));
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
