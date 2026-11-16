import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rakrapi/api.dart';
import 'package:rakrapi/form_barang.dart';

class ApiFormUji extends RakRapiApi {
  final jawaban = Completer<int>();
  int kiriman = 0;
  Map<String, String>? isian;
  Uint8List? unggahan;

  @override
  Future<List<Json>> kategori() async => [
    {'id': 1, 'nama': 'Kategori uji'},
  ];

  @override
  Future<Uint8List> foto(int id) async => base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/2XkAAAAASUVORK5CYII=',
  );

  @override
  Future<int> simpanBarang(
    Map<String, String> data, {
    int? id,
    Uint8List? gambar,
  }) {
    kiriman++;
    isian = data;
    unggahan = gambar;
    return jawaban.future;
  }
}

void main() {
  testWidgets(
    'Simpan dua kali hanya mengirim sekali dan isian bertahan saat gagal',
    (tester) async {
      final api = ApiFormUji();
      tester.view.physicalSize = const Size(1080, 2100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: FormBarang(
            api: api,
            barang: const {
              'id': 1,
              'kategori_id': 1,
              'nama': 'Barang uji formulir',
              'harga_rupiah': 2500,
              'stok': '3.000',
              'satuan': 'botol',
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final harga = find.widgetWithText(TextFormField, 'Harga per satuan');
      await tester.enterText(harga, '4500');
      final simpan = find.widgetWithText(FilledButton, 'Simpan');
      await tester.ensureVisible(simpan);
      await tester.tap(simpan);
      await tester.tap(simpan);
      await tester.pump();
      expect(api.kiriman, 1);
      expect(api.isian?['harga_rupiah'], '4500');
      expect(api.unggahan, isNull);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Menyimpan…'),
            )
            .onPressed,
        isNull,
      );

      api.jawaban.completeError(
        const KesalahanApi('Kategori tidak ditemukan.'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Kategori tidak ditemukan.'), findsOneWidget);
      expect(tester.widget<TextFormField>(harga).controller!.text, '4500');
      expect(tester.widget<FilledButton>(simpan).onPressed, isNotNull);
    },
  );
}
