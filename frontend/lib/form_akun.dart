import 'package:flutter/material.dart';

class FormAkun extends StatefulWidget {
  const FormAkun({
    super.key,
    required this.judul,
    required this.simpan,
    this.labelTombol = 'Simpan akun',
    this.labelSibuk = 'Menyimpan…',
  });
  final String judul;
  final Future<void> Function(String nama, String email, String sandi) simpan;
  final String labelTombol;
  final String labelSibuk;

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
      appBar: AppBar(title: Text(widget.judul)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: nama,
                    enabled: !sibuk,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Nama Lengkap',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 16),
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
                  const SizedBox(height: 16),
                  TextField(
                    controller: sandi,
                    enabled: !sibuk,
                    obscureText: sembunyikanSandi,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: 'Password',
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
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: sibuk ? null : kirim,
                    child: Text(sibuk ? widget.labelSibuk : widget.labelTombol),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
