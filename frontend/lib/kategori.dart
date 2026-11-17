import 'package:flutter/material.dart';

import 'api.dart';
import 'form_barang.dart' show dialogKategori;
import 'katalog.dart' show PesanGagal;

class DaftarKategori extends StatefulWidget {
  const DaftarKategori({super.key, required this.api});
  final RakRapiApi api;

  @override
  State<DaftarKategori> createState() => _DaftarKategoriState();
}

class _DaftarKategoriState extends State<DaftarKategori> {
  late Future<List<Json>> kategori = widget.api.kategori();

  void muatUlang() {
    final permintaan = widget.api.kategori();
    setState(() {
      kategori = permintaan;
    });
  }

  Future<void> bukaDetail(int id) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => DetailKategori(api: widget.api, id: id),
      ),
    );
    if (mounted) muatUlang();
  }

  Future<void> tambah() async {
    final hasil = await dialogKategori(context, widget.api);
    if (mounted && hasil != null) {
      muatUlang();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kategori ${hasil['nama']} disimpan.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Kelola kategori')),
    body: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: tambah,
              child: const Text('Tambah kategori'),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Json>>(
              future: kategori,
              builder: (context, hasil) {
                if (hasil.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (hasil.hasError) {
                  return Center(
                    child: PesanGagal(
                      hasil.error.toString(),
                      ulangi: muatUlang,
                    ),
                  );
                }
                final daftar = hasil.requireData;
                if (daftar.isEmpty) {
                  return const Center(child: Text('Belum ada kategori.'));
                }
                return ListView.separated(
                  itemCount: daftar.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) => ListTile(
                    title: Text(daftar[i]['nama']),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => bukaDetail(daftar[i]['id']),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class DetailKategori extends StatefulWidget {
  const DetailKategori({super.key, required this.api, required this.id});
  final RakRapiApi api;
  final int id;

  @override
  State<DetailKategori> createState() => _DetailKategoriState();
}

class _DetailKategoriState extends State<DetailKategori> {
  late Future<Json> detail = widget.api.detailKategori(widget.id);
  bool menghapus = false;
  String? pesan;

  Future<void> ubah(Json kategori) async {
    final hasil = await dialogKategori(context, widget.api, kategori: kategori);
    if (!mounted || hasil == null) return;
    setState(() {
      detail = Future.value(hasil);
      pesan = null;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Perubahan disimpan.')));
  }

  Future<void> hapus(String nama) async {
    if (menghapus) return;
    final yakin = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus “$nama”?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (!mounted || yakin != true) return;
    setState(() {
      menghapus = true;
      pesan = null;
    });
    try {
      await widget.api.hapusKategori(widget.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Kategori $nama dihapus.')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          menghapus = false;
          pesan = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !menghapus,
    child: Scaffold(
      appBar: AppBar(title: const Text('Detail kategori')),
      body: FutureBuilder<Json>(
        future: detail,
        builder: (context, hasil) {
          if (hasil.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (hasil.hasError) {
            return Center(
              child: PesanGagal(
                hasil.error.toString(),
                ulangi: () {
                  final permintaan = widget.api.detailKategori(widget.id);
                  setState(() {
                    detail = permintaan;
                  });
                },
              ),
            );
          }
          final kategori = hasil.requireData;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                kategori['nama'],
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: menghapus ? null : () => ubah(kategori),
                child: const Text('Ubah'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade800,
                ),
                onPressed: menghapus ? null : () => hapus(kategori['nama']),
                child: Text(menghapus ? 'Menghapus…' : 'Hapus'),
              ),
              if (pesan != null) PesanGagal(pesan!),
            ],
          );
        },
      ),
    ),
  );
}
