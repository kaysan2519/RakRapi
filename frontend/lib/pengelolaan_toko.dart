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
  String _filterStatus = 'aktif';

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Akun pegawai $email dibuat.')));
    }
  }

  Future<void> bukaDetail(Json pegawai) async {
    final berubah = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            DetailPegawai(api: widget.api, id: pegawai['id'] as int),
      ),
    );
    if (mounted && berubah == true) muat();
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
          final semua = snap.requireData;
          final daftarAktif = semua
              .where((p) => (p['status'] ?? 'aktif') == 'aktif')
              .toList();
          final daftarDiberhentikan = semua
              .where((p) => p['status'] == 'diberhentikan')
              .toList();
          final terlihat = _filterStatus == 'aktif'
              ? daftarAktif
              : daftarDiberhentikan;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: FilledButton.icon(
                  onPressed: tambahPegawai,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Tambah pegawai'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: Text('Aktif (${daftarAktif.length})'),
                      selected: _filterStatus == 'aktif',
                      showCheckmark: false,
                      labelStyle: TextStyle(
                        color: _filterStatus == 'aktif'
                            ? Colors.white
                            : hijauTua,
                        fontWeight: FontWeight.w700,
                      ),
                      onSelected: (_) =>
                          setState(() => _filterStatus = 'aktif'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text(
                        'Diberhentikan (${daftarDiberhentikan.length})',
                      ),
                      selected: _filterStatus == 'diberhentikan',
                      showCheckmark: false,
                      labelStyle: TextStyle(
                        color: _filterStatus == 'diberhentikan'
                            ? Colors.white
                            : hijauTua,
                        fontWeight: FontWeight.w700,
                      ),
                      onSelected: (_) =>
                          setState(() => _filterStatus = 'diberhentikan'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: terlihat.isEmpty
                    ? Center(
                        child: KeadaanKosong(
                          ikon: Icons.badge_outlined,
                          judul: _filterStatus == 'aktif'
                              ? 'Belum ada pegawai aktif'
                              : 'Belum ada pegawai diberhentikan',
                          penjelasan: _filterStatus == 'aktif'
                              ? 'Tambahkan akun pegawai agar staf dapat mengelola stok dan pesanan.'
                              : 'Riwayat pegawai yang diberhentikan akan tersimpan di sini beserta alasan dan tanggalnya.',
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                        itemCount: terlihat.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final p = terlihat[i];
                          final diberhentikan = p['status'] == 'diberhentikan';
                          final tgl = formatTanggalSingkat(
                            p['diberhentikan_pada']?.toString(),
                          );
                          return Card(
                            child: ListTile(
                              onTap: () => bukaDetail(p),
                              leading: CircleAvatar(
                                backgroundColor: diberhentikan
                                    ? latarPeringatan
                                    : hijauLembut,
                                child: Icon(
                                  diberhentikan
                                      ? Icons.person_off_outlined
                                      : Icons.person_outline,
                                  color: diberhentikan
                                      ? merahPeringatan
                                      : hijauUtama,
                                ),
                              ),
                              title: Text(
                                p['nama'].toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p['email'].toString(),
                                    style: const TextStyle(color: teksRedup),
                                  ),
                                  if (diberhentikan && tgl.isNotEmpty)
                                    Text(
                                      'Diberhentikan: $tgl',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: merahPeringatan,
                                      ),
                                    ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  BadgeLabel(
                                    diberhentikan ? 'Diberhentikan' : 'Aktif',
                                    latar: diberhentikan
                                        ? latarPeringatan
                                        : hijauLembut,
                                    warnaTeks: diberhentikan
                                        ? merahPeringatan
                                        : hijauUtama,
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.chevron_right,
                                    color: teksRedup,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class DetailPegawai extends StatefulWidget {
  const DetailPegawai({super.key, required this.api, required this.id});
  final RakRapiApi api;
  final int id;

  @override
  State<DetailPegawai> createState() => _DetailPegawaiState();
}

class _DetailPegawaiState extends State<DetailPegawai> {
  late Future<Json> _future = widget.api.detailPegawai(widget.id);
  bool sibuk = false;
  bool adaPerubahan = false;
  String? pesan;

  void muat() {
    setState(() {
      _future = widget.api.detailPegawai(widget.id);
      pesan = null;
    });
  }

  Future<void> bukaDialogBerhentikan(Json pegawai) async {
    if (sibuk) return;
    final alasan = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DialogBerhentikanPegawai(pegawai: pegawai),
    );
    if (!mounted || alasan == null) return;

    setState(() {
      sibuk = true;
      pesan = null;
    });
    try {
      final diperbarui = await widget.api.berhentikanPegawai(widget.id, alasan);
      if (mounted) {
        adaPerubahan = true;
        setState(() {
          _future = Future.value(diperbarui);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Pegawai ${pegawai['nama']} diberhentikan. Akses aplikasi dicabut.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => pesan = e.toString());
    } finally {
      if (mounted) setState(() => sibuk = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !sibuk,
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) return;
    },
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Detail pegawai'),
        leading: IconButton(
          tooltip: 'Kembali',
          onPressed: sibuk ? null : () => Navigator.pop(context, adaPerubahan),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: FutureBuilder<Json>(
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
          final p = snap.requireData;
          final diberhentikan = p['status'] == 'diberhentikan';
          final tgl = formatTanggalSingkat(p['diberhentikan_pada']?.toString());
          final alasan = (p['alasan_pemberhentian'] ?? '').toString().trim();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: diberhentikan
                                ? latarPeringatan
                                : hijauLembut,
                            child: Icon(
                              diberhentikan
                                  ? Icons.person_off_outlined
                                  : Icons.person_outline,
                              size: 28,
                              color: diberhentikan
                                  ? merahPeringatan
                                  : hijauUtama,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p['nama'].toString(),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  p['email'].toString(),
                                  style: const TextStyle(color: teksRedup),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Status akun',
                            style: TextStyle(color: teksRedup),
                          ),
                          BadgeLabel(
                            diberhentikan ? 'Diberhentikan' : 'Aktif',
                            latar: diberhentikan
                                ? latarPeringatan
                                : hijauLembut,
                            warnaTeks: diberhentikan
                                ? merahPeringatan
                                : hijauUtama,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _barisInfo('Peran', 'Pegawai operasional toko'),
                      if (diberhentikan) ...[
                        _barisInfo(
                          'Tanggal pemberhentian',
                          tgl.isEmpty ? '-' : tgl,
                        ),
                        _barisInfo(
                          'Alasan pemberhentian',
                          alasan.isEmpty ? '-' : alasan,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (diberhentikan)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: latarPeringatan,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Pegawai ini sudah diberhentikan. Akun tidak dapat login dan seluruh token lama ditolak, namun catatan akun serta riwayat transaksi tetap dipertahankan di database.',
                    style: TextStyle(fontSize: 12, color: merahPeringatan),
                  ),
                )
              else ...[
                if (pesan != null) PesanGagal(pesan!),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: merahPeringatan,
                  ),
                  onPressed: sibuk ? null : () => bukaDialogBerhentikan(p),
                  icon: const Icon(Icons.person_off_outlined),
                  label: Text(
                    sibuk ? 'Memproses…' : 'Berhentikan Pegawai',
                  ),
                ),
              ],
            ],
          );
        },
      ),
    ),
  );
}

String formatTanggalSingkat(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '';
  final dt = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
  if (dt == null) return raw;
  final lokal = dt.toLocal();
  final d = lokal.day.toString().padLeft(2, '0');
  final m = lokal.month.toString().padLeft(2, '0');
  final y = lokal.year.toString();
  final hh = lokal.hour.toString().padLeft(2, '0');
  final mm = lokal.minute.toString().padLeft(2, '0');
  return '$d/$m/$y $hh:$mm';
}

class _DialogBerhentikanPegawai extends StatefulWidget {
  const _DialogBerhentikanPegawai({required this.pegawai});
  final Json pegawai;

  @override
  State<_DialogBerhentikanPegawai> createState() =>
      _DialogBerhentikanPegawaiState();
}

class _DialogBerhentikanPegawaiState extends State<_DialogBerhentikanPegawai> {
  final alasanCtrl = TextEditingController();
  String? errorDialog;

  @override
  void dispose() {
    alasanCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Berhentikan Pegawai'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Anda akan memberhentikan ${widget.pegawai['nama']} (${widget.pegawai['email']}).',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: latarPeringatan,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Pegawai akan segera kehilangan akses aplikasi, tidak dapat login kembali, dan sesi yang masih aktif otomatis ditolak. Data akun serta riwayat transaksi tetap disimpan di database.',
              style: TextStyle(fontSize: 12, color: merahPeringatan),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: alasanCtrl,
            maxLines: 3,
            maxLength: 500,
            decoration: InputDecoration(
              labelText: 'Alasan pemberhentian',
              hintText: 'Tuliskan alasan pemberhentian pegawai...',
              alignLabelWithHint: true,
              errorText: errorDialog,
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Batal'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: merahPeringatan),
        onPressed: () {
          final teks = alasanCtrl.text.trim();
          if (teks.isEmpty) {
            setState(() => errorDialog = 'Alasan pemberhentian wajib diisi.');
            return;
          }
          Navigator.pop(context, teks);
        },
        child: const Text('Berhentikan Pegawai'),
      ),
    ],
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
