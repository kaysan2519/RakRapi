import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api.dart';
import 'form_akun.dart';
import 'katalog.dart' show PesanGagal;
import 'theme/app_theme.dart';
import 'widgets/keadaan_kosong.dart';

Future<void> tampilkanSheetInfoToko(BuildContext context, Json? toko) async {
  final nama = (toko?['nama_toko'] ?? 'Toko Sembako RakRapi').toString();
  final jam = (toko?['jam_operasional'] ?? '').toString().trim();
  final alamat = (toko?['alamat'] ?? '').toString().trim();
  final kontak = (toko?['kontak'] ?? '').toString().trim();
  final pengambilan = (toko?['info_pengambilan'] ??
          'Ambil di kasir toko setelah status pesanan Siap diambil.')
      .toString();
  final rekSiap = toko?['rekening_tersedia'] == true;

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: hijauLembut,
                    child: Icon(Icons.storefront_outlined, color: hijauUtama),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      nama,
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _barisInfo('Jam operasional', jam.isEmpty ? 'Belum dikonfigurasi pemilik' : jam),
              _barisInfo('Alamat toko', alamat.isEmpty ? 'Belum dikonfigurasi pemilik' : alamat),
              _barisInfo('Kontak toko', kontak.isEmpty ? 'Belum dikonfigurasi pemilik' : kontak),
              _barisInfo('Pengambilan pesanan', 'Ambil di kasir · $pengambilan'),
              const Divider(height: 24),
              const Text(
                'Pembayaran transfer bank',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              if (rekSiap)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: latarAplikasi,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: garisKartu),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        toko!['nama_bank'].toString(),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              toko['nomor_rekening'].toString(),
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(
                                  text: toko['nomor_rekening'].toString(),
                                ),
                              );
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content: Text('Nomor rekening disalin.'),
                                ),
                              );
                            },
                            icon: const Icon(Icons.copy, size: 16),
                            label: const Text('Salin'),
                          ),
                        ],
                      ),
                      Text(
                        'a.n. ${toko['nama_pemilik_rekening']}',
                        style: const TextStyle(color: teksRedup),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: latarAplikasi,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: garisKartu),
                  ),
                  child: const Text(
                    'Pembayaran transfer bank belum tersedia karena rekening toko belum dikonfigurasi pemilik. Gunakan Bayar di kasir.',
                    style: TextStyle(fontSize: 12, color: teksRedup),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _barisInfo(String label, String nilai) => Padding(
  padding: const EdgeInsets.only(bottom: 10),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 12, color: teksRedup)),
      const SizedBox(height: 2),
      Text(nilai, style: const TextStyle(fontWeight: FontWeight.w600)),
    ],
  ),
);

class LayarPegawai extends StatefulWidget {
  const LayarPegawai({super.key, required this.api});
  final RakRapiApi api;

  @override
  State<LayarPegawai> createState() => _LayarPegawaiState();
}

class _LayarPegawaiState extends State<LayarPegawai> {
  late Future<List<Json>> _future = widget.api.daftarPegawai();

  void muat() {
    setState(() {
      _future = widget.api.daftarPegawai();
    });
  }

