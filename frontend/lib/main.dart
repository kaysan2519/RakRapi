import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'katalog.dart';

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

  @override
  void initState() {
    super.initState();
    api.saatSesiHabis = keluar;
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
    if (mounted) setState(() => pengguna = sesi['user'] as Json);
  }

  Future<void> keluar() async {
    api.token = null;
    await penyimpanan.remove('token');
    if (!mounted) return;
    navigasi.currentState?.popUntil((route) => route.isFirst);
    setState(() {
      pengguna = null;
      masalahSesi = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tema = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff216240),
        primary: const Color(0xff205c3a),
      ),
      useMaterial3: true,
    );
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
      layar = LayarMasuk(masuk: masuk);
    } else {
      layar = DaftarBarang(
        api: api,
        pemilik: pengguna!['role'] == 'pemilik',
        keluar: keluar,
      );
    }
    return MaterialApp(
      title: 'RakRapi',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigasi,
      theme: tema.copyWith(
        scaffoldBackgroundColor: Colors.white,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: layar,
    );
  }
}

class LayarMasuk extends StatefulWidget {
  const LayarMasuk({super.key, required this.masuk});
  final Future<void> Function(String, String) masuk;
  @override
  State<LayarMasuk> createState() => _LayarMasukState();
}

class _LayarMasukState extends State<LayarMasuk> {
  final email = TextEditingController();
  final sandi = TextEditingController();
  bool sibuk = false;
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
                Text(
                  'RakRapi',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: sandi,
                  obscureText: true,
                  autocorrect: false,
                  onSubmitted: (_) => kirim(),
                  decoration: const InputDecoration(labelText: 'Sandi'),
                ),
                if (pesan != null) PesanGagal(pesan!),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: sibuk ? null : kirim,
                  child: Text(sibuk ? 'Memeriksa…' : 'Masuk'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
