import 'dart:math';
import 'package:flutter/material.dart';
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
  if (nilai == 0 || (satuan == 'botol' && nilai % 1000 != 0)) return null;
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
  String get kunciKirim => _kunci ??= List.generate(
    16,
    (_) => _acak.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  final _acak = Random.secure();

  void atur(Json barang, int jumlah) {
    _kunci = null;
    if (jumlah == 0) {
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
      IconButton(
        tooltip: 'Kurangi jumlah',
        onPressed: () => langkah(-1000),
        icon: const Icon(Icons.remove),
      ),
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
            return satuan == 'botol'
                ? 'Isi jumlah botol bulat lebih dari nol.'
                : 'Isi kg lebih dari nol, maksimal tiga angka pecahan.';
          },
        ),
      ),
      IconButton(
        tooltip: 'Tambah jumlah',
        onPressed: () => langkah(1000),
        icon: const Icon(Icons.add),
      ),
    ],
  );
}

class LayarKeranjang extends StatefulWidget {
  const LayarKeranjang({super.key, required this.api, required this.keranjang});
  final RakRapiApi api;
  final Keranjang keranjang;
  @override
  State<LayarKeranjang> createState() => _LayarKeranjangState();
}

class _LayarKeranjangState extends State<LayarKeranjang> {
  bool mengirim = false;
  String? pesan;
  Future<void> ubah(ItemKeranjang item) async {
    final jumlah = await showDialog<int>(
      context: context,
      builder: (_) => _UbahJumlah(item: item),
    );
    if (mounted && jumlah != null) {
      setState(() => widget.keranjang.atur(item.barang, jumlah));
    }
  }

  Future<void> kirim() async {
    if (mengirim || widget.keranjang.item.isEmpty) return;
    setState(() {
      mengirim = true;
      pesan = null;
    });
    try {
      final keranjang = widget.keranjang;
      final data = await widget.api.kirimPesanan(keranjang.kunciKirim, [
        for (final i in keranjang.item.values)
          {
            'barang_id': i.barang['id'],
            'satuan': i.barang['satuan'],
            'jumlah': teksJumlah(i.jumlah),
          },
      ]);
      keranjang.kosongkan();
      if (mounted) Navigator.pop(context, data['id'] as int);
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
    final item = widget.keranjang.item.values;
    final total = item.fold(BigInt.zero, (s, i) => s + i.subtotal);
    return PopScope(
      canPop: !mengirim,
      child: Scaffold(
        appBar: AppBar(title: const Text('Keranjang')),
        body: item.isEmpty
            ? const Center(
                child: KeadaanKosong(
                  ikon: Icons.shopping_bag_outlined,
                  judul: 'Keranjang masih kosong.',
                  penjelasan:
                      'Pilih barang dari katalog untuk mulai berbelanja.',
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final i in item)
                    Padding(
                      key: ValueKey(i.barang['id']),
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  SizedBox(
                                    width: 64,
                                    height: 70,
                                    child: FotoPrivat(
                                      api: widget.api,
                                      id: i.barang['id'],
                                      mini: true,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      i.barang['nama'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                hargaRupiah(i.barang['harga_rupiah']),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                '${teksJumlah(i.jumlah)} ${i.barang['satuan']} × ${hargaRupiah(i.barang['harga_rupiah'])}',
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Subtotal ${hargaRupiah(i.subtotal)}',
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Ubah jumlah ${i.barang['nama']}',
                                    onPressed: mengirim ? null : () => ubah(i),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                  IconButton(
                                    tooltip: 'Hapus ${i.barang['nama']}',
                                    onPressed: mengirim
                                        ? null
                                        : () => setState(
                                            () => widget.keranjang.atur(
                                              i.barang,
                                              0,
                                            ),
                                          ),
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: hijauLembut,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Wrap(
                      spacing: 20,
                      runSpacing: 8,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        const Text('Total belanja'),
                        Text(
                          hargaRupiah(total),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (pesan != null) PesanGagal(pesan!),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: mengirim ? null : kirim,
                    child: Text(mengirim ? 'Mengirim…' : 'Kirim pesanan'),
                  ),
                ],
              ),
      ),
    );
  }
}

class _UbahJumlah extends StatefulWidget {
  const _UbahJumlah({required this.item});
  final ItemKeranjang item;
  @override
  State<_UbahJumlah> createState() => _UbahJumlahState();
}

class _UbahJumlahState extends State<_UbahJumlah> {
  late final jumlah = TextEditingController(
    text: teksJumlah(widget.item.jumlah),
  );
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    jumlah.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.item.barang['nama']),
    content: Form(
      key: form,
      child: IsianJumlah(
        controller: jumlah,
        satuan: widget.item.barang['satuan'],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Batal'),
      ),
      FilledButton(
        onPressed: () {
          if (form.currentState!.validate()) {
            Navigator.pop(
              context,
              jumlahPerseribu(jumlah.text, widget.item.barang['satuan']),
            );
          }
        },
        child: const Text('Simpan'),
      ),
    ],
  );
}
