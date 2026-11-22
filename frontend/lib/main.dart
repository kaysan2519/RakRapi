import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'beranda_pembeli.dart';
import 'dashboard_pengelola.dart';
import 'form_akun.dart';
import 'katalog.dart';
import 'keranjang.dart';
import 'pesanan.dart';
import 'theme/app_theme.dart';

void main() => runApp(const RakRapi());

class RakRapi extends StatefulWidget {
  const RakRapi({super.key, this.api});
  final RakRapiApi? api;
  @override
  State<RakRapi> createState() => _RakRapiState();
}

class _RakRapiState extends State<RakRapi> {
  late final api = widget.api ?? RakRapiApi();
  final navigasi = GlobalKey<NavigatorState>();
  final penyimpanan = SharedPreferencesAsync();
  Json? pengguna;
  bool memuat = true;
  String? masalahSesi;
  String? pesanMasuk;

  @override
  void initState() {
    super.initState();
    api.saatSesiHabis = () => keluar(sesiHabis: true);
    pulihkanSesi();
  }

  Future<void> pulihkanSesi() async {
    setState(() {
      memuat = true;
      masalahSesi = null;
    });
    try {
      api.token = await penyimpanan.getString('token');
      if (api.token != null) pengguna = await api.profil();
    } catch (e) {
      if (api.token != null) masalahSesi = e.toString();
    } finally {
      if (mounted) setState(() => memuat = false);
    }
  }

  Future<void> masuk(String email, String sandi) async {
    final sesi = await api.masuk(email.trim(), sandi);
    final token = sesi['token'] as String;
    await penyimpanan.setString('token', token);
    api.token = token;
    api.bersihkanCacheFoto();
    if (mounted) {
      setState(() {
        pengguna = sesi['user'] as Json;
        pesanMasuk = null;
      });
    }
  }

  Future<void> keluar({bool sesiHabis = false}) async {
    api.token = null;
    api.bersihkanCacheFoto();
    await penyimpanan.remove('token');
    if (!mounted) return;
    navigasi.currentState?.popUntil((route) => route.isFirst);
    setState(() {
      pengguna = null;
      masalahSesi = null;
      pesanMasuk = sesiHabis ? 'Sesi berakhir. Silakan masuk kembali.' : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget layar;
    if (memuat) {
      layar = const Scaffold(body: Center(child: CircularProgressIndicator()));
    } else if (masalahSesi != null) {
      layar = Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const LogoRakRapi(),
                  const SizedBox(height: 16),
                  Text(masalahSesi!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: pulihkanSesi,
                    child: const Text('Coba lagi'),
                  ),
                  TextButton(onPressed: keluar, child: const Text('Keluar')),
                ],
              ),
            ),
          ),
        ),
      );
    } else if (pengguna == null) {
      layar = LayarMasuk(
        masuk: masuk,
        daftar: api.daftarWarga,
        pesanSesi: pesanMasuk,
      );
    } else if (pengguna!['role'] == 'warga') {
      layar = BerandaWarga(
        api: api,
        pengguna: pengguna!,
        nama: pengguna!['nama'].toString(),
        keluar: keluar,
      );
    } else if (pengguna!['role'] == 'pemilik' ||
        pengguna!['role'] == 'pegawai') {
      layar = ShellPengelola(api: api, pengguna: pengguna!, keluar: keluar);
    } else {
      layar = Scaffold(
        appBar: AppBar(
          title: const Text('Akun'),
          actions: [TextButton(onPressed: keluar, child: const Text('Keluar'))],
        ),
        body: const SafeArea(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Peran akun tidak dikenal.'),
          ),
        ),
      );
    }
    return MaterialApp(
      title: 'RakRapi',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigasi,
      theme: temaRakRapi(),
      home: layar,
    );
  }
}

class BerandaWarga extends StatefulWidget {
  const BerandaWarga({
    super.key,
    required this.api,
    required this.nama,
    required this.keluar,
    this.pengguna,
  });
  final RakRapiApi api;
  final String nama;
  final Json? pengguna;
  final VoidCallback keluar;

  @override
  State<BerandaWarga> createState() => _BerandaWargaState();
}

class _BerandaWargaState extends State<BerandaWarga> {
  int tab = 0;
  int? kategoriFilter;
  bool fokusCari = false;
  final keranjang = Keranjang();

