import 'package:flutter/material.dart';
import 'api.dart';
import 'katalog.dart';
import 'theme/app_theme.dart';
import 'widgets/keadaan_kosong.dart';

class DaftarPesanan extends StatefulWidget {
  const DaftarPesanan({super.key, required this.api, required this.toko});
  final RakRapiApi api;
  final bool toko;
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
      title: Text(widget.toko ? 'Pesanan masuk' : 'Pesanan saya'),
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
        if (hasil.hasError) {
          return Center(
            child: PesanGagal(hasil.error.toString(), ulangi: muat),
          );
        }
        if (!hasil.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (hasil.requireData.isEmpty) {
          return const Center(
            child: KeadaanKosong(
              ikon: Icons.receipt_long_outlined,
              judul: 'Belum ada pesanan.',
              penjelasan:
                  'Pesanan yang dikirim melalui keranjang akan muncul di sini.',
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: hasil.requireData.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (_, i) {
            final p = hasil.requireData[i];
            return Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => buka(p['id']),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          Text(
                            'Pesanan #${p['id']}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: p['status'] == 'Dikonfirmasi'
                                  ? hijauLembut
                                  : const Color(0xFFFFF0D2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              p['status'],
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      if (widget.toko) ...[
                        const SizedBox(height: 8),
                        Text(p['nama_pemesan']),
                      ],
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              hargaRupiah(p['total_rupiah']),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ),
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
  bool sibuk = false;
  String? pesan;
  void muat() {
    setState(() {
      detail = widget.api.detailPesanan(widget.id);
      pesan = null;
    });
  }

  Future<void> konfirmasi() async {
    if (sibuk) return;
    setState(() {
      sibuk = true;
      pesan = null;
    });
    try {
      final data = await widget.api.konfirmasiPesanan(widget.id);
      if (mounted) {
        setState(() {
          detail = Future.value(data);
        });
      }
    } catch (e) {
      if (mounted) setState(() => pesan = e.toString());
    } finally {
      if (mounted) setState(() => sibuk = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Pesanan #${widget.id}')),
    body: FutureBuilder<Json>(
      future: detail,
      builder: (context, hasil) {
        if (hasil.hasError) {
          return Center(
            child: PesanGagal(hasil.error.toString(), ulangi: muat),
          );
        }
        if (!hasil.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final p = hasil.requireData;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(p['status'], style: Theme.of(context).textTheme.titleLarge),
            if (widget.toko) Text('Pemesan: ${p['nama_pemesan']}'),
            const SizedBox(height: 16),
            for (final r in (p['item'] as List).cast<Json>())
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(r['nama_barang']),
                subtitle: Text(
                  '${stokTampil({'stok': r['jumlah'], 'satuan': r['satuan']})} × ${hargaRupiah(r['harga_rupiah'])}',
                ),
                trailing: Text(hargaRupiah(r['subtotal_rupiah'])),
              ),
            const Divider(),
            Text(
              'Total ${hargaRupiah(p['total_rupiah'])}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (pesan != null) PesanGagal(pesan!),
            if (widget.toko && p['status'] == 'Menunggu konfirmasi') ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: sibuk ? null : konfirmasi,
                child: Text(sibuk ? 'Memproses…' : 'Konfirmasi pesanan'),
              ),
            ],
          ],
        );
      },
    ),
  );
}
