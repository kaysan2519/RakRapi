import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'api.dart';
import 'katalog.dart' show PesanGagal;
import 'theme/app_theme.dart';
import 'widgets/keadaan_kosong.dart';

enum JenisLayanan { lowongan, bansos, pengumuman }

class LayarLayananInfo extends StatefulWidget {
  const LayarLayananInfo({
    super.key,
    required this.api,
    required this.jenis,
    required this.pemilik,
    this.namaPengguna = '',
  });
  final RakRapiApi api;
  final JenisLayanan jenis;
  final bool pemilik;
  final String namaPengguna;

  @override
  State<LayarLayananInfo> createState() => _LayarLayananInfoState();
}

class _LayarLayananInfoState extends State<LayarLayananInfo> {
  late Future<(List<Json>, List<Json>)> _future;
  bool sibuk = false;

  String get _judulHalaman => switch (widget.jenis) {
    JenisLayanan.lowongan => widget.pemilik ? 'Kelola lowongan' : 'Lowongan kerja',
    JenisLayanan.bansos => widget.pemilik ? 'Kelola bansos' : 'Bantuan sosial',
    JenisLayanan.pengumuman =>
      widget.pemilik ? 'Kelola pengumuman' : 'Pengumuman & promo',
  };

  String get _subjudul => switch (widget.jenis) {
    JenisLayanan.lowongan => 'Temukan kesempatan kerja di toko RakRapi.',
    JenisLayanan.bansos =>
      'Lihat program bantuan sosial (demo), persyaratan, dan status pengajuan.',
    JenisLayanan.pengumuman =>
      'Informasi terbaru dan pengumuman promo toko. Info diskon tidak mengubah harga katalog.',
  };

  @override
  void initState() {
    super.initState();
    _future = _muat();
  }

  Future<(List<Json>, List<Json>)> _muat() async {
    switch (widget.jenis) {
      case JenisLayanan.lowongan:
        final items = await widget.api.lowongan();
        final pengajuan = widget.pemilik
            ? await widget.api.semuaLamaran()
            : await widget.api.lamaranSaya();
        return (items, pengajuan);
      case JenisLayanan.bansos:
        final items = await widget.api.daftarBansos();
        final pengajuan = widget.pemilik
            ? await widget.api.semuaPengajuanBansos()
            : await widget.api.pengajuanBansosSaya();
        return (items, pengajuan);
      case JenisLayanan.pengumuman:
        final items = await widget.api.daftarPengumuman();
        return (items, <Json>[]);
    }
  }

  void muatUlang() {
    setState(() {
      _future = _muat();
    });
  }

