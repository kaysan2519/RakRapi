import 'package:flutter/material.dart';

class FormAkun extends StatefulWidget {
  const FormAkun({super.key, required this.judul, required this.simpan});
  final String judul;
  final Future<void> Function(String nama, String email, String sandi) simpan;

  @override
  State<FormAkun> createState() => _FormAkunState();
}

class _FormAkunState extends State<FormAkun> {
  final nama = TextEditingController();
  final email = TextEditingController();
  final sandi = TextEditingController();
  bool sibuk = false;
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
      setState(() => pesan = 'Isi nama, email, dan sandi minimal 8 karakter.');
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
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextField(
              controller: nama,
              enabled: !sibuk,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Nama'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: email,
              enabled: !sibuk,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: sandi,
              enabled: !sibuk,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(labelText: 'Sandi'),
              onSubmitted: (_) => kirim(),
            ),
            if (pesan != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  pesan!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: sibuk ? null : kirim,
              child: Text(sibuk ? 'Menyimpan…' : 'Simpan akun'),
            ),
          ],
        ),
      ),
    ),
  );
}
