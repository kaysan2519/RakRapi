import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'api.dart';
import 'form_barang.dart';
import 'keranjang.dart';
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
          textAlign: TextAlign.center,
          style: const TextStyle(color: merahPeringatan),
        ),
        if (ulangi != null)
          TextButton.icon(
            onPressed: ulangi,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Coba lagi'),
          ),
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
    this.kategoriAwalId,
    this.fokusCari = false,
    this.onKeranjangBerubah,
    this.onBukaKeranjang,
  });
  final RakRapiApi api;
  final String role;
  bool get pemilik => role == 'pemilik';
  bool get bolehMenulis => pemilik || role == 'pegawai';
  final VoidCallback keluar;
  final Keranjang? keranjang;
  final int? kategoriAwalId;
  final bool fokusCari;
  final VoidCallback? onKeranjangBerubah;
  final VoidCallback? onBukaKeranjang;

  @override
  State<DaftarBarang> createState() => _DaftarBarangState();
}

class _DaftarBarangState extends State<DaftarBarang> {
  final _cariCtrl = TextEditingController();
  late Future<(List<Json>, List<Json>)> _dataFuture;
  int? kategoriTerpilih;
  String kueri = '';

  @override
  void initState() {
    super.initState();
    kategoriTerpilih = widget.kategoriAwalId;
    _dataFuture = _muatData();
  }

