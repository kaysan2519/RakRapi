import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api.dart';
import 'katalog.dart';
import 'theme/app_theme.dart';
import 'widgets/keadaan_kosong.dart';

class DaftarPesanan extends StatefulWidget {
  const DaftarPesanan({
    super.key,
    required this.api,
    required this.toko,
    this.onBelanjaSekarang,
  });
  final RakRapiApi api;
  final bool toko;
  final VoidCallback? onBelanjaSekarang;

  @override
  State<DaftarPesanan> createState() => _DaftarPesananState();
}

class _DaftarPesananState extends State<DaftarPesanan> {
  late Future<List<Json>> daftar = widget.api.pesanan();

  void muat() {
    setState(() {
      daftar = widget.api.pesanan();
    });
  }

  Future<void> buka(int id) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            DetailPesanan(api: widget.api, id: id, toko: widget.toko),
      ),
    );
    if (mounted) muat();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.toko ? 'Kelola pesanan' : 'Pesanan saya'),
      actions: [
        IconButton(
          tooltip: 'Muat ulang',
          onPressed: muat,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<List<Json>>(
      future: daftar,
      builder: (context, hasil) {
        if (hasil.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (hasil.hasError) {
          return Center(
            child: PesanGagal(hasil.error.toString(), ulangi: muat),
          );
        }
        final list = hasil.requireData;
        if (list.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  KeadaanKosong(
                    ikon: Icons.receipt_long_outlined,
                    judul: 'Belum ada pesanan',
                    penjelasan: widget.toko
                        ? 'Pesanan pembeli yang masuk akan tampil di sini.'
                        : 'Pesanan yang Anda buat melalui keranjang akan tampil di sini.',
                  ),
                  if (!widget.toko && widget.onBelanjaSekarang != null)
                    FilledButton(
                      onPressed: widget.onBelanjaSekarang,
                      child: const Text('Belanja sekarang'),
                    ),
                ],
              ),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            muat();
            try {
              await daftar;
            } on KesalahanApi {
              // Ditampilkan di PesanGagal.
            }
          },
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final p = list[i];
              final status = p['status'].toString();
              final statusBayar =
                  (p['status_pembayaran'] ?? 'Belum dibayar').toString();
              final metode =
                  (p['metode_pembayaran'] ?? 'Bayar di kasir').toString();
              final kode =
                  (p['kode_pesanan'] ?? 'RR-${p['id'].toString().padLeft(4, '0')}')
                      .toString();
              final items = ((p['item'] as List?) ?? const []).cast<Json>();

              return Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => buka(p['id'] as int),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              kode,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            _badgeStatusPesanan(status),
                          ],
                        ),
                        if (widget.toko) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Pemesan: ${p['nama_pemesan']}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        if (items.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          for (final item in items.take(3))
                            Text(
                              '${item['nama_barang']} × ${stokTampil({'stok': item['jumlah'], 'satuan': item['satuan']})}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: teksRedup,
                              ),
                            ),
                          if (items.length > 3)
                            Text(
                              '+${items.length - 3} produk lainnya',
                              style: const TextStyle(
                                fontSize: 12,
                                color: teksRedup,
                              ),
                            ),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              hargaRupiah(p['total_rupiah']),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: hijauUtama,
                              ),
                            ),
                            _badgeStatusBayar(statusBayar),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '$metode · Ambil di kasir',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: teksRedup,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: teksRedup,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    ),
  );
}

Widget _badgeStatusPesanan(String status) {
  final (latar, teks) = switch (status) {
    'Selesai' => (hijauUtama, Colors.white),
    'Siap diambil' => (hijauLembut, hijauUtama),
    'Dikonfirmasi' => (hijauLembut, hijauTua),
    _ => (latarKuning, kuningStatus),
  };
  return BadgeLabel(status, latar: latar, warnaTeks: teks);
}

