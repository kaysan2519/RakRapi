import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'api.dart';
import 'form_barang.dart';
import 'form_akun.dart';
import 'kategori.dart';

class PesanGagal extends StatelessWidget {
  const PesanGagal(this.pesan, {super.key, this.ulangi});
  final String pesan;
  final VoidCallback? ulangi;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          pesan,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        if (ulangi != null)
          TextButton(onPressed: ulangi, child: const Text('Coba lagi')),
      ],
    ),
  );
}

class DaftarBarang extends StatefulWidget {
  const DaftarBarang({
    super.key,
    required this.api,
    required this.pemilik,
    required this.keluar,
  });
  final RakRapiApi api;
  final bool pemilik;
  final VoidCallback keluar;
  @override
  State<DaftarBarang> createState() => _DaftarBarangState();
}

class _DaftarBarangState extends State<DaftarBarang> {
  late Future<List<Json>> daftar;
  @override
  void initState() {
    super.initState();
    daftar = widget.api.daftarBarang();
  }

  void muatUlang() {
    final permintaan = widget.api.daftarBarang();
    setState(() {
      daftar = permintaan;
    });
  }

  Future<void> bukaDetail(int id) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            DetailBarang(api: widget.api, id: id, pemilik: widget.pemilik),
      ),
    );
    if (mounted) muatUlang();
  }

  Future<void> tambahBarang() async {
    final id = await Navigator.push<int>(
      context,
      MaterialPageRoute(builder: (_) => FormBarang(api: widget.api)),
    );
    if (mounted && id != null) await bukaDetail(id);
  }

  Future<void> tambahKategori() async {
    final kategori = await dialogKategori(context, widget.api);
    if (mounted && kategori != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kategori ${kategori['nama']} disimpan.')),
      );
    }
  }

  Future<void> tambahPegawai() async {
    final email = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            FormAkun(judul: 'Tambah pegawai', simpan: widget.api.tambahPegawai),
      ),
    );
    if (mounted && email != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Akun pegawai $email dibuat.')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Daftar barang'),
      actions: [
        if (widget.pemilik)
          PopupMenuButton<String>(
            tooltip: 'Menu pemilik',
            onSelected: (pilihan) async {
              if (pilihan == 'pegawai') {
                await tambahPegawai();
              } else if (pilihan == 'kategori') {
                await Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DaftarKategori(api: widget.api),
                  ),
                );
                if (mounted) muatUlang();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'kategori',
                child: Text('Kelola kategori'),
              ),
              const PopupMenuItem(
                value: 'pegawai',
                child: Text('Tambah pegawai'),
              ),
            ],
          ),
        TextButton(onPressed: widget.keluar, child: const Text('Keluar')),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          if (widget.pemilik)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: tambahKategori,
                    child: const Text('Tambah kategori'),
                  ),
                  FilledButton(
                    onPressed: tambahBarang,
                    child: const Text('Tambah barang'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: FutureBuilder<List<Json>>(
              future: daftar,
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
                final barang = hasil.requireData;
                if (barang.isEmpty) {
                  return const Center(child: Text('Belum ada barang.'));
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    muatUlang();
                    try {
                      await daftar;
                    } on KesalahanApi {
                      // FutureBuilder menampilkan pesan API dan tombol Coba lagi.
                    }
                  },
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: barang.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final b = barang[i];
                      return ListTile(
                        title: Text(b['nama']),
                        subtitle: Text(
                          '${hargaRupiah(b['harga_rupiah'])} · ${stokTampil(b)}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => bukaDetail(b['id']),
                      );
                    },
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

class DetailBarang extends StatefulWidget {
  const DetailBarang({
    super.key,
    required this.api,
    required this.id,
    required this.pemilik,
  });
  final RakRapiApi api;
  final int id;
  final bool pemilik;
  @override
  State<DetailBarang> createState() => _DetailBarangState();
}

class _DetailBarangState extends State<DetailBarang> {
  late Future<Json> detail;
  bool menghapus = false;
  @override
  void initState() {
    super.initState();
    muat();
  }

  void muat() {
    detail = widget.api.detail(widget.id);
    // FutureBuilder foto dipasang sesudah detail tersedia.
  }

  Future<void> ubah(Json barang) async {
    final id = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => FormBarang(api: widget.api, barang: barang),
      ),
    );
    if (mounted && id != null) setState(muat);
  }

  Future<void> hapus(Json barang) async {
    if (menghapus) return;
    final yakin = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus “${barang['nama']}”?'),
        content: const Text('Barang ini akan dihapus dari daftar.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus barang'),
          ),
        ],
      ),
    );
    if (!mounted || yakin != true) return;
    setState(() => menghapus = true);
    try {
      await widget.api.hapus(widget.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => menghapus = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Detail barang')),
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
              ulangi: () => setState(muat),
            ),
          );
        }
        final b = hasil.requireData;
        final teks = Theme.of(context).textTheme;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              b['nama'],
              style: teks.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: ukuran('Harga', hargaRupiah(b['harga_rupiah'])),
                ),
                Expanded(child: ukuran('Stok', stokTampil(b))),
              ],
            ),
            const SizedBox(height: 20),
            FotoPrivat(key: ObjectKey(b), api: widget.api, id: widget.id),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Kategori'),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(b['nama_kategori'], textAlign: TextAlign.end),
                ),
              ],
            ),
            const Divider(),
            if (widget.pemilik) ...[
              FilledButton(
                onPressed: menghapus ? null : () => ubah(b),
                child: const Text('Ubah barang'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade800,
                  side: BorderSide(color: Colors.red.shade800),
                ),
                onPressed: menghapus ? null : () => hapus(b),
                child: const Text('Hapus barang'),
              ),
            ],
          ],
        );
      },
    ),
  );
  Widget ukuran(String label, String nilai) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label),
      Text(
        nilai,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
    ],
  );
}

class FotoPrivat extends StatefulWidget {
  const FotoPrivat({super.key, required this.api, required this.id});
  final RakRapiApi api;
  final int id;
  @override
  State<FotoPrivat> createState() => _FotoPrivatState();
}

class _FotoPrivatState extends State<FotoPrivat> {
  late Future<Uint8List> foto;
  @override
  void initState() {
    super.initState();
    foto = widget.api.foto(widget.id);
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 220,
    child: FutureBuilder<Uint8List>(
      future: foto,
      builder: (context, hasil) {
        if (hasil.hasError) {
          return PesanGagal(
            hasil.error.toString(),
            ulangi: () {
              final permintaan = widget.api.foto(widget.id);
              setState(() {
                foto = permintaan;
              });
            },
          );
        }
        if (!hasil.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            hasil.requireData,
            fit: BoxFit.contain,
            semanticLabel: 'Foto barang',
            errorBuilder: (_, _, _) => const Text('Foto tidak dapat dibaca.'),
          ),
        );
      },
    ),
  );
}
