import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api.dart';
import 'katalog.dart';
import 'theme/app_theme.dart';
import 'widgets/keadaan_kosong.dart';

int? jumlahPerseribu(String input, String satuan) {
  final teks = input.trim().replaceAll(',', '.');
  if (!RegExp(r'^\d{1,9}(\.\d{1,3})?$').hasMatch(teks)) return null;
  final bagian = teks.split('.');
  final pecahan = bagian.length == 2 ? bagian[1] : '';
  final nilai = int.parse(bagian.first + pecahan.padRight(3, '0'));
  if (nilai == 0 || (satuan != 'kg' && nilai % 1000 != 0)) return null;
  return nilai;
}

String teksJumlah(int nilai) {
  final pecahan = (nilai % 1000)
      .toString()
      .padLeft(3, '0')
      .replaceFirst(RegExp(r'0+$'), '');
  return pecahan.isEmpty ? '${nilai ~/ 1000}' : '${nilai ~/ 1000},$pecahan';
}

class ItemKeranjang {
  ItemKeranjang(this.barang, this.jumlah);
  final Json barang;
  final int jumlah;
  BigInt get subtotal =>
      (BigInt.from(barang['harga_rupiah']) * BigInt.from(jumlah) +
          BigInt.from(500)) ~/
      BigInt.from(1000);
}

class Keranjang {
  final item = <int, ItemKeranjang>{};
  String? _kunci;
  final _acak = Random.secure();

  String get kunciKirim => _kunci ??= List.generate(
    16,
    (_) => _acak.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();

  int get totalItemJenis => item.length;

  BigInt get totalRupiah =>
      item.values.fold(BigInt.zero, (s, i) => s + i.subtotal);

  void atur(Json barang, int jumlah) {
    _kunci = null;
    if (jumlah <= 0) {
      item.remove(barang['id']);
    } else {
      item[barang['id']] = ItemKeranjang(barang, jumlah);
    }
  }

  void kosongkan() {
    _kunci = null;
    item.clear();
  }
}

class IsianJumlah extends StatelessWidget {
  const IsianJumlah({
    super.key,
    required this.controller,
    required this.satuan,
  });
  final TextEditingController controller;
  final String satuan;

  void langkah(int perubahan) {
    final sekarang = jumlahPerseribu(controller.text, satuan);
    if (sekarang == null) return;
    final berikutnya = sekarang + perubahan;
    if (berikutnya <= 0 || berikutnya > 999999999999) return;
    controller.text = teksJumlah(berikutnya);
  }

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      IconButton.outlined(
        tooltip: 'Kurangi jumlah',
        onPressed: () => langkah(-1000),
        icon: const Icon(Icons.remove),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: TextFormField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(
            decimal: satuan == 'kg',
          ),
          textAlign: TextAlign.center,
          decoration: InputDecoration(labelText: 'Jumlah', suffixText: satuan),
          validator: (teks) {
            if (jumlahPerseribu(teks ?? '', satuan) != null) return null;
            return satuan != 'kg'
                ? 'Isi jumlah $satuan bulat lebih dari nol.'
                : 'Isi kg lebih dari nol, maksimal tiga angka pecahan.';
          },
        ),
      ),
      const SizedBox(width: 8),
      IconButton.outlined(
        tooltip: 'Tambah jumlah',
        onPressed: () => langkah(1000),
        icon: const Icon(Icons.add),
      ),
    ],
  );
}

class LayarKeranjang extends StatefulWidget {
  const LayarKeranjang({
    super.key,
    required this.api,
    required this.keranjang,
    this.onMulaiBelanja,
    this.onPesananSelesaiBuat,
    this.onBerubah,
  });
  final RakRapiApi api;
  final Keranjang keranjang;
  final VoidCallback? onMulaiBelanja;
  final void Function(Json pesanan)? onPesananSelesaiBuat;
  final VoidCallback? onBerubah;

  @override
  State<LayarKeranjang> createState() => _LayarKeranjangState();
}

