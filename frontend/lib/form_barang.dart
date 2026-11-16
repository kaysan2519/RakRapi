import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'api.dart';
import 'katalog.dart' show FotoPrivat, PesanGagal;

Future<Json?> dialogKategori(BuildContext context, RakRapiApi api) =>
    showDialog<Json>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DialogKategori(api: api),
    );

class _DialogKategori extends StatefulWidget {
  const _DialogKategori({required this.api});
  final RakRapiApi api;
  @override
  State<_DialogKategori> createState() => _DialogKategoriState();
}

class _DialogKategoriState extends State<_DialogKategori> {
  final nama = TextEditingController();
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
      final hasil = await widget.api.tambahKategori(nama.text.trim());
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
      title: const Text('Tambah kategori'),
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
  const FormBarang({super.key, required this.api, this.barang});
  final RakRapiApi api;
  final Json? barang;
  @override
  State<FormBarang> createState() => _FormBarangState();
}

class _FormBarangState extends State<FormBarang> {
  final nama = TextEditingController();
  final harga = TextEditingController();
  final stok = TextEditingController();
  List<Json> kategori = [];
  int? kategoriId;
  String satuan = 'botol';
  Uint8List? fotoBaru;
  String? pesan, masalahKategori;
  bool mengirim = false, memuatKategori = true, memilih = false;
  final _form = GlobalKey<FormState>();
  @override
  void initState() {
    super.initState();
    final b = widget.barang;
    if (b != null) {
      nama.text = b['nama'];
      harga.text = b['harga_rupiah'].toString();
      stok.text = stokTampil(b).split(' ').first;
      satuan = b['satuan'];
      kategoriId = b['kategori_id'];
    }
    muatKategori();
  }

  @override
  void dispose() {
    nama.dispose();
    harga.dispose();
    stok.dispose();
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
    if (satuan == 'botol' && double.parse(jumlah) % 1 != 0) {
      return 'Jumlah botol harus bulat.';
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
      final id = await widget.api.simpanBarang(
        {
          'nama': nama.text.trim(),
          'kategori_id': kategoriId.toString(),
          'harga_rupiah': harga.text.trim(),
          'stok': stok.text.trim(),
          'satuan': satuan,
        },
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
          title: Text(b == null ? 'Tambah barang' : 'Ubah barang'),
        ),
        body: SafeArea(
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: nama,
                  enabled: !mengirim,
                  decoration: const InputDecoration(labelText: 'Nama barang'),
                  validator: (value) {
                    final namaBarang = (value ?? '').trim();
                    if (namaBarang.isEmpty || namaBarang.runes.length > 150) {
                      return 'Isi nama, maksimal 150 karakter.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
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
                  validator: (v) =>
                      v == null ? 'Pilih atau tambahkan kategori.' : null,
                ),
                if (memuatKategori) const LinearProgressIndicator(),
                if (masalahKategori != null)
                  PesanGagal(masalahKategori!, ulangi: muatKategori),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: mengirim || memuatKategori
                        ? null
                        : tambahKategori,
                    icon: const Icon(Icons.add),
                    label: const Text('Tambah kategori'),
                  ),
                ),
                TextFormField(
                  controller: harga,
                  enabled: !mengirim,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Harga per satuan',
                    prefixText: 'Rp ',
                  ),
                  validator: (v) {
                    final angka = (v ?? '').trim();
                    final rupiah = int.tryParse(angka);
                    if (!RegExp(r'^\d+$').hasMatch(angka) ||
                        rupiah == null ||
                        rupiah > 4294967295) {
                      return 'Isi harga dalam rupiah bulat.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
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
                        items: ['botol', 'kg']
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
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: memilih || mengirim ? null : pilihFoto,
                  icon: const Icon(Icons.photo_outlined),
                  label: Text(
                    b != null || fotoBaru != null ? 'Ganti foto' : 'Pilih foto',
                  ),
                ),
                if (fotoBaru != null)
                  Image.memory(
                    fotoBaru!,
                    height: 160,
                    cacheHeight: 480,
                    fit: BoxFit.contain,
                    semanticLabel: 'Pratinjau foto',
                    errorBuilder: (_, _, _) => const Text(
                      'Foto tidak dapat dibaca. Pilih JPEG atau PNG.',
                    ),
                  )
                else if (b != null)
                  FotoPrivat(api: widget.api, id: b['id']),
                if (pesan != null) PesanGagal(pesan!),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: mengirim || memilih || memuatKategori
                      ? null
                      : simpan,
                  child: Text(mengirim ? 'Menyimpan…' : 'Simpan'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