  Future<void> tambahPegawai() async {
    final email = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => FormAkun(
          judul: 'Tambah pegawai',
          subjudul: 'Buat akun baru untuk staf operasional toko.',
          simpan: widget.api.tambahPegawai,
          labelTombol: 'Buat akun pegawai',
        ),
      ),
    );
    if (mounted && email != null) {
      muat();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Akun pegawai $email dibuat.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Kelola pegawai'),
      actions: [
        IconButton(
          tooltip: 'Muat ulang',
          onPressed: muat,
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
              onPressed: tambahPegawai,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Tambah pegawai'),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Json>>(
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
                final daftar = snap.requireData;
                if (daftar.isEmpty) {
                  return const Center(
                    child: KeadaanKosong(
                      ikon: Icons.badge_outlined,
                      judul: 'Belum ada akun pegawai',
                      penjelasan: 'Tambahkan akun pegawai agar staf dapat mengelola stok dan pesanan.',
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  itemCount: daftar.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final p = daftar[i];
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: hijauLembut,
                          child: Icon(Icons.person_outline, color: hijauUtama),
                        ),
                        title: Text(
                          p['nama'],
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          p['email'],
                          style: const TextStyle(color: teksRedup),
                        ),
                        trailing: const BadgeLabel('Pegawai'),
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

class LayarInfoToko extends StatefulWidget {
  const LayarInfoToko({super.key, required this.api});
  final RakRapiApi api;

  @override
  State<LayarInfoToko> createState() => _LayarInfoTokoState();
}

class _LayarInfoTokoState extends State<LayarInfoToko> {
  final namaToko = TextEditingController();
  final jam = TextEditingController();
  final alamat = TextEditingController();
  final kontak = TextEditingController();
  final pengambilan = TextEditingController();
  final namaBank = TextEditingController();
  final nomorRekening = TextEditingController();
  final pemilikRekening = TextEditingController();

  bool memuat = true;
  bool menyimpan = false;
  String? pesan;

  @override
  void initState() {
    super.initState();
    muat();
  }

  @override
  void dispose() {
    namaToko.dispose();
    jam.dispose();
    alamat.dispose();
    kontak.dispose();
    pengambilan.dispose();
    namaBank.dispose();
    nomorRekening.dispose();
    pemilikRekening.dispose();
    super.dispose();
  }

  Future<void> muat() async {
    setState(() {
      memuat = true;
      pesan = null;
    });
    try {
      final d = await widget.api.infoToko();
      namaToko.text = (d['nama_toko'] ?? '').toString();
      jam.text = (d['jam_operasional'] ?? '').toString();
      alamat.text = (d['alamat'] ?? '').toString();
      kontak.text = (d['kontak'] ?? '').toString();
      pengambilan.text = (d['info_pengambilan'] ?? '').toString();
      namaBank.text = (d['nama_bank'] ?? '').toString();
      nomorRekening.text = (d['nomor_rekening'] ?? '').toString();
      pemilikRekening.text = (d['nama_pemilik_rekening'] ?? '').toString();
    } catch (e) {
      pesan = e.toString();
    } finally {
      if (mounted) setState(() => memuat = false);
    }
  }

  Future<void> simpan() async {
    if (menyimpan) return;
    FocusScope.of(context).unfocus();
    setState(() {
      menyimpan = true;
      pesan = null;
    });
    try {
      await widget.api.perbaruiInfoToko({
        'nama_toko': namaToko.text.trim(),
        'jam_operasional': jam.text.trim(),
        'alamat': alamat.text.trim(),
        'kontak': kontak.text.trim(),
        'info_pengambilan': pengambilan.text.trim(),
        'nama_bank': namaBank.text.trim(),
        'nomor_rekening': nomorRekening.text.trim(),
        'nama_pemilik_rekening': pemilikRekening.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Informasi toko & rekening disimpan.')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) setState(() => pesan = e.toString());
    } finally {
      if (mounted) setState(() => menyimpan = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Info & rekening toko')),
    body: memuat
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Informasi toko tampil di bagian atas beranda pembeli.',
                style: TextStyle(color: teksRedup),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: namaToko,
                decoration: const InputDecoration(labelText: 'Nama toko'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: jam,
                decoration: const InputDecoration(
                  labelText: 'Jam operasional',
                  hintText: 'Contoh: Buka setiap hari · 07.00–21.00',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: alamat,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Alamat toko'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: kontak,
                decoration: const InputDecoration(labelText: 'Kontak toko'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pengambilan,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Petunjuk pengambilan di kasir',
                ),
              ),
              const Divider(height: 28),
              const Text(
                'Rekening Transfer Bank (Opsional)',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              const SizedBox(height: 4),
              const Text(
                'Kosongkan ketiga kolom di bawah bila transfer bank belum diaktifkan. Jangan mengisi nomor rekening palsu.',
                style: TextStyle(fontSize: 12, color: teksRedup),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: namaBank,
                decoration: const InputDecoration(labelText: 'Nama bank'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nomorRekening,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Nomor rekening'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pemilikRekening,
                decoration: const InputDecoration(
                  labelText: 'Nama pemilik rekening',
                ),
              ),
              if (pesan != null) PesanGagal(pesan!),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: menyimpan ? null : simpan,
                child: Text(menyimpan ? 'Menyimpan…' : 'Simpan informasi toko'),
              ),
            ],
          ),
  );
}