class _LayarKeranjangState extends State<LayarKeranjang> {
  void ubahLangkah(ItemKeranjang i, int delta) {
    final stokMaks =
        jumlahPerseribu(i.barang['stok'].toString(), i.barang['satuan']) ?? 0;
    final baru = i.jumlah + delta;
    if (baru > stokMaks && stokMaks > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jumlah melebihi stok tersedia.')),
      );
      return;
    }
    setState(() => widget.keranjang.atur(i.barang, baru));
    widget.onBerubah?.call();
  }

  Future<void> bukaCheckout() async {
    final pesanan = await Navigator.push<Json>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            LayarCheckout(api: widget.api, keranjang: widget.keranjang),
      ),
    );
    if (!mounted) return;
    widget.onBerubah?.call();
    setState(() {});
    if (pesanan != null) {
      if (widget.onPesananSelesaiBuat != null) {
        widget.onPesananSelesaiBuat!(pesanan);
      } else {
        Navigator.pop(context, pesanan['id'] as int);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final daftarItem = widget.keranjang.item.values.toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Keranjang')),
      body: daftarItem.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const KeadaanKosong(
                      ikon: Icons.shopping_bag_outlined,
                      judul: 'Keranjang masih kosong',
                      penjelasan:
                          'Pilih kebutuhan harian Anda dari katalog untuk mulai berbelanja.',
                    ),
                    if (widget.onMulaiBelanja != null)
                      FilledButton(
                        onPressed: widget.onMulaiBelanja,
                        child: const Text('Mulai belanja'),
                      ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Periksa barang sebelum melanjutkan ke checkout.',
                  style: TextStyle(color: teksRedup),
                ),
                const SizedBox(height: 14),
                for (final i in daftarItem)
                  Padding(
                    key: ValueKey(i.barang['id']),
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            FotoUrlPrivat(
                              api: widget.api,
                              fotoUrl:
                                  (i.barang['foto_url'] ??
                                          '/api/barang/${i.barang['id']}/foto')
                                      .toString(),
                              lebar: 68,
                              tinggi: 68,
                              fit: BoxFit.contain,
                              radius: 12,
                              mini: true,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    i.barang['nama'].toString(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    hargaRupiah(i.subtotal),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: hijauUtama,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      _tombolKecil(
                                        Icons.remove,
                                        () => ubahLangkah(i, -1000),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                        ),
                                        child: Text(
                                          '${teksJumlah(i.jumlah)} ${i.barang['satuan']}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      _tombolKecil(
                                        Icons.add,
                                        () => ubahLangkah(i, 1000),
                                      ),
                                      const Spacer(),
                                      IconButton(
                                        tooltip: 'Hapus',
                                        onPressed: () {
                                          setState(
                                            () => widget.keranjang.atur(
                                              i.barang,
                                              0,
                                            ),
                                          );
                                          widget.onBerubah?.call();
                                        },
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: merahPeringatan,
                                          size: 20,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total belanja',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          hargaRupiah(widget.keranjang.totalRupiah),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: hijauUtama,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: bukaCheckout,
                  child: const Text('Lanjut checkout'),
                ),
              ],
            ),
    );
  }

  Widget _tombolKecil(IconData ikon, VoidCallback onTap) => InkWell(
    borderRadius: BorderRadius.circular(8),
    onTap: onTap,
    child: Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: latarAplikasi,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: garisKartu),
      ),
      child: Icon(ikon, size: 16, color: hijauTua),
    ),
  );
}

class LayarCheckout extends StatefulWidget {
  const LayarCheckout({
    super.key,
    required this.api,
    required this.keranjang,
  });
  final RakRapiApi api;
  final Keranjang keranjang;

  @override
  State<LayarCheckout> createState() => _LayarCheckoutState();
}

class _LayarCheckoutState extends State<LayarCheckout> {
  String metode = 'Bayar di kasir';
  Json? infoToko;
  bool memuatToko = true;
  bool mengirim = false;
  String? pesan;

  @override
  void initState() {
    super.initState();
    _muatToko();
  }

  Future<void> _muatToko() async {
    try {
      final d = await widget.api.infoToko();
      if (mounted) setState(() => infoToko = d);
    } catch (_) {
      // Tetap lanjut dengan Bayar di kasir jika info toko belum dimuat.
    } finally {
      if (mounted) setState(() => memuatToko = false);
    }
  }

