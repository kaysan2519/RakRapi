import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'form_akun.dart';
import 'katalog.dart';
import 'keranjang.dart';
import 'lowongan.dart';
import 'theme/app_theme.dart';
import 'widgets/keadaan_kosong.dart';

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
    if (mounted) {
      setState(() {
        pengguna = sesi['user'] as Json;
        pesanMasuk = null;
      });
    }
  }

  Future<void> keluar({bool sesiHabis = false}) async {
    api.token = null;
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(masalahSesi!),
                TextButton(
                  onPressed: pulihkanSesi,
                  child: const Text('Coba lagi'),
                ),
                TextButton(onPressed: keluar, child: const Text('Keluar')),
              ],
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
      layar = BerandaWarga(api: api, nama: pengguna!['nama'], keluar: keluar);
    } else if (pengguna!['role'] == 'pemilik' ||
        pengguna!['role'] == 'pegawai') {
      layar = DaftarBarang(api: api, role: pengguna!['role'], keluar: keluar);
    } else {
      layar = Scaffold(
        appBar: AppBar(
          title: const Text('Akun'),
          actions: [TextButton(onPressed: keluar, child: const Text('Keluar'))],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: const Text('Peran akun tidak dikenal.'),
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
  });
  final RakRapiApi api;
  final String nama;
  final VoidCallback keluar;

  @override
  State<BerandaWarga> createState() => _BerandaWargaState();
}

class _BerandaWargaState extends State<BerandaWarga> {
  int tab = 0;
  final keranjang = Keranjang();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: switch (tab) {
      0 => DaftarBarang(
        api: widget.api,
        role: 'warga',
        keluar: widget.keluar,
        keranjang: keranjang,
      ),
      1 => LayarLowongan(api: widget.api, pemilik: false),
      _ => Scaffold(
        appBar: AppBar(title: const Text('Bantuan sosial')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: KeadaanKosong(
              ikon: Icons.volunteer_activism_outlined,
              judul: 'Layanan bansos sedang disiapkan',
              penjelasan:
                  'Halo, ${widget.nama}. Pengajuan dan riwayat bantuan belum tersedia. Kamu tetap bisa berbelanja melalui Katalog.',
            ),
          ),
        ),
      ),
    },
    bottomNavigationBar: NavigationBar(
      selectedIndex: tab,
      onDestinationSelected: (index) => setState(() => tab = index),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.storefront), label: 'Katalog'),
        NavigationDestination(
          icon: Icon(Icons.work_outline),
          label: 'Lowongan',
        ),
        NavigationDestination(
          icon: Icon(Icons.volunteer_activism_outlined),
          label: 'Bansos',
        ),
      ],
    ),
  );
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
          judul: 'Daftar sebagai pembeli',
          simpan: widget.daftar,
          labelTombol: 'Daftar',
          labelSibuk: 'Mendaftar…',
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
      const SnackBar(content: Text('Akun pembeli dibuat. Silakan masuk.')),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.storefront_outlined,
                  size: 56,
                  color: hijauUtama,
                ),
                const SizedBox(height: 8),
                Text(
                  'RakRapi',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 48),
                Text(
                  'Masuk ke Akun',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Kelola toko, belanja, dan akses layanan RakRapi.'),
                const SizedBox(height: 28),
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.mail_outline),
                  ),
                ),
                const SizedBox(height: 16),
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
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: sibuk ? null : kirim,
                  child: Text(sibuk ? 'Memeriksa…' : 'Masuk'),
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('Belum punya akun? '),
                    TextButton(
                      onPressed: sibuk ? null : daftar,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Daftar sebagai pembeli'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