  void bukaKatalog({int? kategoriId, bool fokusCari = false}) {
    setState(() {
      kategoriFilter = kategoriId;
      this.fokusCari = fokusCari;
      tab = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final userObj =
        widget.pengguna ?? {'nama': widget.nama, 'email': '', 'role': 'warga'};
    final jumlahKeranjang = keranjang.totalItemJenis;

    return Scaffold(
      body: switch (tab) {
        0 => BerandaPembeliTab(
          api: widget.api,
          nama: widget.nama,
          keranjang: keranjang,
          onBukaKatalog: bukaKatalog,
          onBukaKeranjang: () => setState(() => tab = 2),
          onKeranjangBerubah: () => setState(() {}),
        ),
        1 => DaftarBarang(
          api: widget.api,
          role: 'warga',
          keluar: widget.keluar,
          keranjang: keranjang,
          kategoriAwalId: kategoriFilter,
          fokusCari: fokusCari,
          onKeranjangBerubah: () => setState(() {}),
          onBukaKeranjang: () => setState(() => tab = 2),
        ),
        2 => LayarKeranjang(
          api: widget.api,
          keranjang: keranjang,
          onMulaiBelanja: () => bukaKatalog(),
          onBerubah: () => setState(() {}),
          onPesananSelesaiBuat: (_) => setState(() => tab = 3),
        ),
        3 => DaftarPesanan(
          api: widget.api,
          toko: false,
          onBelanjaSekarang: () => bukaKatalog(),
        ),
        _ => AkunPembeliTab(
          api: widget.api,
          pengguna: userObj,
          keluar: widget.keluar,
        ),
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (index) => setState(() {
          if (index == 1) {
            kategoriFilter = null;
            fokusCari = false;
          }
          tab = index;
        }),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Beranda',
          ),
          const NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Katalog',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: jumlahKeranjang > 0,
              label: Text('$jumlahKeranjang'),
              child: const Icon(Icons.shopping_bag_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: jumlahKeranjang > 0,
              label: Text('$jumlahKeranjang'),
              child: const Icon(Icons.shopping_bag),
            ),
            label: 'Keranjang',
          ),
          const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Pesanan',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Akun',
          ),
        ],
      ),
    );
  }
}

class LayarMasuk extends StatefulWidget {
  const LayarMasuk({
    super.key,
    required this.masuk,
    required this.daftar,
    this.pesanSesi,
  });
  final Future<void> Function(String, String) masuk;
  final Future<void> Function(String, String, String) daftar;
  final String? pesanSesi;
  @override
  State<LayarMasuk> createState() => _LayarMasukState();
}

class _LayarMasukState extends State<LayarMasuk> {
  final email = TextEditingController();
  final sandi = TextEditingController();
  bool sibuk = false;
  bool sembunyikanSandi = true;
  String? pesan;

  @override
  void dispose() {
    email.dispose();
    sandi.dispose();
    super.dispose();
  }

  Future<void> kirim() async {
    if (sibuk) return;
    FocusScope.of(context).unfocus();
    setState(() {
      sibuk = true;
      pesan = null;
    });
    try {
      await widget.masuk(email.text, sandi.text);
    } catch (e) {
      if (mounted) setState(() => pesan = e.toString());
    } finally {
      if (mounted) setState(() => sibuk = false);
    }
  }

  Future<void> daftar() async {
    final terdaftar = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => FormAkun(
          judul: 'Daftar Akun',
          subjudul: 'Buat akun untuk mulai menggunakan RakRapi.',
          simpan: widget.daftar,
          labelTombol: 'Daftar',
          labelSibuk: 'Mendaftar…',
          modeDaftar: true,
        ),
      ),
    );
    if (!mounted || terdaftar == null) return;
    setState(() {
      email.text = terdaftar;
      sandi.clear();
      pesan = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Akun berhasil dibuat. Silakan masuk.')),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: LogoRakRapi(besar: true)),
                const SizedBox(height: 18),
                Text(
                  'Masuk ke Akun',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Akses layanan RakRapi dengan akun Anda.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: teksRedup),
                ),
                const SizedBox(height: 22),
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.mail_outline),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: sandi,
                  obscureText: sembunyikanSandi,
                  autocorrect: false,
                  onSubmitted: (_) => kirim(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      tooltip: sembunyikanSandi
                          ? 'Tampilkan password'
                          : 'Sembunyikan password',
                      onPressed: () =>
                          setState(() => sembunyikanSandi = !sembunyikanSandi),
                      icon: Icon(
                        sembunyikanSandi
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),
                if (pesan != null || widget.pesanSesi != null)
                  PesanGagal(pesan ?? widget.pesanSesi!),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: sibuk ? null : kirim,
                  child: Text(sibuk ? 'Memeriksa…' : 'Masuk'),
                ),
                const SizedBox(height: 14),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Belum punya akun? ',
                      style: TextStyle(color: teksRedup),
                    ),
                    TextButton(
                      onPressed: sibuk ? null : daftar,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Daftar'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.asset(
                    'assets/images/ilustrasi_toko.webp',
                    height: 165,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
