import 'package:flutter/material.dart';

import 'api.dart';
import 'form_barang.dart' show dialogKategori;
import 'katalog.dart' show PesanGagal;
import 'theme/app_theme.dart';
import 'widgets/keadaan_kosong.dart';

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
    appBar: AppBar(
      title: const Text('Kelola kategori'),
      actions: [
        IconButton(
          tooltip: 'Muat ulang',
          onPressed: muatUlang,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: FilledButton.icon(
              onPressed: tambah,
              icon: const Icon(Icons.add),
              label: const Text('Tambah kategori'),
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
                  return const Center(
                    child: KeadaanKosong(
                      ikon: Icons.category_outlined,
                      judul: 'Belum ada kategori',
                      penjelasan: 'Tambahkan kategori untuk mengelompokkan produk toko.',
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  itemCount: daftar.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final k = daftar[i];
                    final jumlah = k['jumlah_produk'] ?? 0;
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: hijauLembut,
                          child: Icon(Icons.grid_view_rounded, color: hijauUtama, size: 20),
                        ),
                        title: Text(
                          k['nama'],
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '$jumlah produk',
                          style: const TextStyle(color: teksRedup),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => bukaDetail(k['id']),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class LayarKategoriPembeli extends StatefulWidget {
  const LayarKategoriPembeli({
    super.key,
    required this.api,
    required this.onPilihKategori,
  });
  final RakRapiApi api;
  final void Function(int kategoriId) onPilihKategori;

  @override
  State<LayarKategoriPembeli> createState() => _LayarKategoriPembeliState();
}

class _LayarKategoriPembeliState extends State<LayarKategoriPembeli> {
  late Future<List<Json>> _future = widget.api.kategori();

  void muat() {
    setState(() {
      _future = widget.api.kategori();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Kategori')),
    body: FutureBuilder<List<Json>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: PesanGagal(snap.error.toString(), ulangi: muat));
        }
        final daftar = snap.requireData;
        if (daftar.isEmpty) {
          return const Center(
            child: KeadaanKosong(
              ikon: Icons.grid_view_outlined,
              judul: 'Belum ada kategori',
              penjelasan: 'Kategori produk akan tampil setelah ditambahkan toko.',
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Pilih kebutuhan yang ingin Anda cari.',
              style: TextStyle(color: teksRedup),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: daftar.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.45,
              ),
              itemBuilder: (_, i) {
                final k = daftar[i];
                return Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () {
                      Navigator.pop(context);
                      widget.onPilihKategori(k['id'] as int);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.grid_view_rounded, color: hijauUtama, size: 22),
                          const SizedBox(height: 8),
                          Text(
                            k['nama'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${k['jumlah_produk'] ?? 0} produk',
                            style: const TextStyle(fontSize: 12, color: teksRedup),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
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
        content: const Text(
          'Kategori hanya dapat dihapus jika tidak lagi digunakan oleh produk.',
        ),
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
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Nama kategori', style: TextStyle(color: teksRedup)),
                      const SizedBox(height: 4),
                      Text(
                        kategori['nama'],
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: menghapus ? null : () => ubah(kategori),
                child: const Text('Ubah nama kategori'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: merahPeringatan,
                  side: const BorderSide(color: merahPeringatan),
                ),
                onPressed: menghapus ? null : () => hapus(kategori['nama']),
                child: Text(menghapus ? 'Menghapus…' : 'Hapus kategori'),
              ),
              if (pesan != null) PesanGagal(pesan!),
            ],
          );
        },
      ),
    ),
  );
}
