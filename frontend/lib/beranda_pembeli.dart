import 'package:flutter/material.dart';

import 'api.dart';
import 'katalog.dart';
import 'kategori.dart';
import 'keranjang.dart';
import 'layanan_info.dart';
import 'pengelolaan_toko.dart';
import 'theme/app_theme.dart';

class BerandaPembeliTab extends StatefulWidget {
  const BerandaPembeliTab({
    super.key,
    required this.api,
    required this.nama,
    required this.keranjang,
    required this.onBukaKatalog,
    required this.onBukaKeranjang,
    required this.onKeranjangBerubah,
  });
  final RakRapiApi api;
  final String nama;
  final Keranjang keranjang;
  final void Function({int? kategoriId, bool fokusCari}) onBukaKatalog;
  final VoidCallback onBukaKeranjang;
  final VoidCallback onKeranjangBerubah;

  @override
  State<BerandaPembeliTab> createState() => _BerandaPembeliTabState();
}

class _BerandaPembeliTabState extends State<BerandaPembeliTab> {
  late Future<(Json, List<Json>, List<Json>)> _future = _muat();

  Future<(Json, List<Json>, List<Json>)> _muat() async {
    final hasil = await Future.wait([
      widget.api.infoToko(),
      widget.api.daftarPin(),
      widget.api.daftarBarang(),
    ]);
    return (hasil[0] as Json, hasil[1] as List<Json>, hasil[2] as List<Json>);
  }

  void muatUlang() {
    setState(() {
      _future = _muat();
    });
  }

