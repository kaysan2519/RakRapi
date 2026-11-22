import 'package:flutter/material.dart';

import 'api.dart';
import 'katalog.dart';
import 'kategori.dart';
import 'layanan_info.dart';
import 'pengelolaan_toko.dart';
import 'pesanan.dart';
import 'theme/app_theme.dart';

class ShellPengelola extends StatefulWidget {
  const ShellPengelola({
    super.key,
    required this.api,
    required this.pengguna,
    required this.keluar,
  });
  final RakRapiApi api;
  final Json pengguna;
  final VoidCallback keluar;

  @override
  State<ShellPengelola> createState() => _ShellPengelolaState();
}

class _ShellPengelolaState extends State<ShellPengelola> {
  int tab = 0;

  String get role => widget.pengguna['role'].toString();
  bool get pemilik => role == 'pemilik';

  @override
  Widget build(BuildContext context) => Scaffold(
    body: switch (tab) {
      0 => _DashboardTab(
        api: widget.api,
        pengguna: widget.pengguna,
        onPilihTab: (i) => setState(() => tab = i),
      ),
      1 => DaftarBarang(
        api: widget.api,
        role: role,
        keluar: widget.keluar,
      ),
      2 => DaftarPesanan(api: widget.api, toko: true),
      _ => _AkunPengelolaTab(
        api: widget.api,
        pengguna: widget.pengguna,
        keluar: widget.keluar,
      ),
    },
    bottomNavigationBar: NavigationBar(
      selectedIndex: tab,
      onDestinationSelected: (i) => setState(() => tab = i),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Beranda',
        ),
        NavigationDestination(
          icon: Icon(Icons.inventory_2_outlined),
          selectedIcon: Icon(Icons.inventory_2),
          label: 'Produk',
        ),
        NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          selectedIcon: Icon(Icons.receipt_long),
          label: 'Pesanan',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Akun',
        ),
      ],
    ),
  );
}

class _DashboardTab extends StatefulWidget {
  const _DashboardTab({
    required this.api,
    required this.pengguna,
    required this.onPilihTab,
  });
  final RakRapiApi api;
  final Json pengguna;
  final ValueChanged<int> onPilihTab;

  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  late Future<Json> _future = widget.api.ringkasanDashboard();

  bool get pemilik => widget.pengguna['role'] == 'pemilik';

  void muat() {
    setState(() {
      _future = widget.api.ringkasanDashboard();
    });
  }

