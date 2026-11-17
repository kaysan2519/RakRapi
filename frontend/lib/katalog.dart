import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'api.dart';
import 'form_barang.dart';
import 'form_akun.dart';
import 'kategori.dart';
import 'lowongan.dart';
import 'keranjang.dart';
import 'pesanan.dart';

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
    required this.role,
    required this.keluar,
    this.keranjang,
  });
  final RakRapiApi api;
  final String role;
  bool get pemilik => role == 'pemilik';
  bool get bolehMenulis => pemilik || role == 'pegawai';
  final VoidCallback keluar;
  final Keranjang? keranjang;
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
        builder: (_) => DetailBarang(
          api: widget.api,
          id: id,
          role: widget.role,
          keranjang: widget.keranjang,
        ),
      ),
    );
    if (mounted) muatUlang();
  }

  Future<void> tambahBarang() async {
    final id = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            FormBarang(api: widget.api, bolehTambahKategori: widget.pemilik),
      ),
    );
    if (mounted && id != null) await bukaDetail(id);
  }

  Future<void> bukaKeranjang() async {
    final id = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            LayarKeranjang(api: widget.api, keranjang: widget.keranjang!),
      ),
    );
    if (!mounted) return;
    setState(() {});
    if (id != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DetailPesanan(api: widget.api, id: id, toko: false),
        ),
      );
    }
    if (mounted) muatUlang();
  }

  Future<void> bukaPesanan() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            DaftarPesanan(api: widget.api, toko: widget.bolehMenulis),
      ),
    );
    if (mounted) muatUlang();
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
        IconButton(
          tooltip: widget.bolehMenulis ? 'Pesanan masuk' : 'Pesanan saya',
          onPressed: bukaPesanan,
          icon: const Icon(Icons.receipt_long_outlined),
        ),
        if (widget.keranjang != null)
          IconButton(
            tooltip: 'Keranjang',
            onPressed: bukaKeranjang,
            icon: Semantics(
              label: 'Keranjang, ${widget.keranjang!.item.length} jenis barang',
              excludeSemantics: true,
              child: Badge(
                label: Text('${widget.keranjang!.item.length}'),
                child: const Icon(Icons.shopping_cart_outlined),
              ),
            ),
          ),
        if (widget.pemilik)
          PopupMenuButton<String>(
            tooltip: 'Menu pemilik',
            onSelected: (pilihan) async {
              if (pilihan == 'pegawai') {
                await tambahPegawai();
              } else if (pilihan == 'lowongan') {
                await Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        LayarLowongan(api: widget.api, pemilik: true),
                  ),
                );
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
                value: 'lowongan',
                child: Text('Kelola lowongan'),
              ),
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
          if (widget.bolehMenulis)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  if (widget.pemilik)
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
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: SizedBox.square(
                          dimension: 64,
                          child: FotoPrivat(
                            key: ObjectKey(b),
                            api: widget.api,
                            id: b['id'],
                            mini: true,
                          ),
                        ),
                        title: Text(b['nama']),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${hargaRupiah(b['harga_rupiah'])} / ${b['satuan']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text('Stok ${stokTampil(b)}'),
                          ],
                        ),
                        isThreeLine: true,
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
    required this.role,
    this.keranjang,
  });
  final RakRapiApi api;
  final int id;
  final String role;
  final Keranjang? keranjang;
  @override
  State<DetailBarang> createState() => _DetailBarangState();
}

class _DetailBarangState extends State<DetailBarang> {
  late Future<Json> detail;
  bool menghapus = false;
  final jumlah = TextEditingController(text: '1');
  final formJumlah = GlobalKey<FormState>();

  @override
  void dispose() {
    jumlah.dispose();
    super.dispose();
  }

  void tambahKeKeranjang(Json b) {
    if (!formJumlah.currentState!.validate()) return;
    final keranjang = widget.keranjang!;
    final lama = keranjang.item[b['id']];
    final satuanSama = lama?.barang['satuan'] == b['satuan'];
    final total =
        jumlahPerseribu(jumlah.text, b['satuan'])! +
        (satuanSama ? lama!.jumlah : 0);
    if (total > 999999999999) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jumlah melebihi batas per barang.')),
      );
      return;
    }
    keranjang.atur(b, total);
    Navigator.pop(context);
  }

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
        builder: (_) => FormBarang(
          api: widget.api,
          barang: barang,
          bolehTambahKategori: widget.role == 'pemilik',
        ),
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
            if (widget.role == 'warga' && widget.keranjang != null) ...[
              Form(
                key: formJumlah,
                child: IsianJumlah(controller: jumlah, satuan: b['satuan']),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => tambahKeKeranjang(b),
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('Tambah ke keranjang'),
              ),
            ],
            if (widget.role == 'pemilik' || widget.role == 'pegawai')
              FilledButton(
                onPressed: menghapus ? null : () => ubah(b),
                child: const Text('Ubah barang'),
              ),
            if (widget.role == 'pemilik') ...[
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
  const FotoPrivat({
    super.key,
    required this.api,
    required this.id,
    this.mini = false,
  });
  final RakRapiApi api;
  final int id;
  final bool mini;
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
          if (widget.mini) return const Icon(Icons.broken_image_outlined);
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
            cacheWidth: widget.mini ? 128 : null,
            fit: BoxFit.contain,
            semanticLabel: 'Foto barang',
            errorBuilder: (_, _, _) => widget.mini
                ? const Icon(Icons.broken_image_outlined)
                : const Text('Foto tidak dapat dibaca.'),
          ),
        );
      },
    ),
  );
}