  Future<void> bukaForm({Json? data, String? jenisPengumumanAwal}) async {
    final simpan = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => FormLayananInfo(
          api: widget.api,
          jenis: widget.jenis,
          data: data,
          jenisPengumumanAwal: jenisPengumumanAwal,
        ),
      ),
    );
    if (mounted && simpan == true) {
      muatUlang();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Informasi berhasil disimpan.')));
    }
  }

  Future<void> togglePin(Json item) async {
    if (sibuk) return;
    final baru = !(item['is_pinned'] == true);
    setState(() => sibuk = true);
    try {
      switch (widget.jenis) {
        case JenisLayanan.lowongan:
          await widget.api.pinLowongan(item['id'] as int, baru);
        case JenisLayanan.bansos:
          await widget.api.pinBansos(item['id'] as int, baru);
        case JenisLayanan.pengumuman:
          await widget.api.pinPengumuman(item['id'] as int, baru);
      }
      if (mounted) {
        muatUlang();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              baru
                  ? 'Informasi dipin ke beranda pembeli.'
                  : 'Pin dilepas dari beranda pembeli.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => sibuk = false);
    }
  }

  Future<void> hapusItem(Json item) async {
    final nama = (item['judul'] ?? item['nama'] ?? '').toString();
    final yakin = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus “$nama”?'),
        content: const Text('Data yang dihapus tidak dapat dikembalikan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: merahPeringatan),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (!mounted || yakin != true) return;
    setState(() => sibuk = true);
    try {
      switch (widget.jenis) {
        case JenisLayanan.lowongan:
          await widget.api.hapusLowongan(item['id'] as int);
        case JenisLayanan.bansos:
          await widget.api.hapusBansos(item['id'] as int);
        case JenisLayanan.pengumuman:
          await widget.api.hapusPengumuman(item['id'] as int);
      }
      if (mounted) {
        muatUlang();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('“$nama” dihapus.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => sibuk = false);
    }
  }

  Future<void> bukaFormAjukan(Json item) async {
    final dikirim = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => FormAjukanWarga(
          api: widget.api,
          jenis: widget.jenis,
          item: item,
          namaAwal: widget.namaPengguna,
        ),
      ),
    );
    if (mounted && dikirim == true) {
      muatUlang();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pengajuan dikirim. Status: Menunggu verifikasi.'),
        ),
      );
    }
  }

  Future<void> tinjauPengajuan(Json p, String statusBaru) async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$statusBaru pengajuan?'),
        content: Text(
          'Pemohon: ${p['nama_pelamar'] ?? p['nama_pemohon'] ?? ''}\nKeputusan akan terlihat pada akun pembeli.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(statusBaru),
          ),
        ],
      ),
    );
    if (!mounted || yakin != true) return;
    setState(() => sibuk = true);
    try {
      if (widget.jenis == JenisLayanan.lowongan) {
        await widget.api.tinjauLamaran(p['id'] as int, statusBaru);
      } else {
        await widget.api.tinjauPengajuanBansos(p['id'] as int, statusBaru);
      }
      if (mounted) {
        muatUlang();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Pengajuan ditandai $statusBaru.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => sibuk = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_judulHalaman),
      actions: [
        IconButton(
          tooltip: 'Muat ulang',
          onPressed: muatUlang,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<(List<Json>, List<Json>)>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: PesanGagal(snap.error.toString(), ulangi: muatUlang),
          );
        }
        final (daftar, daftarPengajuan) = snap.requireData;
        return RefreshIndicator(
          onRefresh: () async {
            muatUlang();
            try {
              await _future;
            } on KesalahanApi {
              // Kesalahan ditampilkan melalui PesanGagal.
            }
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(_subjudul, style: const TextStyle(color: teksRedup)),
              const SizedBox(height: 14),
              if (widget.pemilik) ...[
                FilledButton.icon(
                  onPressed: () => bukaForm(),
                  icon: const Icon(Icons.add),
                  label: Text(
                    switch (widget.jenis) {
                      JenisLayanan.lowongan => 'Tambah lowongan',
                      JenisLayanan.bansos => 'Tambah program bansos',
                      JenisLayanan.pengumuman => 'Tambah pengumuman / diskon',
                    },
                  ),
                ),
                const SizedBox(height: 14),
              ],
              if (daftar.isEmpty)
                KeadaanKosong(
                  ikon: switch (widget.jenis) {
                    JenisLayanan.lowongan => Icons.work_outline,
                    JenisLayanan.bansos => Icons.volunteer_activism_outlined,
                    JenisLayanan.pengumuman => Icons.campaign_outlined,
                  },
                  judul: 'Belum ada data',
                  penjelasan:
                      'Informasi dari toko akan tampil di sini setelah ditambahkan.',
                )
              else
                for (final item in daftar)
                  _kartuItem(item, daftarPengajuan),
              if (widget.pemilik && widget.jenis != JenisLayanan.pengumuman) ...[
                const SizedBox(height: 16),
                Text(
                  widget.jenis == JenisLayanan.lowongan
                      ? 'Lamaran masuk (${daftarPengajuan.length})'
                      : 'Pengajuan bansos masuk (${daftarPengajuan.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 10),
                if (daftarPengajuan.isEmpty)
                  const Text(
                    'Belum ada pengajuan masuk.',
                    style: TextStyle(color: teksRedup),
                  )
                else
                  for (final p in daftarPengajuan) _kartuPengajuanPemilik(p),
              ],
            ],
          ),
        );
      },
    ),
  );

  Widget _kartuItem(Json item, List<Json> pengajuan) {
    final id = item['id'] as int;
    final judul = (item['judul'] ?? item['nama'] ?? '').toString();
    final deskripsi = (item['deskripsi'] ?? '').toString();
    final persyaratan = (item['persyaratan'] ?? '').toString();
    final fotoUrl = item['foto_url']?.toString();
    final dipin = item['is_pinned'] == true;
    final aktif = item['aktif'] != false;

    final meta = switch (widget.jenis) {
      JenisLayanan.lowongan =>
        (item['info_tambahan'] ?? item['lokasi'] ?? 'Toko RakRapi').toString(),
      JenisLayanan.bansos =>
        '${item['jenis_bantuan'] ?? 'Bantuan sosial'} · Sisa kuota ${item['sisa_kuota'] ?? item['kuota']}/${item['kuota']}',
      JenisLayanan.pengumuman =>
        (item['info_tambahan'] ?? item['jenis'] ?? 'Pengumuman').toString(),
    };

    Json? pengajuanSaya;
    if (!widget.pemilik && widget.jenis != JenisLayanan.pengumuman) {
      final kunciFk =
          widget.jenis == JenisLayanan.lowongan ? 'lowongan_id' : 'program_id';
      for (final p in pengajuan) {
        if (p[kunciFk] == id) {
          pengajuanSaya = p;
          break;
        }
      }
    }

    final kuotaPenuh =
        widget.jenis == JenisLayanan.bansos &&
        ((item['sisa_kuota'] as int?) ?? 1) <= 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (fotoUrl != null && fotoUrl.isNotEmpty)
              FotoUrlPrivat(
                api: widget.api,
                fotoUrl: fotoUrl,
                tinggi: 170,
                fit: BoxFit.cover,
                radius: 0,
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (dipin)
                        const BadgeLabel(
                          'Dipin',
                          latar: hijauUtama,
                          warnaTeks: Colors.white,
                        ),
                      if (widget.jenis == JenisLayanan.pengumuman &&
                          item['jenis'] != null)
                        BadgeLabel(item['jenis'].toString()),
                      if (!aktif)
                        const BadgeLabel(
                          'Ditutup',
                          latar: latarPeringatan,
                          warnaTeks: merahPeringatan,
                        ),
                      if (meta.isNotEmpty) BadgeLabel(meta),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    judul,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (deskripsi.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      deskripsi,
                      style: const TextStyle(color: teksRedup, height: 1.45),
                    ),
                  ],
                  if (persyaratan.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Persyaratan: $persyaratan',
                      style: const TextStyle(fontSize: 12, color: teksRedup),
                    ),
                  ],
                  if (widget.jenis == JenisLayanan.bansos) ...[
                    const SizedBox(height: 6),
                    const Text(
                      'Program bansos demo — verifikasi manual oleh pemilik toko, tidak menjamin penerimaan.',
                      style: TextStyle(fontSize: 11, color: teksRedup),
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (!widget.pemilik &&
                      widget.jenis != JenisLayanan.pengumuman) ...[
                    if (pengajuanSaya != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: hijauLembut,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Status pengajuan Anda: ${pengajuanSaya['status']}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: hijauUtama,
                          ),
                        ),
                      )
                    else
                      OutlinedButton(
                        onPressed: (!aktif || kuotaPenuh)
                            ? null
                            : () => bukaFormAjukan(item),
                        child: Text(
                          !aktif
                              ? 'Sudah ditutup'
                              : kuotaPenuh
                              ? 'Kuota penuh'
                              : widget.jenis == JenisLayanan.lowongan
                              ? 'Ajukan lamaran'
                              : 'Ajukan bantuan',
                        ),
                      ),
                  ],
                  if (widget.pemilik)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: sibuk ? null : () => togglePin(item),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: dipin ? hijauUtama : Colors.white,
                            foregroundColor: dipin ? Colors.white : hijauUtama,
                          ),
                          icon: Icon(
                            dipin ? Icons.push_pin : Icons.push_pin_outlined,
                            size: 16,
                          ),
                          label: Text(dipin ? 'Lepas pin' : 'Pin ke beranda'),
                        ),
                        OutlinedButton(
                          onPressed: sibuk ? null : () => bukaForm(data: item),
                          child: const Text('Edit / foto'),
                        ),
                        TextButton(
                          onPressed: sibuk ? null : () => hapusItem(item),
                          style: TextButton.styleFrom(
                            foregroundColor: merahPeringatan,
                          ),
                          child: const Text('Hapus'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kartuPengajuanPemilik(Json p) {
    final status = p['status'].toString();
    final menunggu = status == 'Menunggu verifikasi';
    final judulProgram =
        (p['judul_lowongan'] ?? p['nama_program'] ?? '').toString();
    final namaPemohon =
        (p['nama_pelamar'] ?? p['nama_pemohon'] ?? '').toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      judulProgram,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  BadgeLabel(
                    status,
                    latar: status == 'Disetujui'
                        ? hijauLembut
                        : status == 'Ditolak'
                        ? latarPeringatan
                        : latarKuning,
                    warnaTeks: status == 'Disetujui'
                        ? hijauUtama
                        : status == 'Ditolak'
                        ? merahPeringatan
                        : kuningStatus,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '$namaPemohon (${p['email_warga'] ?? ''})',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                (p['keterangan'] ?? '').toString(),
                style: const TextStyle(fontSize: 12, color: teksRedup),
              ),
              if (menunggu) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: sibuk
                            ? null
                            : () => tinjauPengajuan(p, 'Disetujui'),
                        child: const Text('Setujui'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: merahPeringatan,
                          side: const BorderSide(color: merahPeringatan),
                        ),
                        onPressed: sibuk
                            ? null
                            : () => tinjauPengajuan(p, 'Ditolak'),
                        child: const Text('Tolak'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class FormAjukanWarga extends StatefulWidget {
  const FormAjukanWarga({
    super.key,
    required this.api,
    required this.jenis,
    required this.item,
    required this.namaAwal,
  });
  final RakRapiApi api;
  final JenisLayanan jenis;
  final Json item;
  final String namaAwal;

  @override
  State<FormAjukanWarga> createState() => _FormAjukanWargaState();
}

class _FormAjukanWargaState extends State<FormAjukanWarga> {
  late final nama = TextEditingController(text: widget.namaAwal);
  final keterangan = TextEditingController();
  bool mengirim = false;
  String? pesan;

  @override
  void dispose() {
    nama.dispose();
    keterangan.dispose();
    super.dispose();
  }

  Future<void> kirim() async {
    if (mengirim) return;
    if (nama.text.trim().isEmpty || keterangan.text.trim().isEmpty) {
      setState(() => pesan = 'Lengkapi nama dan keterangan pengajuan.');
      return;
    }
    setState(() {
      mengirim = true;
      pesan = null;
    });
    try {
      final id = widget.item['id'] as int;
      if (widget.jenis == JenisLayanan.lowongan) {
        await widget.api.ajukanLamaran(
          id,
          nama.text.trim(),
          keterangan.text.trim(),
        );
      } else {
        await widget.api.ajukanBansos(
          id,
          nama.text.trim(),
          keterangan.text.trim(),
        );
      }
      if (mounted) Navigator.pop(context, true);
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
    final isLow = widget.jenis == JenisLayanan.lowongan;
    final judulItem = (widget.item['judul'] ?? widget.item['nama']).toString();
    return Scaffold(
      appBar: AppBar(
        title: Text(isLow ? 'Ajukan lamaran' : 'Ajukan bantuan sosial'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    judulItem,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    (widget.item['deskripsi'] ?? '').toString(),
                    style: const TextStyle(fontSize: 13, color: teksRedup),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: nama,
            enabled: !mengirim,
            decoration: InputDecoration(
              labelText: isLow ? 'Nama pelamar' : 'Nama pemohon',
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: keterangan,
            enabled: !mengirim,
            maxLines: 4,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: 'Alasan / keterangan',
              hintText:
                  'Tuliskan keterangan singkat (tidak perlu memasukkan NIK atau dokumen sensitif).',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: hijauLembut,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Pengajuan akan diverifikasi manual oleh pemilik toko. Jangan memasukkan NIK atau data pribadi sensitif.',
              style: TextStyle(fontSize: 12, color: hijauTua),
            ),
          ),
          if (pesan != null) PesanGagal(pesan!),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: mengirim ? null : kirim,
            child: Text(mengirim ? 'Mengirim…' : 'Kirim pengajuan'),
          ),
        ],
      ),
    );
  }
}

class FormLayananInfo extends StatefulWidget {
  const FormLayananInfo({
    super.key,
    required this.api,
    required this.jenis,
    this.data,
    this.jenisPengumumanAwal,
  });
  final RakRapiApi api;
  final JenisLayanan jenis;
  final Json? data;
  final String? jenisPengumumanAwal;

  @override
  State<FormLayananInfo> createState() => _FormLayananInfoState();
}

class _FormLayananInfoState extends State<FormLayananInfo> {
  late final judul = TextEditingController(
    text: (widget.data?['judul'] ?? widget.data?['nama'] ?? '').toString(),
  );
  late final deskripsi = TextEditingController(
    text: (widget.data?['deskripsi'] ?? '').toString(),
  );
  late final syarat = TextEditingController(
    text: (widget.data?['persyaratan'] ?? '').toString(),
  );
  late final tambahan = TextEditingController(
    text: (widget.data?['info_tambahan'] ??
            widget.data?['jenis_bantuan'] ??
            '')
        .toString(),
  );
  late final lokasi = TextEditingController(
    text: (widget.data?['lokasi'] ?? 'Toko RakRapi').toString(),
  );
  late final kuota = TextEditingController(
    text: (widget.data?['kuota'] ?? 20).toString(),
  );
  late String jenisPengumuman =
      widget.data?['jenis']?.toString() ??
      widget.jenisPengumumanAwal ??
      'Pengumuman';
  late bool aktif = widget.data?['aktif'] != false;
  late bool dipin = widget.data?['is_pinned'] == true;
  Uint8List? fotoBaru;
  bool hapusFotoLama = false;
  bool sibuk = false;
  String? pesan;

  @override
  void dispose() {
    judul.dispose();
    deskripsi.dispose();
    syarat.dispose();
    tambahan.dispose();
    lokasi.dispose();
    kuota.dispose();
    super.dispose();
  }

  Future<void> pilihFoto() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return;
    if (await file.length() > 5 * 1024 * 1024) {
      setState(() => pesan = 'Foto maksimal 5 MB.');
      return;
    }
    final bytes = await file.readAsBytes();
    if (deteksiJenisGambar(bytes) == null) {
      setState(() => pesan = 'Pilih JPG, PNG, atau WebP maksimal 5 MB.');
      return;
    }
    setState(() {
      fotoBaru = bytes;
      hapusFotoLama = false;
      pesan = null;
    });
  }

  Future<void> simpan({bool paksaPin = false}) async {
    if (sibuk) return;
    if (judul.text.trim().isEmpty) {
      setState(() => pesan = 'Judul / nama wajib diisi.');
      return;
    }
    final statusPin = paksaPin ? true : dipin;
    setState(() {
      sibuk = true;
      pesan = null;
    });
    try {
      final id = widget.data?['id'] as int?;
      final fields = <String, String>{
        'deskripsi': deskripsi.text.trim(),
        'aktif': aktif.toString(),
        'is_pinned': statusPin.toString(),
        if (hapusFotoLama) 'hapus_foto': 'true',
      };
      switch (widget.jenis) {
        case JenisLayanan.lowongan:
          fields['judul'] = judul.text.trim();
          fields['persyaratan'] = syarat.text.trim();
          fields['lokasi'] = lokasi.text.trim();
          fields['info_tambahan'] = tambahan.text.trim();
          await widget.api.simpanLowongan(fields, id: id, gambar: fotoBaru);
        case JenisLayanan.bansos:
          fields['nama'] = judul.text.trim();
          fields['jenis_bantuan'] = tambahan.text.trim();
          fields['persyaratan'] = syarat.text.trim();
          fields['kuota'] = kuota.text.trim();
          await widget.api.simpanBansos(fields, id: id, gambar: fotoBaru);
        case JenisLayanan.pengumuman:
          fields['judul'] = judul.text.trim();
          fields['jenis'] = jenisPengumuman;
          fields['info_tambahan'] = tambahan.text.trim();
          await widget.api.simpanPengumuman(fields, id: id, gambar: fotoBaru);
      }
      if (mounted) Navigator.pop(context, true);
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
  Widget build(BuildContext context) {
    final edit = widget.data != null;
    final fotoUrlLama = widget.data?['foto_url']?.toString();
    final judulLayar = switch (widget.jenis) {
      JenisLayanan.lowongan => edit ? 'Edit lowongan' : 'Tambah lowongan',
      JenisLayanan.bansos => edit ? 'Edit program bansos' : 'Tambah program bansos',
      JenisLayanan.pengumuman =>
        edit ? 'Edit pengumuman' : 'Tambah pengumuman / diskon',
    };

    return Scaffold(
      appBar: AppBar(title: Text(judulLayar)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: judul,
            enabled: !sibuk,
            decoration: InputDecoration(
              labelText: widget.jenis == JenisLayanan.bansos
                  ? 'Nama program'
                  : 'Judul informasi',
            ),
          ),
          const SizedBox(height: 12),
          if (widget.jenis == JenisLayanan.pengumuman) ...[
            DropdownButtonFormField<String>(
              initialValue: jenisPengumuman,
              decoration: const InputDecoration(labelText: 'Jenis informasi'),
              items: const [
                DropdownMenuItem(value: 'Pengumuman', child: Text('Pengumuman')),
                DropdownMenuItem(value: 'Diskon', child: Text('Diskon / Promo')),
                DropdownMenuItem(
                  value: 'Informasi toko',
                  child: Text('Informasi toko'),
                ),
              ],
              onChanged: sibuk
                  ? null
                  : (v) => setState(() => jenisPengumuman = v ?? 'Pengumuman'),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: deskripsi,
            enabled: !sibuk,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Deskripsi / keterangan',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: tambahan,
            enabled: !sibuk,
            decoration: InputDecoration(
              labelText: widget.jenis == JenisLayanan.bansos
                  ? 'Jenis bantuan'
                  : 'Informasi singkat (label)',
            ),
          ),
          if (widget.jenis == JenisLayanan.lowongan) ...[
            const SizedBox(height: 12),
            TextField(
              controller: lokasi,
              enabled: !sibuk,
              decoration: const InputDecoration(labelText: 'Lokasi kerja'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: syarat,
              enabled: !sibuk,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Persyaratan'),
            ),
          ],
          if (widget.jenis == JenisLayanan.bansos) ...[
            const SizedBox(height: 12),
            TextField(
              controller: kuota,
              enabled: !sibuk,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Kuota penerima'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: syarat,
              enabled: !sibuk,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Persyaratan'),
            ),
          ],
          const SizedBox(height: 14),
          const Text(
            'Foto atau poster (opsional)',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: sibuk ? null : pilihFoto,
                icon: const Icon(Icons.photo_outlined, size: 18),
                label: Text(
                  fotoBaru != null || (!hapusFotoLama && fotoUrlLama != null)
                      ? 'Ganti foto'
                      : 'Unggah foto',
                ),
              ),
              if (fotoBaru != null || (!hapusFotoLama && fotoUrlLama != null))
                TextButton(
                  onPressed: sibuk
                      ? null
                      : () => setState(() {
                          fotoBaru = null;
                          hapusFotoLama = true;
                        }),
                  style: TextButton.styleFrom(foregroundColor: merahPeringatan),
                  child: const Text('Hapus foto'),
                ),
            ],
          ),
          const Text(
            'JPG, PNG, WebP · maks. 5 MB',
            style: TextStyle(fontSize: 12, color: teksRedup),
          ),
          const SizedBox(height: 8),
          if (fotoBaru != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.memory(fotoBaru!, height: 160, fit: BoxFit.cover),
            )
          else if (!hapusFotoLama && fotoUrlLama != null && fotoUrlLama.isNotEmpty)
            FotoUrlPrivat(
              api: widget.api,
              fotoUrl: fotoUrlLama,
              tinggi: 160,
              fit: BoxFit.cover,
            ),
          const SizedBox(height: 10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Status aktif / dipublikasikan'),
            value: aktif,
            onChanged: sibuk ? null : (v) => setState(() => aktif = v),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Tampilkan di bagian atas beranda pembeli (pin)'),
            value: dipin,
            onChanged: sibuk ? null : (v) => setState(() => dipin = v ?? false),
          ),
          if (pesan != null) PesanGagal(pesan!),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: sibuk ? null : () => simpan(paksaPin: false),
            child: Text(sibuk ? 'Menyimpan…' : 'Simpan'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: sibuk ? null : () => simpan(paksaPin: true),
            child: const Text('Simpan & pin ke beranda'),
          ),
        ],
      ),
    );
  }
}

class LayarPinPrioritas extends StatefulWidget {
  const LayarPinPrioritas({super.key, required this.api});
  final RakRapiApi api;

  @override
  State<LayarPinPrioritas> createState() => _LayarPinPrioritasState();
}

class _LayarPinPrioritasState extends State<LayarPinPrioritas> {
  late Future<List<Json>> _future = widget.api.daftarPin(semua: true);
  String filterJenis = 'Semua';
  bool sibuk = false;

  void muat() {
    setState(() {
      _future = widget.api.daftarPin(semua: true);
    });
  }

  Future<void> buatBaru(JenisLayanan jenis, {String? jenisPengumuman}) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => FormLayananInfo(
          api: widget.api,
          jenis: jenis,
          jenisPengumumanAwal: jenisPengumuman,
        ),
      ),
    );
    if (mounted && ok == true) muat();
  }

  Future<void> togglePin(Json item) async {
    if (sibuk) return;
    final baru = !(item['is_pinned'] == true);
    final id = item['id'] as int;
    setState(() => sibuk = true);
    try {
      switch (item['sumber']) {
        case 'lowongan':
          await widget.api.pinLowongan(id, baru);
        case 'bansos':
          await widget.api.pinBansos(id, baru);
        default:
          await widget.api.pinPengumuman(id, baru);
      }
      if (mounted) {
        muat();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              baru
                  ? 'Info dipin ke beranda pembeli.'
                  : 'Pin dilepas dari beranda pembeli.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => sibuk = false);
    }
  }

  Future<void> bukaEdit(Json item) async {
    final jenis = switch (item['sumber']) {
      'lowongan' => JenisLayanan.lowongan,
      'bansos' => JenisLayanan.bansos,
      _ => JenisLayanan.pengumuman,
    };
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            LayarLayananInfo(api: widget.api, jenis: jenis, pemilik: true),
      ),
    );
    if (mounted) muat();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Pin informasi ke beranda'),
      actions: [
        IconButton(
          tooltip: 'Muat ulang',
          onPressed: muat,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<List<Json>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: PesanGagal(snap.error.toString(), ulangi: muat));
        }
        final semua = snap.requireData;
        final jumlahPin = semua.where((x) => x['is_pinned'] == true).length;
        final terlihat = semua
            .where((x) => filterJenis == 'Semua' || x['jenis'] == filterJenis)
            .toList();

        return RefreshIndicator(
          onRefresh: () async {
            muat();
            try {
              await _future;
            } on KesalahanApi {
              // Kesalahan ditampilkan melalui PesanGagal.
            }
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Tekan Pin ke beranda pada informasi yang sudah ada, atau buat informasi baru dengan foto lalu pilih Simpan & pin ke beranda.',
                style: TextStyle(color: teksRedup, height: 1.4),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$jumlahPin informasi sedang dipin',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Perubahan tersimpan di database dan tampil di atas beranda pembeli.',
                        style: TextStyle(fontSize: 12, color: teksRedup),
                      ),
                      const SizedBox(height: 12),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 2.3,
                        children: [
                          _tombolBuat(
                            '+ Lowongan',
                            'Buat info baru',
                            () => buatBaru(JenisLayanan.lowongan),
                          ),
                          _tombolBuat(
                            '+ Diskon',
                            'Buat promo baru',
                            () => buatBaru(
                              JenisLayanan.pengumuman,
                              jenisPengumuman: 'Diskon',
                            ),
                          ),
                          _tombolBuat(
                            '+ Bansos',
                            'Buat program baru',
                            () => buatBaru(JenisLayanan.bansos),
                          ),
                          _tombolBuat(
                            '+ Pengumuman',
                            'Buat info baru',
                            () => buatBaru(
                              JenisLayanan.pengumuman,
                              jenisPengumuman: 'Pengumuman',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final k in const [
                      'Semua',
                      'Lowongan',
                      'Diskon',
                      'Bansos',
                      'Pengumuman',
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(k),
                          selected: filterJenis == k,
                          showCheckmark: false,
                          labelStyle: TextStyle(
                            color: filterJenis == k ? Colors.white : hijauTua,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                          onSelected: (_) => setState(() => filterJenis = k),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (terlihat.isEmpty)
                const KeadaanKosong(
                  ikon: Icons.push_pin_outlined,
                  judul: 'Belum ada informasi',
                  penjelasan: 'Buat informasi baru dari tombol di atas untuk dipin.',
                )
              else
                for (final item in terlihat)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (item['foto_url'] != null)
                            FotoUrlPrivat(
                              api: widget.api,
                              fotoUrl: item['foto_url'].toString(),
                              tinggi: 150,
                              fit: BoxFit.cover,
                              radius: 0,
                            ),
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 6,
                                  children: [
                                    BadgeLabel(item['jenis'].toString()),
                                    if (item['is_pinned'] == true)
                                      const BadgeLabel(
                                        'Dipin',
                                        latar: hijauUtama,
                                        warnaTeks: Colors.white,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  item['judul'].toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  (item['deskripsi'] ?? '').toString(),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: teksRedup,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    FilledButton.tonalIcon(
                                      style: FilledButton.styleFrom(
                                        backgroundColor:
                                            item['is_pinned'] == true
                                            ? hijauUtama
                                            : hijauLembut,
                                        foregroundColor:
                                            item['is_pinned'] == true
                                            ? Colors.white
                                            : hijauUtama,
                                      ),
                                      onPressed: sibuk
                                          ? null
                                          : () => togglePin(item),
                                      icon: Icon(
                                        item['is_pinned'] == true
                                            ? Icons.push_pin
                                            : Icons.push_pin_outlined,
                                        size: 16,
                                      ),
                                      label: Text(
                                        item['is_pinned'] == true
                                            ? 'Lepas pin'
                                            : 'Pin ke beranda',
                                      ),
                                    ),
                                    OutlinedButton(
                                      onPressed: () => bukaEdit(item),
                                      child: const Text('Kelola / foto'),
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
            ],
          ),
        );
      },
    ),
  );

  Widget _tombolBuat(String judul, String sub, VoidCallback onTap) => InkWell(
    borderRadius: BorderRadius.circular(12),
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: latarAplikasi,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: garisKartu),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            judul,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: hijauTua,
            ),
          ),
          Text(
            sub,
            style: const TextStyle(fontSize: 11, color: teksRedup),
          ),
        ],
      ),
    ),
  );
}
