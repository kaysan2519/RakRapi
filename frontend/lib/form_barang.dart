import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'api.dart';
import 'katalog.dart' show FotoPrivat, PesanGagal;
import 'theme/app_theme.dart';

const daftarSatuan = [
  'botol',
  'kg',
  'pcs',
  'bungkus',
  'pack',
  'sisir',
  'kotak',
  'lembar',
  'sachet',
];

Future<Json?> dialogKategori(
  BuildContext context,
  RakRapiApi api, {
  Json? kategori,
}) => showDialog<Json>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _DialogKategori(api: api, kategori: kategori),
);

class _DialogKategori extends StatefulWidget {
  const _DialogKategori({required this.api, this.kategori});
  final RakRapiApi api;
  final Json? kategori;
  @override
  State<_DialogKategori> createState() => _DialogKategoriState();
}

class _DialogKategoriState extends State<_DialogKategori> {
  late final nama = TextEditingController(text: widget.kategori?['nama']);
  bool sibuk = false;
  String? pesan;
  @override
  void dispose() {
    nama.dispose();
    super.dispose();
  }

  Future<void> simpan() async {
    if (sibuk) return;
    if (nama.text.trim().isEmpty) {
      setState(() => pesan = 'Isi nama kategori.');
      return;
    }
    setState(() {
      sibuk = true;
      pesan = null;
    });
    try {
      final id = widget.kategori?['id'] as int?;
      final nilai = nama.text.trim();
      final hasil = id == null
          ? await widget.api.tambahKategori(nilai)
          : await widget.api.ubahKategori(id, nilai);
      if (mounted) Navigator.pop(context, hasil);
    } catch (e) {
      if (mounted) {
        setState(() {
          pesan = e.toString();
          sibuk = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !sibuk,
    child: AlertDialog(
      title: Text(
        widget.kategori == null ? 'Tambah kategori' : 'Ubah kategori',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nama,
            autofocus: true,
            maxLength: 100,
            enabled: !sibuk,
            decoration: const InputDecoration(labelText: 'Nama kategori'),
            onSubmitted: (_) => simpan(),
          ),
          if (pesan != null) PesanGagal(pesan!),
        ],
      ),
      actions: [
        TextButton(
          onPressed: sibuk ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: sibuk ? null : simpan,
          child: Text(sibuk ? 'Menyimpan…' : 'Simpan'),
        ),
      ],
    ),
  );
}

class FormBarang extends StatefulWidget {
  const FormBarang({
    super.key,
    required this.api,
    required this.bolehTambahKategori,
    this.barang,
  });
  final RakRapiApi api;
  final bool bolehTambahKategori;
  final Json? barang;
  @override
  State<FormBarang> createState() => _FormBarangState();
}

class _FormBarangState extends State<FormBarang> {
  final nama = TextEditingController();
  final harga = TextEditingController();
  final stok = TextEditingController();
  final deskripsi = TextEditingController();
  List<Json> kategori = [];
  int? kategoriId;
  String satuan = 'pack';
  Uint8List? fotoBaru;
  String? pesan, masalahKategori;
  bool mengirim = false, memuatKategori = true, memilih = false;
  final _form = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final b = widget.barang;
    if (b != null) {
      nama.text = b['nama'] ?? '';
      harga.text = b['harga_rupiah'].toString();
      stok.text = stokTampil(b).split(' ').first;
      satuan = daftarSatuan.contains(b['satuan']) ? b['satuan'] : 'pack';
      kategoriId = b['kategori_id'];
      deskripsi.text = (b['deskripsi'] ?? '').toString();
    }
    muatKategori();
  }

  @override
  void dispose() {
    nama.dispose();
    harga.dispose();
    stok.dispose();
    deskripsi.dispose();
    super.dispose();
  }

  Future<void> muatKategori() async {
    setState(() {
      memuatKategori = true;
      masalahKategori = null;
    });
    try {
      final hasil = await widget.api.kategori();
      if (mounted) {
        setState(() {
          kategori = hasil;
          if (!kategori.any((k) => k['id'] == kategoriId)) kategoriId = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => masalahKategori = e.toString());
    } finally {
      if (mounted) setState(() => memuatKategori = false);
    }
  }

  Future<void> tambahKategori() async {
    final baru = await dialogKategori(context, widget.api);
    if (!mounted || baru == null) return;
    setState(() {
      kategori = [...kategori, baru];
      kategoriId = baru['id'];
    });
  }

  Future<void> pilihFoto() async {
    if (memilih || mengirim) return;
    setState(() {
      memilih = true;
      pesan = null;
    });
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (file == null) return;
      if (await file.length() > 5 * 1024 * 1024) {
        throw const KesalahanApi('Foto maksimal 5 MiB.');
      }
      final bytes = await file.readAsBytes();
      if (deteksiJenisGambar(bytes) == null) {
        throw const KesalahanApi('Pilih foto JPG, PNG, atau WebP.');
      }
      if (mounted) setState(() => fotoBaru = bytes);
    } catch (e) {
      if (mounted) setState(() => pesan = e.toString());
    } finally {
      if (mounted) setState(() => memilih = false);
    }
  }

  String? periksaStok(String? value) {
    final jumlah = (value ?? '').trim().replaceAll(',', '.');
    if (!RegExp(r'^\d{1,9}(\.\d{1,3})?$').hasMatch(jumlah)) {
      return 'Isi stok 0 atau lebih, maksimal tiga desimal.';
    }
    if (satuan != 'kg' && double.parse(jumlah) % 1 != 0) {
      return 'Jumlah untuk satuan $satuan harus bilangan bulat.';
    }
    return null;
  }

  Future<void> simpan() async {
    if (mengirim || memilih) return;
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    if (widget.barang == null && fotoBaru == null) {
      setState(() => pesan = 'Pilih foto barang terlebih dahulu.');
      return;
    }
    setState(() {
      mengirim = true;
      pesan = null;
    });
    try {
      final lama = widget.barang;
      final isian = {
        if (lama == null || nama.text.trim() != lama['nama'])
          'nama': nama.text.trim(),
        if (lama == null || kategoriId != lama['kategori_id'])
          'kategori_id': kategoriId.toString(),
        if (lama == null ||
            int.tryParse(harga.text.trim()) != lama['harga_rupiah'])
          'harga_rupiah': harga.text.trim(),
        if (lama == null ||
            stok.text.trim() != stokTampil(lama).split(' ').first)
          'stok': stok.text.trim(),
        if (lama == null || satuan != lama['satuan']) 'satuan': satuan,
        if (lama == null ||
            deskripsi.text.trim() != (lama['deskripsi'] ?? '').toString())
          'deskripsi': deskripsi.text.trim(),
      };
      if (isian.isEmpty && fotoBaru == null) {
        Navigator.pop(context, lama!['id']);
        return;
      }
      final id = await widget.api.simpanBarang(
        isian,
        id: widget.barang?['id'],
        gambar: fotoBaru,
      );
      if (mounted) Navigator.pop(context, id);
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
    final b = widget.barang;
    return PopScope(
      canPop: !mengirim,
      child: Scaffold(
        appBar: AppBar(
          title: Text(b == null ? 'Tambah produk' : 'Edit produk'),
        ),
        body: SafeArea(
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: hijauLembut,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.inventory_2_outlined, color: hijauUtama),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              b == null
                                  ? 'Lengkapi informasi produk'
                                  : 'Perbarui informasi produk',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Harga berlaku per satuan. Foto lama tetap aman saat hanya mengubah teks.',
                              style: TextStyle(fontSize: 12, color: teksRedup),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                TextFormField(
                  controller: nama,
                  enabled: !mengirim,
                  decoration: const InputDecoration(labelText: 'Nama produk'),
                  validator: (value) {
                    final namaBarang = (value ?? '').trim();
                    if (namaBarang.isEmpty || namaBarang.runes.length > 150) {
                      return 'Isi nama produk, maksimal 150 karakter.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<int>(
                  key: ValueKey(kategoriId),
                  initialValue: kategoriId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Kategori'),
                  items: kategori
                      .map(
                        (k) => DropdownMenuItem<int>(
                          value: k['id'],
                          child: Text(k['nama']),
                        ),
                      )
                      .toList(),
                  onChanged: mengirim || memuatKategori
                      ? null
                      : (v) => setState(() => kategoriId = v),
                  validator: (v) => v == null ? 'Pilih kategori produk.' : null,
                ),
                if (memuatKategori) const LinearProgressIndicator(),
                if (masalahKategori != null)
                  PesanGagal(masalahKategori!, ulangi: muatKategori),
                if (widget.bolehTambahKategori)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: mengirim || memuatKategori
                          ? null
                          : tambahKategori,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Tambah kategori'),
                    ),
                  )
                else
                  const SizedBox(height: 14),
                TextFormField(
                  controller: harga,
                  enabled: !mengirim,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Harga per satuan (Rp)',
                    prefixText: 'Rp ',
                  ),
                  validator: (v) {
                    final angka = (v ?? '').trim();
                    final rupiah = int.tryParse(angka);
                    if (!RegExp(r'^\d+$').hasMatch(angka) ||
                        rupiah == null ||
                        rupiah < 1 ||
                        rupiah > 4294967295) {
                      return 'Isi harga bulat lebih dari Rp0.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: stok,
                        enabled: !mengirim,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(labelText: 'Stok'),
                        validator: periksaStok,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: satuan,
                        decoration: const InputDecoration(labelText: 'Satuan'),
                        items: daftarSatuan
                            .map(
                              (s) => DropdownMenuItem(value: s, child: Text(s)),
                            )
                            .toList(),
                        onChanged: mengirim
                            ? null
                            : (v) => setState(() => satuan = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: deskripsi,
                  enabled: !mengirim,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Deskripsi produk (opsional)',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: memilih || mengirim ? null : pilihFoto,
                  icon: const Icon(Icons.photo_outlined),
                  label: Text(
                    b != null || fotoBaru != null ? 'Ganti foto' : 'Pilih foto',
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'JPG, PNG, atau WebP · maksimal 5 MB',
                    style: TextStyle(fontSize: 12, color: teksRedup),
                  ),
                ),
                if (fotoBaru != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.memory(
                      fotoBaru!,
                      height: 170,
                      cacheHeight: 480,
                      fit: BoxFit.contain,
                      semanticLabel: 'Pratinjau foto',
                    ),
                  )
                else if (b != null)
                  FotoPrivat(api: widget.api, id: b['id']),
                if (pesan != null) PesanGagal(pesan!),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: mengirim || memilih || memuatKategori
                      ? null
                      : simpan,
                  child: Text(mengirim ? 'Menyimpan…' : 'Simpan produk'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