  @override
  void didUpdateWidget(covariant DaftarBarang oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kategoriAwalId != widget.kategoriAwalId &&
        widget.kategoriAwalId != null) {
      setState(() => kategoriTerpilih = widget.kategoriAwalId);
    }
  }

  @override
  void dispose() {
    _cariCtrl.dispose();
    super.dispose();
  }

  Future<(List<Json>, List<Json>)> _muatData() async {
    final hasil = await Future.wait([
      widget.api.daftarBarang(),
      widget.api.kategori(),
    ]);
    return (hasil[0], hasil[1]);
  }

  void muatUlang() {
    setState(() {
      _dataFuture = _muatData();
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
          onKeranjangBerubah: widget.onKeranjangBerubah,
        ),
      ),
    );
    if (mounted) {
      widget.onKeranjangBerubah?.call();
      muatUlang();
    }
  }

  Future<void> tambahBarang() async {
    final id = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            FormBarang(api: widget.api, bolehTambahKategori: widget.pemilik),
      ),
    );
    if (mounted && id != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Produk berhasil disimpan.')));
      muatUlang();
    }
  }

  void tambahCepat(Json b) {
    final keranjang = widget.keranjang;
    if (keranjang == null) return;
    final stokMaks = jumlahPerseribu(b['stok'].toString(), b['satuan']) ?? 0;
    if (stokMaks <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Stok produk sedang habis.')));
      return;
    }
    final lama = keranjang.item[b['id']];
    final saatIni = lama?.jumlah ?? 0;
    final berikutnya = saatIni + 1000;
    if (berikutnya > stokMaks) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jumlah melebihi stok tersedia.')),
      );
      return;
    }
    keranjang.atur(b, berikutnya);
    widget.onKeranjangBerubah?.call();
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${b['nama']} ditambahkan ke keranjang.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final jumlahKeranjang = widget.keranjang?.totalItemJenis ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.bolehMenulis ? 'Produk & stok' : 'Katalog produk'),
        actions: [
          if (widget.keranjang != null && widget.onBukaKeranjang != null)
            IconButton(
              tooltip: 'Keranjang',
              onPressed: widget.onBukaKeranjang,
              icon: Badge(
                isLabelVisible: jumlahKeranjang > 0,
                label: Text('$jumlahKeranjang'),
                child: const Icon(Icons.shopping_bag_outlined),
              ),
            ),
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: muatUlang,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<(List<Json>, List<Json>)>(
          future: _dataFuture,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(
                child: PesanGagal(snap.error.toString(), ulangi: muatUlang),
              );
            }
            final (semuaBarang, semuaKategori) = snap.requireData;
            final kata = kueri.trim().toLowerCase();
            final terlihat = semuaBarang.where((b) {
              final cocokKat =
                  kategoriTerpilih == null ||
                  b['kategori_id'] == kategoriTerpilih;
              final cocokCari =
                  kata.isEmpty ||
                  b['nama'].toString().toLowerCase().contains(kata) ||
                  (b['nama_kategori'] ?? '').toString().toLowerCase().contains(
                    kata,
                  );
              return cocokKat && cocokCari;
            }).toList();

            return RefreshIndicator(
              onRefresh: () async {
                muatUlang();
                try {
                  await _dataFuture;
                } on KesalahanApi {
                  // Ditampilkan lewat PesanGagal.
                }
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  if (widget.bolehMenulis) ...[
                    FilledButton.icon(
                      onPressed: tambahBarang,
                      icon: const Icon(Icons.add),
                      label: const Text('Tambah produk'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _cariCtrl,
                    autofocus: widget.fokusCari,
                    onChanged: (v) => setState(() => kueri = v),
                    decoration: InputDecoration(
                      hintText: 'Cari beras, telur, minyak...',
                      prefixIcon: const Icon(Icons.search, color: teksRedup),
                      suffixIcon: kueri.isNotEmpty
                          ? IconButton(
                              tooltip: 'Hapus pencarian',
                              onPressed: () {
                                _cariCtrl.clear();
                                setState(() => kueri = '');
                              },
                              icon: const Icon(Icons.close, size: 18),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _chipKategori(null, 'Semua'),
                        for (final k in semuaKategori)
                          _chipKategori(k['id'] as int, k['nama'].toString()),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        kategoriTerpilih == null
                            ? 'Semua produk (${terlihat.length})'
                            : '${semuaKategori.firstWhere((k) => k['id'] == kategoriTerpilih, orElse: () => {'nama': 'Kategori'})['nama']} (${terlihat.length})',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      if (widget.keranjang != null &&
                          widget.onBukaKeranjang != null)
                        TextButton(
                          onPressed: widget.onBukaKeranjang,
                          child: Text(
                            'Keranjang (${widget.keranjang!.totalItemJenis})',
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (terlihat.isEmpty)
                    KeadaanKosong(
                      ikon: Icons.inventory_2_outlined,
                      judul: semuaBarang.isEmpty
                          ? 'Belum ada produk'
                          : 'Produk tidak ditemukan',
                      penjelasan: semuaBarang.isEmpty
                          ? 'Produk yang ditambahkan toko akan muncul di sini.'
                          : 'Coba ubah kata kunci pencarian atau pilih kategori lain.',
                    )
                  else
                    LayoutBuilder(
                      builder: (context, batas) {
                        final kolom = batas.maxWidth < 300
                            ? 1
                            : (batas.maxWidth / 172).floor().clamp(2, 4);
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: terlihat.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: kolom,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                mainAxisExtent: 268,
                              ),
                          itemBuilder: (_, i) => _kartuProduk(terlihat[i]),
                        );
                      },
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _chipKategori(int? id, String nama) {
    final aktif = kategoriTerpilih == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(nama),
        selected: aktif,
        showCheckmark: false,
        labelStyle: TextStyle(
          color: aktif ? Colors.white : hijauTua,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        onSelected: (_) => setState(() => kategoriTerpilih = id),
      ),
    );
  }

  Widget _kartuProduk(Json b) {
    final stokAngka = double.tryParse(b['stok'].toString()) ?? 0;
    final habis = stokAngka <= 0;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => bukaDetail(b['id'] as int),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    FotoUrlPrivat(
                      key: ValueKey('barang-${b['id']}'),
                      api: widget.api,
                      fotoUrl:
                          (b['foto_url'] ?? '/api/barang/${b['id']}/foto')
                              .toString(),
                      tinggi: null,
                      fit: BoxFit.contain,
                      radius: 12,
                    ),
                    if (habis)
                      Positioned(
                        left: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: merahPeringatan,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Habis',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                (b['nama_kategori'] ?? '').toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: teksRedup),
              ),
              const SizedBox(height: 2),
              Text(
                b['nama'].toString(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                hargaRupiah(b['harga_rupiah']),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: hijauUtama,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      habis ? 'Stok habis' : 'Stok ${stokTampil(b)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: habis ? merahPeringatan : teksRedup,
                        fontWeight: habis ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(32, 32),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: widget.role == 'warga'
                          ? (habis ? null : () => tambahCepat(b))
                          : () => bukaDetail(b['id'] as int),
                      child: Icon(
                        widget.role == 'warga'
                            ? Icons.add
                            : Icons.edit_outlined,
                        size: 16,
                      ),
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
}

class DetailBarang extends StatefulWidget {
  const DetailBarang({
    super.key,
    required this.api,
    required this.id,
    required this.role,
    this.keranjang,
    this.onKeranjangBerubah,
  });
  final RakRapiApi api;
  final int id;
  final String role;
  final Keranjang? keranjang;
  final VoidCallback? onKeranjangBerubah;

  @override
  State<DetailBarang> createState() => _DetailBarangState();
}

class _DetailBarangState extends State<DetailBarang> {
  late Future<Json> detail;
  bool menghapus = false;
  final jumlah = TextEditingController(text: '1');
  final formJumlah = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    muat();
  }

  @override
  void dispose() {
    jumlah.dispose();
    super.dispose();
  }

  void muat() {
    detail = widget.api.detail(widget.id);
  }

  void tambahKeKeranjang(Json b) {
    if (!formJumlah.currentState!.validate()) return;
    final keranjang = widget.keranjang!;
    final stokMaks = jumlahPerseribu(b['stok'].toString(), b['satuan']) ?? 0;
    final lama = keranjang.item[b['id']];
    final satuanSama = lama?.barang['satuan'] == b['satuan'];
    final tambahan = jumlahPerseribu(jumlah.text, b['satuan'])!;
    final total = tambahan + (satuanSama ? lama!.jumlah : 0);
    if (stokMaks <= 0 || total > stokMaks) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Jumlah melebihi stok tersedia (${stokTampil(b)}).'),
        ),
      );
      return;
    }
    keranjang.atur(b, total);
    widget.onKeranjangBerubah?.call();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${b['nama']} ditambahkan ke keranjang.')),
    );
    Navigator.pop(context);
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
        content: const Text(
          'Produk ini akan dihapus dari katalog. Riwayat pesanan lama tetap aman.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: merahPeringatan),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus produk'),
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
    appBar: AppBar(title: const Text('Detail produk')),
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
        final stokAngka = double.tryParse(b['stok'].toString()) ?? 0;
        final habis = stokAngka <= 0;
        final deskripsi = (b['deskripsi'] ?? '').toString().trim();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FotoUrlPrivat(
              key: ObjectKey(b),
              api: widget.api,
              fotoUrl:
                  (b['foto_url'] ?? '/api/barang/${widget.id}/foto').toString(),
              tinggi: 240,
              fit: BoxFit.contain,
              radius: 18,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                BadgeLabel(b['nama_kategori'].toString()),
                BadgeLabel(
                  habis ? 'Stok habis' : 'Tersedia · ${stokTampil(b)}',
                  latar: habis ? latarPeringatan : hijauLembut,
                  warnaTeks: habis ? merahPeringatan : hijauUtama,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              b['nama'].toString(),
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              '${hargaRupiah(b['harga_rupiah'])} / ${b['satuan']}',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: hijauUtama,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              deskripsi.isNotEmpty
                  ? deskripsi
                  : 'Produk kebutuhan harian tersedia di Toko Sembako RakRapi.',
              style: const TextStyle(color: teksRedup, height: 1.5),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: hijauLembut,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(Icons.storefront_outlined, color: hijauUtama, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Ambil di kasir · Pesanan diambil langsung di kasir toko setelah status Siap diambil.',
                      style: TextStyle(fontSize: 12, color: hijauTua),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (widget.role == 'warga' && widget.keranjang != null) ...[
              if (!habis) ...[
                Form(
                  key: formJumlah,
                  child: IsianJumlah(controller: jumlah, satuan: b['satuan']),
                ),
                const SizedBox(height: 14),
              ],
              FilledButton.icon(
                onPressed: habis ? null : () => tambahKeKeranjang(b),
                icon: const Icon(Icons.add_shopping_cart),
                label: Text(
                  habis ? 'Stok sedang habis' : 'Tambah ke keranjang',
                ),
              ),
            ],
            if (widget.role == 'pemilik' || widget.role == 'pegawai')
              FilledButton.icon(
                onPressed: menghapus ? null : () => ubah(b),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit produk & stok'),
              ),
            if (widget.role == 'pemilik') ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: merahPeringatan,
                  side: const BorderSide(color: merahPeringatan),
                ),
                onPressed: menghapus ? null : () => hapus(b),
                icon: const Icon(Icons.delete_outline),
                label: Text(menghapus ? 'Menghapus…' : 'Hapus produk'),
              ),
            ],
          ],
        );
      },
    ),
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
    height: widget.mini ? 64 : 200,
    child: FutureBuilder<Uint8List>(
      future: foto,
      builder: (context, hasil) {
        if (hasil.hasError) {
          if (widget.mini) return const Icon(Icons.broken_image_outlined);
          return PesanGagal(
            hasil.error.toString(),
            ulangi: () {
              widget.api.hapusCacheFoto('/api/barang/${widget.id}/foto');
              final permintaan = widget.api.foto(widget.id);
              setState(() => foto = permintaan);
            },
          );
        }
        if (!hasil.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
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