Widget _badgeStatusBayar(String statusBayar) {
  final lunas = statusBayar == 'Sudah dibayar';
  return BadgeLabel(
    statusBayar,
    latar: lunas ? hijauLembut : latarPeringatan,
    warnaTeks: lunas ? hijauUtama : merahPeringatan,
  );
}

class DetailPesanan extends StatefulWidget {
  const DetailPesanan({
    super.key,
    required this.api,
    required this.id,
    required this.toko,
  });
  final RakRapiApi api;
  final int id;
  final bool toko;

  @override
  State<DetailPesanan> createState() => _DetailPesananState();
}

class _DetailPesananState extends State<DetailPesanan> {
  late Future<Json> detail = widget.api.detailPesanan(widget.id);
  Json? infoToko;
  bool sibuk = false;
  String? pesan;

  @override
  void initState() {
    super.initState();
    _muatToko();
  }

  Future<void> _muatToko() async {
    try {
      final t = await widget.api.infoToko();
      if (mounted) setState(() => infoToko = t);
    } catch (_) {}
  }

  void muat() {
    setState(() {
      detail = widget.api.detailPesanan(widget.id);
      pesan = null;
    });
  }

  Future<void> jalankanAksi({
    required String judulDialog,
    required String isiDialog,
    required Future<Json> Function() aksi,
    required String pesanSukses,
  }) async {
    if (sibuk) return;
    final yakin = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(judulDialog),
        content: Text(isiDialog),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, lanjutkan'),
          ),
        ],
      ),
    );
    if (!mounted || yakin != true) return;
    setState(() {
      sibuk = true;
      pesan = null;
    });
    try {
      final data = await aksi();
      if (mounted) {
        setState(() {
          detail = Future.value(data);
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(pesanSukses)));
      }
    } catch (e) {
      if (mounted) setState(() => pesan = e.toString());
    } finally {
      if (mounted) setState(() => sibuk = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('Pesanan RR-${widget.id.toString().padLeft(4, '0')}'),
      actions: [
        IconButton(
          tooltip: 'Muat ulang',
          onPressed: muat,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<Json>(
      future: detail,
      builder: (context, hasil) {
        if (hasil.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (hasil.hasError) {
          return Center(
            child: PesanGagal(hasil.error.toString(), ulangi: muat),
          );
        }
        final p = hasil.requireData;
        final status = p['status'].toString();
        final statusBayar =
            (p['status_pembayaran'] ?? 'Belum dibayar').toString();
        final metode =
            (p['metode_pembayaran'] ?? 'Bayar di kasir').toString();
        final lunas = statusBayar == 'Sudah dibayar';
        final kode =
            (p['kode_pesanan'] ?? 'RR-${p['id'].toString().padLeft(4, '0')}')
                .toString();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          kode,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                        _badgeStatusPesanan(status),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Status pembayaran',
                          style: TextStyle(color: teksRedup),
                        ),
                        _badgeStatusBayar(statusBayar),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$metode · Ambil di kasir',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    if (widget.toko) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Pemesan: ${p['nama_pemesan']}',
                        style: const TextStyle(color: teksRedup),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (!widget.toko)
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: hijauLembut,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  status == 'Menunggu konfirmasi'
                      ? 'Menunggu konfirmasi pegawai. Jangan transfer sebelum pesanan dikonfirmasi.'
                      : status == 'Dikonfirmasi'
                      ? 'Pesanan sedang disiapkan pegawai. Tunggu hingga status Siap diambil.'
                      : status == 'Siap diambil'
                      ? 'Pesanan siap diambil di kasir toko! Tunjukkan nomor pesanan $kode.'
                      : 'Pesanan selesai dan pembayaran telah diverifikasi. Terima kasih!',
                  style: const TextStyle(fontSize: 13, color: hijauTua),
                ),
              ),
            if (!widget.toko &&
                metode == 'Transfer bank' &&
                !lunas &&
                infoToko?['rekening_tersedia'] == true) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Instruksi transfer bank',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text('Bank: ${infoToko!['nama_bank']}'),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              infoToko!['nomor_rekening'].toString(),
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(
                                  text: infoToko!['nomor_rekening'].toString(),
                                ),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Nomor rekening disalin.'),
                                ),
                              );
                            },
                            icon: const Icon(Icons.copy, size: 15),
                            label: const Text('Salin'),
                          ),
                        ],
                      ),
                      Text(
                        'Atas nama: ${infoToko!['nama_pemilik_rekening']}',
                        style: const TextStyle(color: teksRedup),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Transfer tepat ${hargaRupiah(p['total_rupiah'])}, lalu tunjukkan bukti transfer kepada pegawai di kasir.',
                        style: const TextStyle(fontSize: 12, color: teksRedup),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Daftar barang',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    for (final r in (p['item'] as List).cast<Json>())
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          r['nama_barang'].toString(),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${stokTampil({'stok': r['jumlah'], 'satuan': r['satuan']})} × ${hargaRupiah(r['harga_rupiah'])}',
                        ),
                        trailing: Text(
                          hargaRupiah(r['subtotal_rupiah']),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total pembayaran',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          hargaRupiah(p['total_rupiah']),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: hijauUtama,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (pesan != null) PesanGagal(pesan!),
            if (widget.toko) ...[
              const SizedBox(height: 16),
              if (status == 'Menunggu konfirmasi')
                FilledButton(
                  onPressed: sibuk
                      ? null
                      : () => jalankanAksi(
                          judulDialog: 'Konfirmasi pesanan?',
                          isiDialog:
                              'Stok produk akan dikurangi secara atomik setelah pesanan dikonfirmasi.',
                          aksi: () => widget.api.konfirmasiPesanan(widget.id),
                          pesanSukses: 'Pesanan dikonfirmasi dan stok dikurangi.',
                        ),
                  child: Text(sibuk ? 'Memproses…' : 'Konfirmasi pesanan'),
                ),
              if (status == 'Dikonfirmasi')
                FilledButton(
                  onPressed: sibuk
                      ? null
                      : () => jalankanAksi(
                          judulDialog: 'Tandai siap diambil?',
                          isiDialog:
                              'Pastikan seluruh barang pesanan telah disiapkan untuk diambil di kasir.',
                          aksi: () => widget.api.siapDiambilPesanan(widget.id),
                          pesanSukses: 'Pesanan ditandai Siap diambil.',
                        ),
                  child: Text(sibuk ? 'Memproses…' : 'Tandai siap diambil'),
                ),
              if ((status == 'Dikonfirmasi' || status == 'Siap diambil') &&
                  !lunas) ...[
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: sibuk
                      ? null
                      : () => jalankanAksi(
                          judulDialog: 'Verifikasi pembayaran?',
                          isiDialog: metode == 'Transfer bank'
                              ? 'Pastikan dana transfer telah benar-benar diterima di rekening toko.'
                              : 'Pastikan pembayaran tunai di kasir telah diterima penuh.',
                          aksi: () =>
                              widget.api.verifikasiPembayaranPesanan(widget.id),
                          pesanSukses: 'Pembayaran dicatat sebagai Sudah dibayar.',
                        ),
                  child: Text(
                    metode == 'Transfer bank'
                        ? 'Verifikasi transfer diterima'
                        : 'Catat pembayaran di kasir',
                  ),
                ),
              ],
              if (status == 'Siap diambil' && lunas) ...[
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: sibuk
                      ? null
                      : () => jalankanAksi(
                          judulDialog: 'Selesaikan pesanan?',
                          isiDialog:
                              'Pastikan barang telah diserahkan kepada pembeli di kasir.',
                          aksi: () => widget.api.selesaikanPesanan(widget.id),
                          pesanSukses: 'Pesanan selesai.',
                        ),
                  child: Text(sibuk ? 'Memproses…' : 'Selesaikan pesanan'),
                ),
              ],
            ],
          ],
        );
      },
    ),
  );
}
