import 'package:flutter/material.dart';
import 'api.dart';
import 'katalog.dart';

class LayarLowongan extends StatefulWidget {
  const LayarLowongan({super.key, required this.api, required this.pemilik});
  final RakRapiApi api;
  final bool pemilik;

  @override
  State<LayarLowongan> createState() => _LayarLowonganState();
}

class _LayarLowonganState extends State<LayarLowongan> {
  final judul = TextEditingController();
  late Future<List<Json>> daftar;
  bool menyimpan = false;
  String? pesan;

  @override
  void initState() {
    super.initState();
    daftar = widget.api.lowongan();
  }

  @override
  void dispose() {
    judul.dispose();
    super.dispose();
  }

  void muatUlang() {
    final permintaan = widget.api.lowongan();
    setState(() {
      daftar = permintaan;
    });
  }

  Future<void> simpan({int? idUntukDitutup}) async {
    if (menyimpan) return;
    final nama = judul.text.trim();
    if (idUntukDitutup == null && nama.isEmpty) {
      setState(() => pesan = 'Isi judul lowongan.');
      return;
    }
    setState(() {
      menyimpan = true;
      pesan = null;
    });
    try {
      if (idUntukDitutup == null) {
        await widget.api.bukaLowongan(nama);
        if (!mounted) return;
        judul.clear();
      } else {
        await widget.api.tutupLowongan(idUntukDitutup);
      }
      if (mounted) muatUlang();
    } catch (e) {
      if (mounted) setState(() => pesan = e.toString());
    } finally {
      if (mounted) setState(() => menyimpan = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.pemilik ? 'Kelola lowongan' : 'Lowongan aktif'),
      actions: [
        IconButton(
          tooltip: 'Muat ulang',
          onPressed: muatUlang,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.pemilik) ...[
            TextField(
              controller: judul,
              enabled: !menyimpan,
              maxLength: 150,
              decoration: const InputDecoration(labelText: 'Judul lowongan'),
            ),
            FilledButton(
              onPressed: menyimpan ? null : () => simpan(),
              child: const Text('Buka lowongan'),
            ),
            const SizedBox(height: 16),
          ],
          if (pesan != null) PesanGagal(pesan!),
          FutureBuilder<List<Json>>(
            future: daftar,
            builder: (context, hasil) {
              if (hasil.connectionState != ConnectionState.done) {
                return const LinearProgressIndicator();
              }
              if (hasil.hasError) {
                return PesanGagal(hasil.error.toString(), ulangi: muatUlang);
              }
              final lowongan = hasil.requireData;
              if (lowongan.isEmpty) {
                return Text(
                  widget.pemilik
                      ? 'Belum ada lowongan.'
                      : 'Belum ada lowongan aktif.',
                );
              }
              return Column(
                children: [
                  for (final l in lowongan)
                    ListTile(
                      title: Text(l['judul']),
                      subtitle: widget.pemilik
                          ? Text(l['aktif'] ? 'Aktif' : 'Ditutup')
                          : null,
                      trailing: widget.pemilik && l['aktif'] == true
                          ? TextButton(
                              onPressed: menyimpan
                                  ? null
                                  : () => simpan(idUntukDitutup: l['id']),
                              child: const Text('Tutup'),
                            )
                          : null,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    ),
  );
}