  Future<void> buatPesanan() async {
    if (mengirim || widget.keranjang.item.isEmpty) return;
    setState(() {
      mengirim = true;
      pesan = null;
    });
    try {
      final keranjang = widget.keranjang;
      final data = await widget.api.kirimPesanan(
        keranjang.kunciKirim,
        [
          for (final i in keranjang.item.values)
            {
              'barang_id': i.barang['id'],
              'satuan': i.barang['satuan'],
              'jumlah': teksJumlah(i.jumlah).replaceAll(',', '.'),
            },
        ],
        metodePembayaran: metode,
      );
      keranjang.kosongkan();
      if (!mounted) return;
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LayarPesananBerhasil(pesanan: data),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          pesan = e.toString();
          mengirim = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.keranjang.item.values.toList();
    final rekeningTersedia = infoToko?['rekening_tersedia'] == true;

    return PopScope(
      canPop: !mengirim,
      child: Scaffold(
        appBar: AppBar(title: const Text('Checkout')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Pesanan hanya dapat diambil di kasir toko.',
              style: TextStyle(color: teksRedup),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '1. Pengambilan pesanan',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.radio_button_checked,
                          color: hijauUtama,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Ambil di kasir',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                (infoToko?['info_pengambilan'] ??
                                        'Datang setelah status pesanan Siap diambil, tunjukkan nomor pesanan.')
                                    .toString(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: teksRedup,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
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
                      '2. Metode pembayaran',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    _pilihanBayar(
                      judul: 'Bayar di kasir',
                      sub: 'Bayar tunai saat mengambil pesanan di kasir.',
                      dipilih: metode == 'Bayar di kasir',
                      aktif: !mengirim,
                      onTap: () => setState(() => metode = 'Bayar di kasir'),
                    ),
                    const SizedBox(height: 10),
                    _pilihanBayar(
                      judul: 'Transfer bank',
                      sub: rekeningTersedia
                          ? 'Transfer ke rekening toko setelah pesanan dikonfirmasi, lalu tunjukkan bukti transfer di kasir.'
                          : 'Pembayaran transfer belum tersedia karena rekening toko belum dikonfigurasi pemilik.',
                      dipilih: metode == 'Transfer bank',
                      aktif: !mengirim && rekeningTersedia,
                      onTap: () => setState(() => metode = 'Transfer bank'),
                    ),
                    if (memuatToko)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: LinearProgressIndicator(),
                      ),
                    if (rekeningTersedia && metode == 'Transfer bank') ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: latarAplikasi,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: garisKartu),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bank: ${infoToko!['nama_bank']}',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    infoToko!['nomor_rekening'].toString(),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () {
                                    Clipboard.setData(
                                      ClipboardData(
                                        text: infoToko!['nomor_rekening']
                                            .toString(),
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
                              style: const TextStyle(
                                fontSize: 12,
                                color: teksRedup,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
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
                      '3. Ringkasan pesanan',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    for (final i in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${i.barang['nama']} × ${teksJumlah(i.jumlah)} ${i.barang['satuan']}',
                              ),
                            ),
                            Text(
                              hargaRupiah(i.subtotal),
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          hargaRupiah(widget.keranjang.totalRupiah),
                          style: const TextStyle(
                            fontSize: 20,
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
            const SizedBox(height: 10),
            const Text(
              'Total dihitung ulang oleh server berdasarkan harga aktual database. Pembayaran diverifikasi oleh pegawai/pemilik toko.',
              style: TextStyle(fontSize: 12, color: teksRedup),
            ),
            if (pesan != null) PesanGagal(pesan!),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: mengirim ? null : buatPesanan,
              child: Text(mengirim ? 'Membuat pesanan…' : 'Buat pesanan'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pilihanBayar({
    required String judul,
    required String sub,
    required bool dipilih,
    required bool aktif,
    required VoidCallback onTap,
  }) => InkWell(
    borderRadius: BorderRadius.circular(12),
    onTap: aktif ? onTap : null,
    child: Opacity(
      opacity: aktif ? 1 : 0.55,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: dipilih ? hijauLembut : latarAplikasi,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: dipilih ? hijauUtama : garisKartu,
            width: dipilih ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              dipilih
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              color: dipilih ? hijauUtama : teksRedup,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    judul,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    style: const TextStyle(fontSize: 12, color: teksRedup),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class LayarPesananBerhasil extends StatelessWidget {
  const LayarPesananBerhasil({super.key, required this.pesanan});
  final Json pesanan;

  @override
  Widget build(BuildContext context) {
    final kode =
        (pesanan['kode_pesanan'] ?? 'RR-${pesanan['id']}').toString();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(
                    child: CircleAvatar(
                      radius: 38,
                      backgroundColor: hijauLembut,
                      child: Icon(Icons.check, size: 38, color: hijauUtama),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Pesanan dibuat',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pesanan $kode sedang menunggu konfirmasi pegawai. Status pembayaran: ${pesanan['status_pembayaran'] ?? 'Belum dibayar'}. Ambil pesanan di kasir setelah status Siap diambil.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: teksRedup, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, pesanan),
                    child: const Text('Lihat pesanan saya'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
