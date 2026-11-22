import 'package:flutter/material.dart';

import 'theme/app_theme.dart';

class FormAkun extends StatefulWidget {
  const FormAkun({
    super.key,
    required this.judul,
    required this.simpan,
    this.subjudul,
    this.labelTombol = 'Simpan akun',
    this.labelSibuk = 'Menyimpan…',
    this.modeDaftar = false,
  });
  final String judul;
  final String? subjudul;
  final Future<void> Function(String nama, String email, String sandi) simpan;
  final String labelTombol;
  final String labelSibuk;
  final bool modeDaftar;

  @override
  State<FormAkun> createState() => _FormAkunState();
}

class _FormAkunState extends State<FormAkun> {
  final nama = TextEditingController();
  final email = TextEditingController();
  final sandi = TextEditingController();
  bool sibuk = false;
  bool sembunyikanSandi = true;
  String? pesan;

  @override
  void dispose() {
    nama.dispose();
    email.dispose();
    sandi.dispose();
    super.dispose();
  }

  Future<void> kirim() async {
    if (sibuk) return;
    FocusScope.of(context).unfocus();
    if (nama.text.trim().isEmpty ||
        email.text.trim().isEmpty ||
        sandi.text.length < 8) {
      setState(
        () => pesan = 'Isi nama lengkap, email, dan password minimal 8 karakter.',
      );
      return;
    }
    setState(() {
      sibuk = true;
      pesan = null;
    });
    try {
      await widget.simpan(nama.text.trim(), email.text.trim(), sandi.text);
      if (mounted) Navigator.pop(context, email.text.trim());
    } catch (error) {
      if (mounted) {
        setState(() {
          pesan = error.toString();
          sibuk = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !sibuk,
    child: Scaffold(
      appBar: widget.modeDaftar
          ? AppBar(
              leading: IconButton(
                tooltip: 'Kembali',
                onPressed: sibuk ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
              ),
            )
          : AppBar(title: Text(widget.judul)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.modeDaftar) ...[
                    const Center(child: LogoRakRapi(besar: true)),
                    const SizedBox(height: 18),
                    Text(
                      widget.judul,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.subjudul ??
                          'Buat akun untuk mulai menggunakan RakRapi.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: teksRedup),
                    ),
                    const SizedBox(height: 24),
                  ] else if (widget.subjudul != null) ...[
                    Text(
                      widget.subjudul!,
                      style: const TextStyle(color: teksRedup),
                    ),
                    const SizedBox(height: 18),
                  ],
                  TextField(
                    controller: nama,
                    enabled: !sibuk,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Nama Lengkap',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: email,
                    enabled: !sibuk,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.mail_outline),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: sandi,
                    enabled: !sibuk,
                    obscureText: sembunyikanSandi,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      helperText: 'Minimal 8 karakter',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        tooltip: sembunyikanSandi
                            ? 'Tampilkan password'
                            : 'Sembunyikan password',
                        onPressed: () => setState(
                          () => sembunyikanSandi = !sembunyikanSandi,
                        ),
                        icon: Icon(
                          sembunyikanSandi
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    onSubmitted: (_) => kirim(),
                  ),
                  if (pesan != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        pesan!,
                        style: const TextStyle(color: merahPeringatan),
                      ),
                    ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: sibuk ? null : kirim,
                    child: Text(sibuk ? widget.labelSibuk : widget.labelTombol),
                  ),
                  if (widget.modeDaftar) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          'Sudah punya akun? ',
                          style: TextStyle(color: teksRedup),
                        ),
                        TextButton(
                          onPressed: sibuk ? null : () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Masuk'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
