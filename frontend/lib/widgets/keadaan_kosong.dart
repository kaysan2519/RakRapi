import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// Dipakai saat API belum mempunyai data, bukan diganti dengan data contoh.
class KeadaanKosong extends StatelessWidget {
  const KeadaanKosong({
    super.key,
    required this.ikon,
    required this.judul,
    required this.penjelasan,
  });
  final IconData ikon;
  final String judul;
  final String penjelasan;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 36,
          backgroundColor: hijauLembut,
          child: Icon(ikon, size: 32, color: hijauUtama),
        ),
        const SizedBox(height: 20),
        Text(
          judul,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(penjelasan, textAlign: TextAlign.center),
      ],
    ),
  );
}
