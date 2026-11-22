import 'package:flutter/material.dart';

import 'api.dart';
import 'layanan_info.dart';

class LayarLowongan extends StatelessWidget {
  const LayarLowongan({
    super.key,
    required this.api,
    required this.pemilik,
    this.namaPengguna = '',
  });
  final RakRapiApi api;
  final bool pemilik;
  final String namaPengguna;

  @override
  Widget build(BuildContext context) => LayarLayananInfo(
    api: api,
    jenis: JenisLayanan.lowongan,
    pemilik: pemilik,
    namaPengguna: namaPengguna,
  );
}
