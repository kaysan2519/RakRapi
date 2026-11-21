import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rakrapi/api.dart';
import 'package:rakrapi/main.dart';
import 'package:rakrapi/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Fake bawaan dependensi shared_preferences yang sudah terpasang, hanya untuk tes.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const tokenUji = 'token-fixture-hanya-di-memori';
  const pesanHabis = 'Sesi berakhir. Silakan masuk kembali.';
  late SharedPreferencesAsync penyimpanan;

  http.Response json(Object data, [int status = 200]) => http.Response(
    jsonEncode(data),
    status,
    headers: {'content-type': 'application/json'},
  );

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    penyimpanan = SharedPreferencesAsync();
  });
  setUpAll(() async {
    temaRakRapi();
    await GoogleFonts.pendingFonts();
  });

  test('Bearer dikirim untuk profil, detail, foto, dan multipart', () async {
    final api = RakRapiApi()..token = tokenUji;
    final jalur = <String>[];
    await http.runWithClient(
      () async {
        await api.profil();
        await api.detail(2);
        expect(await api.foto(2), [1, 2, 3]);
        await api.simpanBarang({
          'nama': 'Fixture',
        }, gambar: Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]));
      },
      () => MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer $tokenUji');
        jalur.add(request.url.path);
        if (request.url.path.endsWith('/foto')) {
          return http.Response.bytes([1, 2, 3], 200);
        }
        if (request.method == 'POST') {
          expect(
            request.headers['content-type'],
            startsWith('multipart/form-data'),
          );
          return json({
            'data': {'id': 9},
          }, 201);
        }
        return json({
          'user': {'id': 1},
          'data': {'id': 2},
        });
      }),
    );
    expect(jalur, [
      '/api/auth/me',
      '/api/barang/2',
      '/api/barang/2/foto',
      '/api/barang',
    ]);
  });

  test(
    '401 login publik tidak menghapus sesi; 403 dan jaringan juga tidak',
    () async {
      final api = RakRapiApi()..token = tokenUji;
      var berakhir = 0;
      api.saatSesiHabis = () => berakhir++;
      await http.runWithClient(
        () async {
          await expectLater(
            api.masuk('uji@example.test', 'sandi-fixture'),
            throwsA(isA<KesalahanApi>()),
          );
        },
        () => MockClient((request) async {
          expect(request.headers.containsKey('Authorization'), isFalse);
          if (request.url.path.endsWith('/health')) {
            return json({'status': 'ok', 'nama_database': 'rakrapi'});
          }
          return json({'pesan': 'Email atau sandi salah.'}, 401);
        }),
      );
      for (final hasil in [403, 503, 'jaringan', 'timeout']) {
        await http.runWithClient(
          () async {
            await expectLater(api.profil(), throwsA(isA<KesalahanApi>()));
          },
          () => MockClient((_) async {
            if (hasil == 'jaringan') throw http.ClientException('offline');
            if (hasil == 'timeout') throw TimeoutException('uji');
            return json({'pesan': 'Tidak dapat diakses.'}, hasil as int);
          }),
        );
      }
      expect(berakhir, 0);
      expect(api.token, tokenUji);
    },
  );

  test('401 dari permintaan sesi lama tidak mengeluarkan sesi baru', () async {
    final api = RakRapiApi()..token = tokenUji;
    var berakhir = 0;
    api.saatSesiHabis = () => berakhir++;
    await http.runWithClient(
      () async {
        await expectLater(api.profil(), throwsA(isA<KesalahanApi>()));
      },
      () => MockClient((_) async {
        api.token = 'sesi-baru-fixture';
        return json({'pesan': 'Silakan masuk kembali.'}, 401);
      }),
    );
    expect(api.token, 'sesi-baru-fixture');
    expect(berakhir, 0);
  });

  for (final role in ['pemilik', 'pegawai', 'warga']) {
    testWidgets('Sesi $role dipulihkan lewat /me; keluar menghapus token', (
      tester,
    ) async {
      await penyimpanan.setString('token', tokenUji);
      var profilDibaca = 0;
      final api = RakRapiApi();
      await http.runWithClient(
        () async {
          await tester.pumpWidget(RakRapi(api: api));
          await tester.pumpAndSettle();
          expect(profilDibaca, 1);
          expect(find.text('Katalog Barang'), findsOneWidget);
          expect(
            find.text('Tambah barang'),
            role == 'warga' ? findsNothing : findsOneWidget,
          );
          expect(
            find.byTooltip('Menu pemilik'),
            role == 'pemilik' ? findsOneWidget : findsNothing,
          );
          await tester.tap(find.byTooltip('Keluar'));
          await tester.pumpAndSettle();
          expect(find.text('Masuk'), findsOneWidget);
          expect(find.text(pesanHabis), findsNothing);
          expect(await penyimpanan.getString('token'), isNull);
          expect(api.token, isNull);
        },
        () => MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer $tokenUji');
          if (request.url.path.endsWith('/auth/me')) {
            profilDibaca++;
            return json({
              'user': {
                'id': 1,
                'nama': 'Uji',
                'email': 'uji@example.test',
                'role': role,
              },
            });
          }
          return json({'data': []});
        }),
      );
    });
  }

  for (final saatMemulihkan in [true, false]) {
    testWidgets(
      '401 saat ${saatMemulihkan ? 'pemulihan' : 'foto'} membuka Masuk dengan pesan',
      (tester) async {
        await penyimpanan.setString('token', tokenUji);
        final api = RakRapiApi();
        await http.runWithClient(
          () async {
            await tester.pumpWidget(RakRapi(api: api));
            await tester.pumpAndSettle();
            if (!saatMemulihkan) {
              expect(find.text('Katalog Barang'), findsOneWidget);
              await expectLater(api.foto(2), throwsA(isA<KesalahanApi>()));
              await tester.pumpAndSettle();
            }
            expect(find.text('Masuk'), findsOneWidget);
            expect(find.text(pesanHabis), findsOneWidget);
            expect(await penyimpanan.getString('token'), isNull);
            expect(api.token, isNull);
          },
          () => MockClient((request) async {
            if (saatMemulihkan || request.url.path.endsWith('/foto')) {
              return json({'pesan': 'Silakan masuk kembali.'}, 401);
            }
            return json({
              'user': {'id': 1, 'nama': 'Uji', 'role': 'pegawai'},
              'data': [],
            });
          }),
        );
      },
    );
  }

  testWidgets(
    'Jaringan gagal saat /me mempertahankan token dan bisa dicoba ulang',
    (tester) async {
      await penyimpanan.setString('token', tokenUji);
      var offline = true;
      final api = RakRapiApi();
      await http.runWithClient(
        () async {
          await tester.pumpWidget(RakRapi(api: api));
          await tester.pumpAndSettle();
          expect(find.text('Coba lagi'), findsOneWidget);
          expect(await penyimpanan.getString('token'), tokenUji);
          expect(api.token, tokenUji);
          offline = false;
          await tester.tap(find.text('Coba lagi'));
          await tester.pumpAndSettle();
          expect(find.text('Katalog Barang'), findsOneWidget);
        },
        () => MockClient((_) async {
          if (offline) throw http.ClientException('offline');
          return json({
            'user': {'id': 1, 'nama': 'Uji', 'role': 'pegawai'},
            'data': [],
          });
        }),
      );
    },
  );
}
