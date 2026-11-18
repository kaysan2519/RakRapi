import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'api.dart';
import 'form_barang.dart';
import 'form_akun.dart';
import 'kategori.dart';
import 'lowongan.dart';
import 'keranjang.dart';
import 'pesanan.dart';
import 'theme/app_theme.dart';
import 'widgets/keadaan_kosong.dart';

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
  int? kategoriTerpilih;
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
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TOKO SEMBAKO RAKRAPI',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const Text(
            'Katalog Barang',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
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
        IconButton(
          tooltip: 'Keluar',
          onPressed: widget.keluar,
          icon: const Icon(Icons.logout_outlined),
        ),
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
                // Warga belum boleh meminta endpoint pengelolaan kategori.
                // Chip berasal dari kategori barang yang dikirim API katalog.
                final kategori = <int, String>{
                  for (final b in barang)
                    b['kategori_id'] as int: b['nama_kategori'] as String,
                };
                final aktif = kategori.containsKey(kategoriTerpilih)
                    ? kategoriTerpilih
                    : null;
                final terlihat = barang
                    .where((b) => aktif == null || b['kategori_id'] == aktif)
                    .toList();
                return RefreshIndicator(
                  onRefresh: () async {
                    muatUlang();
                    try {
                      await daftar;
                    } on KesalahanApi {
                      // FutureBuilder menyediakan tombol Coba lagi.
                    }
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: hijauUtama,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Katalog Toko RakRapi',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${barang.length} barang • ${kategori.length} kategori dalam katalog',
                              style: const TextStyle(color: Color(0xFFDCE8DF)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Kategori',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            chipKategori(null, 'Semua', aktif),
                            for (final k in kategori.entries)
                              chipKategori(k.key, k.value, aktif),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (barang.isEmpty)
                        const KeadaanKosong(
                          ikon: Icons.inventory_2_outlined,
                          judul: 'Belum ada barang.',
                          penjelasan:
                              'Barang yang ditambahkan oleh toko akan tampil di sini. Tarik ke bawah untuk memuat ulang.',
                        )
                      else
                        LayoutBuilder(
                          builder: (context, batas) {
                            // Lebar kartu tetap nyaman pada HP maupun tablet.
                            final kolom = batas.maxWidth < 300
                                ? 1
                                : (batas.maxWidth / 180).floor().clamp(2, 5);
                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: terlihat.length,
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: kolom,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    mainAxisExtent:
                                        300 +
                                        (MediaQuery.textScalerOf(
                                              context,
                                            ).scale(40) -
                                            40),
                                  ),
                              itemBuilder: (_, i) => kartuBarang(terlihat[i]),
                            );
                          },
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );

  Widget chipKategori(int? id, String nama, int? aktif) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(nama),
      selected: aktif == id,
      showCheckmark: false,
      labelStyle: TextStyle(color: aktif == id ? Colors.white : hijauUtama),
      onSelected: (_) => setState(() => kategoriTerpilih = id),
    ),
  );

  Widget kartuBarang(Json barang) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => bukaDetail(barang['id']),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: latarAplikasi,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: FotoPrivat(
                      key: ObjectKey(barang),
                      api: widget.api,
                      id: barang['id'],
                    ),
                  ),
                  Positioned(
                    left: 6,
                    right: 6,
                    bottom: 6,
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: hijauUtama,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Stok: ${stokTampil(barang)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              barang['nama'],
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '/ ${barang['satuan']}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    hargaRupiah(barang['harga_rupiah']),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton.filled(
                  tooltip: widget.role == 'warga'
                      ? 'Pilih jumlah ${barang['nama']}'
                      : 'Detail ${barang['nama']}',
                  onPressed: () => bukaDetail(barang['id']),
                  icon: Icon(
                    widget.role == 'warga' ? Icons.add : Icons.arrow_forward,
                    size: 19,
                  ),
                ),
              ],
            ),
          ],
        ),
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
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: ColoredBox(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: FotoPrivat(
                    key: ObjectKey(b),
                    api: widget.api,
                    id: widget.id,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                label: Text(b['nama_kategori']),
                backgroundColor: hijauLembut,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              b['nama'],
              style: teks.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                ukuran(
                  'Harga per ${b['satuan']}',
                  hargaRupiah(b['harga_rupiah']),
                ),
                ukuran('Stok', stokTampil(b)),
              ],
            ),
            const SizedBox(height: 28),
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
            cacheWidth: widget.mini ? 192 : 800,
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