  void bukaLayanan(JenisLayanan jenis) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => LayarLayananInfo(
          api: widget.api,
          jenis: jenis,
          pemilik: false,
          namaPengguna: widget.nama,
        ),
      ),
    ).then((_) {
      if (mounted) muatUlang();
    });
  }

  void bukaKategori() {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => LayarKategoriPembeli(
          api: widget.api,
          onPilihKategori: (id) => widget.onBukaKatalog(kategoriId: id),
        ),
      ),
    );
  }

  void tambahCepat(Json b) {
    final stokMaks = jumlahPerseribu(b['stok'].toString(), b['satuan']) ?? 0;
    if (stokMaks <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Stok produk sedang habis.')));
      return;
    }
    final lama = widget.keranjang.item[b['id']];
    final baru = (lama?.jumlah ?? 0) + 1000;
    if (baru > stokMaks) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jumlah melebihi stok tersedia.')),
      );
      return;
    }
    widget.keranjang.atur(b, baru);
    widget.onKeranjangBerubah();
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
    final jumlahKeranjang = widget.keranjang.totalItemJenis;
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<(Json, List<Json>, List<Json>)>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(
                child: PesanGagal(snap.error.toString(), ulangi: muatUlang),
              );
            }
            final (toko, daftarPin, semuaProduk) = snap.requireData;
            final jamToko = (toko['jam_operasional'] ?? '').toString().trim();
            final teksInfoAtas = jamToko.isNotEmpty
                ? jamToko
                : 'Informasi jam buka belum dikonfigurasi';
            final pilihan = semuaProduk.take(4).toList();

            return RefreshIndicator(
              onRefresh: () async {
                muatUlang();
                try {
                  await _future;
                } on KesalahanApi {
                  // Kesalahan ditampilkan melalui PesanGagal.
                }
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const LogoRakRapi(),
                      IconButton.outlined(
                        tooltip: 'Keranjang',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: garisKartu),
                        ),
                        onPressed: widget.onBukaKeranjang,
                        icon: Badge(
                          isLabelVisible: jumlahKeranjang > 0,
                          label: Text('$jumlahKeranjang'),
                          child: const Icon(
                            Icons.shopping_bag_outlined,
                            size: 20,
                            color: hijauTua,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Selamat datang, ${widget.nama}',
                    style: const TextStyle(color: teksRedup, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Mau belanja apa hari ini?',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Informasi toko ringkas di bagian atas beranda (bukan kotak besar di bawah).
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => tampilkanSheetInfoToko(context, toko),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: garisKartu),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.schedule,
                            size: 15,
                            color: hijauUtama,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              teksInfoAtas,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: teksRedup,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Info toko',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: hijauUtama,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => widget.onBukaKatalog(fokusCari: true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 13,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: garisKartu),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.search, color: teksRedup, size: 20),
                          SizedBox(width: 10),
                          Text(
                            'Cari beras, telur, minyak...',
                            style: TextStyle(color: teksRedup, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (daftarPin.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text(
                      'Info prioritas',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Informasi penting yang dipin pemilik toko.',
                      style: TextStyle(fontSize: 12, color: teksRedup),
                    ),
                    const SizedBox(height: 10),
                    for (final pin in daftarPin) _kartuPin(pin),
                  ],
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: hijauTua,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'KEBUTUHAN HARIAN',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                            color: Color(0xFFB7D6C4),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Belanja dekat, lebih praktis.',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Pesan sembako dari aplikasi, lalu ambil langsung di kasir toko.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFFD5E3DA),
                          ),
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: hijauTua,
                            minimumSize: const Size(140, 42),
                          ),
                          onPressed: () => widget.onBukaKatalog(),
                          icon: const Icon(Icons.arrow_forward, size: 16),
                          label: const Text('Mulai belanja'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Layanan',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _tombolLayanan(
                        Icons.grid_view_rounded,
                        'Kategori',
                        bukaKategori,
                      ),
                      const SizedBox(width: 8),
                      _tombolLayanan(
                        Icons.work_outline,
                        'Lowongan',
                        () => bukaLayanan(JenisLayanan.lowongan),
                      ),
                      const SizedBox(width: 8),
                      _tombolLayanan(
                        Icons.volunteer_activism_outlined,
                        'Bansos',
                        () => bukaLayanan(JenisLayanan.bansos),
                      ),
                      const SizedBox(width: 8),
                      _tombolLayanan(
                        Icons.campaign_outlined,
                        'Pengumuman',
                        () => bukaLayanan(JenisLayanan.pengumuman),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Produk pilihan',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      TextButton(
                        onPressed: () => widget.onBukaKatalog(),
                        child: const Text('Lihat semua'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: pilihan.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          mainAxisExtent: 256,
                        ),
                    itemBuilder: (_, i) => _kartuProdukRingkas(pilihan[i]),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _kartuPin(Json pin) {
    final sumber = pin['sumber']?.toString() ?? 'pengumuman';
    final jenis = pin['jenis']?.toString() ?? 'Pengumuman';
    final fotoUrl = pin['foto_url']?.toString();
    final labelTombol = sumber == 'lowongan'
        ? 'Lihat lowongan'
        : sumber == 'bansos'
        ? 'Lihat program'
        : 'Lihat informasi';
    final targetJenis = sumber == 'lowongan'
        ? JenisLayanan.lowongan
        : sumber == 'bansos'
        ? JenisLayanan.bansos
        : JenisLayanan.pengumuman;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (fotoUrl != null && fotoUrl.isNotEmpty)
              FotoUrlPrivat(
                api: widget.api,
                fotoUrl: fotoUrl,
                tinggi: 155,
                fit: BoxFit.cover,
                radius: 0,
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    children: [
                      BadgeLabel(jenis),
                      const BadgeLabel(
                        'Dipin',
                        latar: hijauUtama,
                        warnaTeks: Colors.white,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    pin['judul'].toString(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if ((pin['deskripsi'] ?? '').toString().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      pin['deskripsi'].toString(),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: teksRedup),
                    ),
                  ],
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () => bukaLayanan(targetJenis),
                    child: Text(labelTombol),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tombolLayanan(IconData ikon, String label, VoidCallback onTap) =>
      Expanded(
        child: Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 19,
                    backgroundColor: hijauLembut,
                    child: Icon(ikon, size: 19, color: hijauUtama),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _kartuProdukRingkas(Json b) {
    final habis = (double.tryParse(b['stok'].toString()) ?? 0) <= 0;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) => DetailBarang(
                api: widget.api,
                id: b['id'] as int,
                role: 'warga',
                keranjang: widget.keranjang,
                onKeranjangBerubah: widget.onKeranjangBerubah,
              ),
            ),
          ).then((_) {
            if (mounted) {
              widget.onKeranjangBerubah();
              muatUlang();
            }
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: FotoUrlPrivat(
                  api: widget.api,
                  fotoUrl:
                      (b['foto_url'] ?? '/api/barang/${b['id']}/foto')
                          .toString(),
                  tinggi: null,
                  fit: BoxFit.contain,
                  radius: 12,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                (b['nama_kategori'] ?? '').toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: teksRedup),
              ),
              Text(
                b['nama'].toString(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                hargaRupiah(b['harga_rupiah']),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
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
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 30,
                    height: 30,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(30, 30),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: habis ? null : () => tambahCepat(b),
                      child: const Icon(Icons.add, size: 16),
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

class AkunPembeliTab extends StatefulWidget {
  const AkunPembeliTab({
    super.key,
    required this.api,
    required this.pengguna,
    required this.keluar,
  });
  final RakRapiApi api;
  final Json pengguna;
  final VoidCallback keluar;

  @override
  State<AkunPembeliTab> createState() => _AkunPembeliTabState();
}

class _AkunPembeliTabState extends State<AkunPembeliTab> {
  late Future<(List<Json>, List<Json>, Json)> _future = _muat();

  Future<(List<Json>, List<Json>, Json)> _muat() async {
    final res = await Future.wait([
      widget.api.lamaranSaya(),
      widget.api.pengajuanBansosSaya(),
      widget.api.infoToko(),
    ]);
    return (res[0] as List<Json>, res[1] as List<Json>, res[2] as Json);
  }

  void muat() {
    setState(() {
      _future = _muat();
    });
  }

  Future<void> konfirmasiKeluar() async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar dari akun?'),
        content: const Text('Anda perlu masuk kembali untuk mengakses RakRapi.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (yakin == true) widget.keluar();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Akun'),
      actions: [
        IconButton(
          tooltip: 'Muat ulang',
          onPressed: muat,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<(List<Json>, List<Json>, Json)>(
      future: _future,
      builder: (context, snap) {
        final lamaran = snap.data?.$1 ?? const <Json>[];
        final bansos = snap.data?.$2 ?? const <Json>[];
        final toko = snap.data?.$3;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 26,
                      backgroundColor: hijauLembut,
                      child: Icon(Icons.person_outline, color: hijauUtama),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.pengguna['nama'].toString(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            widget.pengguna['email'].toString(),
                            style: const TextStyle(color: teksRedup),
                          ),
                          const SizedBox(height: 4),
                          const BadgeLabel('Pembeli'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.storefront_outlined, color: hijauUtama),
                title: const Text(
                  'Informasi toko & pengambilan',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text('Jam buka, alamat, dan info pembayaran'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => tampilkanSheetInfoToko(context, toko),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pengajuan saya',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (snap.connectionState != ConnectionState.done)
                      const LinearProgressIndicator()
                    else if (lamaran.isEmpty && bansos.isEmpty)
                      const Text(
                        'Belum ada pengajuan lamaran maupun bantuan sosial.',
                        style: TextStyle(color: teksRedup),
                      )
                    else ...[
                      for (final l in lamaran)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text('Lowongan: ${l['judul_lowongan']}'),
                          subtitle: Text(l['status'].toString()),
                          trailing: BadgeLabel(l['status'].toString()),
                        ),
                      for (final b in bansos)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text('Bansos: ${b['nama_program']}'),
                          subtitle: Text(b['status'].toString()),
                          trailing: BadgeLabel(b['status'].toString()),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: merahPeringatan,
                side: const BorderSide(color: merahPeringatan),
              ),
              onPressed: konfirmasiKeluar,
              icon: const Icon(Icons.logout_outlined),
              label: const Text('Keluar'),
            ),
          ],
        );
      },
    ),
  );
}