  Future<void> bukaHalaman(Widget halaman) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => halaman),
    );
    if (mounted) muat();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: FutureBuilder<Json>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: PesanGagal(snap.error.toString(), ulangi: muat),
            );
          }
          final d = snap.requireData;
          return RefreshIndicator(
            onRefresh: () async {
              muat();
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
                    BadgeLabel(pemilik ? 'Pemilik' : 'Pegawai'),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Operasional toko · ${widget.pengguna['nama']}',
                  style: const TextStyle(color: teksRedup, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  pemilik ? 'Ringkasan toko' : 'Kelola operasional',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: hijauLembut,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    pemilik
                        ? 'Kelola katalog, kategori, pegawai, pesanan, dan informasi prioritas toko dari satu tempat.'
                        : 'Periksa stok barang, konfirmasi pesanan masuk, verifikasi pembayaran, dan selesaikan pesanan.',
                    style: const TextStyle(fontSize: 13, color: hijauTua),
                  ),
                ),
                if (pemilik) ...[
                  const SizedBox(height: 14),
                  // Tombol Pin informasi ke beranda menonjol di bagian atas dashboard pemilik.
                  Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: const BorderSide(color: hijauUtama, width: 1.5),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FilledButton.icon(
                            onPressed: () =>
                                bukaHalaman(LayarPinPrioritas(api: widget.api)),
                            icon: const Icon(Icons.push_pin_outlined, size: 19),
                            label: const Text('Pin informasi ke beranda'),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${d['jumlah_pin_aktif'] ?? 0} informasi sedang dipin · pilih atau buat info baru dengan foto',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              color: teksRedup,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.85,
                  children: [
                    _kartuKpi('Produk aktif', '${d['jumlah_produk'] ?? 0}'),
                    _kartuKpi('Pesanan masuk', '${d['pesanan_masuk'] ?? 0}'),
                    if (pemilik) ...[
                      _kartuKpi('Kategori', '${d['jumlah_kategori'] ?? 0}'),
                      _kartuKpi('Pesanan selesai', '${d['pesanan_selesai'] ?? 0}'),
                      _kartuKpi('Pegawai', '${d['jumlah_pegawai'] ?? 0}'),
                      _kartuKpi('Stok menipis (≤5)', '${d['stok_menipis'] ?? 0}'),
                    ] else ...[
                      _kartuKpi('Sedang diproses', '${d['pesanan_diproses'] ?? 0}'),
                      _kartuKpi('Pesanan selesai', '${d['pesanan_selesai'] ?? 0}'),
                      _kartuKpi('Stok menipis (≤5)', '${d['stok_menipis'] ?? 0}'),
                      _kartuKpi('Kategori', '${d['jumlah_kategori'] ?? 0}'),
                    ],
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Menu pengelolaan',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.45,
                  children: [
                    _menuTile(
                      Icons.inventory_2_outlined,
                      'Produk & stok',
                      'Kelola katalog dan stok',
                      () => widget.onPilihTab(1),
                    ),
                    _menuTile(
                      Icons.receipt_long_outlined,
                      'Pesanan',
                      'Konfirmasi & pembayaran',
                      () => widget.onPilihTab(2),
                    ),
                    if (pemilik) ...[
                      _menuTile(
                        Icons.grid_view_rounded,
                        'Kategori',
                        'Kelola kategori produk',
                        () => bukaHalaman(DaftarKategori(api: widget.api)),
                      ),
                      _menuTile(
                        Icons.badge_outlined,
                        'Pegawai',
                        'Kelola akun staf toko',
                        () => bukaHalaman(LayarPegawai(api: widget.api)),
                      ),
                      _menuTile(
                        Icons.work_outline,
                        'Lowongan',
                        '${d['lamaran_menunggu'] ?? 0} lamaran menunggu',
                        () => bukaHalaman(
                          LayarLayananInfo(
                            api: widget.api,
                            jenis: JenisLayanan.lowongan,
                            pemilik: true,
                          ),
                        ),
                      ),
                      _menuTile(
                        Icons.volunteer_activism_outlined,
                        'Bansos',
                        '${d['bansos_menunggu'] ?? 0} pengajuan menunggu',
                        () => bukaHalaman(
                          LayarLayananInfo(
                            api: widget.api,
                            jenis: JenisLayanan.bansos,
                            pemilik: true,
                          ),
                        ),
                      ),
                      _menuTile(
                        Icons.campaign_outlined,
                        'Pengumuman & Diskon',
                        'Kelola info dan promo',
                        () => bukaHalaman(
                          LayarLayananInfo(
                            api: widget.api,
                            jenis: JenisLayanan.pengumuman,
                            pemilik: true,
                          ),
                        ),
                      ),
                      _menuTile(
                        Icons.push_pin_outlined,
                        'Pin prioritas',
                        'Atur info atas beranda',
                        () => bukaHalaman(LayarPinPrioritas(api: widget.api)),
                      ),
                      _menuTile(
                        Icons.storefront_outlined,
                        'Info & rekening toko',
                        'Jam buka & rekening bank',
                        () => bukaHalaman(LayarInfoToko(api: widget.api)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          );
        },
      ),
    ),
  );

  Widget _kartuKpi(String label, String nilai) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: teksRedup)),
          const SizedBox(height: 4),
          Text(
            nilai,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: hijauTua,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _menuTile(
    IconData ikon,
    String judul,
    String sub,
    VoidCallback onTap,
  ) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(ikon, color: hijauUtama, size: 22),
            const SizedBox(height: 8),
            Text(
              judul,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            const SizedBox(height: 2),
            Text(
              sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: teksRedup),
            ),
          ],
        ),
      ),
    ),
  );
}

class _AkunPengelolaTab extends StatelessWidget {
  const _AkunPengelolaTab({
    required this.api,
    required this.pengguna,
    required this.keluar,
  });
  final RakRapiApi api;
  final Json pengguna;
  final VoidCallback keluar;

  @override
  Widget build(BuildContext context) {
    final pemilik = pengguna['role'] == 'pemilik';
    return Scaffold(
      appBar: AppBar(title: const Text('Akun')),
      body: ListView(
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
                          pengguna['nama'].toString(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          pengguna['email'].toString(),
                          style: const TextStyle(color: teksRedup),
                        ),
                        const SizedBox(height: 4),
                        BadgeLabel(pemilik ? 'Pemilik' : 'Pegawai'),
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
              title: Text(
                pemilik ? 'Kelola info & rekening toko' : 'Lihat informasi toko',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                if (pemilik) {
                  await Navigator.push<void>(
                    context,
                    MaterialPageRoute(builder: (_) => LayarInfoToko(api: api)),
                  );
                } else {
                  try {
                    final toko = await api.infoToko();
                    if (context.mounted) {
                      await tampilkanSheetInfoToko(context, toko);
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(e.toString())));
                    }
                  }
                }
              },
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: merahPeringatan,
              side: const BorderSide(color: merahPeringatan),
            ),
            onPressed: () async {
              final yakin = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Keluar dari akun?'),
                  content: const Text(
                    'Anda perlu masuk kembali untuk mengakses dashboard.',
                  ),
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
              if (yakin == true) keluar();
            },
            icon: const Icon(Icons.logout_outlined),
            label: const Text('Keluar'),
          ),
        ],
      ),
    );
  }
}
