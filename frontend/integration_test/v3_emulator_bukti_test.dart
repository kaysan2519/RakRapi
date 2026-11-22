import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rakrapi/api.dart';
import 'package:rakrapi/main.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Verifikasi E2E RakRapi V3 tiga role terhubung Aiven + Cloudinary',
    (tester) async {
      const apiUrl = String.fromEnvironment(
        'API_URL',
        defaultValue: 'http://127.0.0.1:3000/api',
      );
      const emailPemilik = String.fromEnvironment('EMAIL_PEMILIK');
      const sandiPemilik = String.fromEnvironment('SANDI_PEMILIK');
      const emailPegawai = String.fromEnvironment('EMAIL_PEGAWAI');
      const sandiPegawai = String.fromEnvironment('SANDI_PEGAWAI');
      const emailPembeli = String.fromEnvironment('EMAIL_PEMBELI');
      const sandiPembeli = String.fromEnvironment('SANDI_PEMBELI');

      var converted = false;
      Future<void> tangkap(String nama) async {
        await tester.pumpAndSettle(const Duration(milliseconds: 600));
        if (!converted) {
          await binding.convertFlutterSurfaceToImage();
          converted = true;
        }
        await tester.pumpAndSettle(const Duration(milliseconds: 400));
        await binding.takeScreenshot(nama);
      }

      Future<void> tunggu(Finder f, {int detik = 40}) async {
        final batas = DateTime.now().add(Duration(seconds: detik));
        while (f.evaluate().isEmpty && DateTime.now().isBefore(batas)) {
          await tester.pump(const Duration(milliseconds: 200));
          await Future<void>.delayed(const Duration(milliseconds: 150));
        }
        expect(f, findsWidgets);
      }

      Future<void> tekan(Finder f) async {
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await tunggu(f);
        await tester.ensureVisible(f.first);
        await tester.pumpAndSettle();
        await tester.tap(f.first);
        await tester.pumpAndSettle();
      }

      Future<void> keluarDariTabAkun() async {
        await tekan(find.text('Akun'));
        await tunggu(find.widgetWithText(OutlinedButton, 'Keluar'));
        await tekan(find.widgetWithText(OutlinedButton, 'Keluar'));
        await tunggu(find.widgetWithText(FilledButton, 'Keluar'));
        await tekan(find.widgetWithText(FilledButton, 'Keluar'));
        await tunggu(find.text('Masuk ke Akun'));
      }

      Future<void> masukSebagai(String email, String sandi, String targetText) async {
        await tunggu(find.text('Masuk ke Akun'));
        await tester.enterText(find.widgetWithText(TextField, 'Email'), email);
        await tester.enterText(find.widgetWithText(TextField, 'Password'), sandi);
        await tekan(find.widgetWithText(FilledButton, 'Masuk'));
        await tunggu(find.text(targetText));
        // Beri waktu foto Cloudinary selesai termuat
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
      }

      await tester.pumpWidget(RakRapi(api: RakRapiApi(alamat: apiUrl)));
      await tester.pumpAndSettle();

      // Jika masih ada sesi lama, keluar terlebih dahulu
      if (find.text('Masuk ke Akun').evaluate().isEmpty &&
          find.text('Akun').evaluate().isNotEmpty) {
        await keluarDariTabAkun();
      }

      // 1. Screenshot Login V3
      await tunggu(find.text('Masuk ke Akun'));
      expect(find.text('Belum punya akun? '), findsOneWidget);
      expect(find.text('Daftar sebagai pembeli'), findsNothing);
      expect(find.text('Pilih role'), findsNothing);
      await tangkap('01-login');

      // 2. Buka Register V3 & screenshot
      await tekan(find.widgetWithText(TextButton, 'Daftar'));
      await tunggu(find.text('Daftar Akun'));
      expect(find.text('Sudah punya akun? '), findsOneWidget);
      expect(find.text('Pilih role'), findsNothing);
      await tangkap('02-register');

      // Daftarkan akun pembeli uji jika belum terdaftar (idempoten)
      await tester.enterText(
        find.widgetWithText(TextField, 'Nama Lengkap'),
        'Pembeli Uji',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Email'),
        emailPembeli,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Password'),
        sandiPembeli,
      );
      await tekan(find.widgetWithText(FilledButton, 'Daftar'));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      if (find.text('Daftar Akun').evaluate().isNotEmpty) {
        // Email sudah terdaftar sebelumnya -> kembali ke Masuk
        await tekan(find.widgetWithText(TextButton, 'Masuk'));
      }

      // 3. Login Pembeli -> Beranda Pembeli -> Katalog -> Detail ID 2
      await masukSebagai(
        emailPembeli,
        sandiPembeli,
        'Mau belanja apa hari ini?',
      );
      expect(find.text('Info toko'), findsOneWidget);
      expect(find.text('Info prioritas'), findsOneWidget);
      await tangkap('03-beranda-pembeli');

      await tekan(find.text('Katalog'));
      await tunggu(find.text('Minyak goreng 1 L'));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      await tangkap('04-katalog-pembeli');

      await tekan(find.text('Minyak goreng 1 L'));
      await tunggu(find.text('Detail produk'));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      await tangkap('05-detail-produk');
      await tester.pageBack();
      await tester.pumpAndSettle();

      await keluarDariTabAkun();

      // 4. Login Pemilik -> Dashboard Pemilik -> Pin Prioritas
      await masukSebagai(emailPemilik, sandiPemilik, 'Ringkasan toko');
      expect(find.text('Pin informasi ke beranda'), findsOneWidget);
      await tangkap('06-dashboard-pemilik');

      await tekan(find.text('Pin informasi ke beranda'));
      await tunggu(find.text('2 informasi sedang dipin'));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      await tangkap('07-pin-prioritas');
      await tester.pageBack();
      await tester.pumpAndSettle();

      await keluarDariTabAkun();

      // 5. Login Pegawai -> Dashboard Pegawai
      await masukSebagai(emailPegawai, sandiPegawai, 'Kelola operasional');
      expect(find.text('Pin informasi ke beranda'), findsNothing);
      await tangkap('08-dashboard-pegawai');

      await keluarDariTabAkun();
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 6)),
  );
}
