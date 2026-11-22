import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../api.dart';

// Palet warna sesuai Prototype V3 RakRapi.
const hijauTua = Color(0xFF112B21);
const hijauUtama = Color(0xFF0D4935);
const teksRedup = Color(0xFF63736B);
const garisKartu = Color(0xFFE1E5DF);
const latarAplikasi = Color(0xFFF6F5F0);
const hijauLembut = Color(0xFFE6EEE4);
const latarGambar = Color(0xFFECEEE7);
const merahPeringatan = Color(0xFFA43F32);
const latarPeringatan = Color(0xFFF7E8E3);
const kuningStatus = Color(0xFF8A5A00);
const latarKuning = Color(0xFFFFF3D6);

ThemeData temaRakRapi() {
  // Font lokal disertakan dalam APK sehingga tetap stabil tanpa internet.
  GoogleFonts.config.allowRuntimeFetching = false;
  final dasar = ThemeData(useMaterial3: true);
  final bentuk = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(14),
  );
  return dasar.copyWith(
    colorScheme: ColorScheme.fromSeed(
      seedColor: hijauUtama,
      primary: hijauUtama,
      onPrimary: Colors.white,
      secondary: hijauLembut,
      onSecondary: hijauTua,
      surface: latarAplikasi,
      onSurface: hijauTua,
      error: merahPeringatan,
    ),
    scaffoldBackgroundColor: latarAplikasi,
    textTheme: GoogleFonts.plusJakartaSansTextTheme(dasar.textTheme).apply(
      fontFamily: 'PlusJakartaSans',
      bodyColor: hijauTua,
      displayColor: hijauTua,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: latarAplikasi,
      foregroundColor: hijauTua,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: hijauTua,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: garisKartu),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: hijauUtama,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 48),
        shape: bentuk,
        textStyle: const TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: hijauTua,
        backgroundColor: Colors.white,
        minimumSize: const Size(48, 46),
        shape: bentuk,
        side: const BorderSide(color: garisKartu),
        textStyle: const TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: hijauUtama,
        textStyle: const TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: garisKartu),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: garisKartu),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: hijauUtama, width: 1.5),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: hijauUtama,
      side: const BorderSide(color: garisKartu),
      shape: const StadiumBorder(),
      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
      labelStyle: const TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      backgroundColor: Colors.white,
      indicatorColor: hijauLembut,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w800
              : FontWeight.w600,
          color: states.contains(WidgetState.selected) ? hijauUtama : teksRedup,
        ),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    dividerTheme: const DividerThemeData(color: garisKartu),
  );
}

class LogoRakRapi extends StatelessWidget {
  const LogoRakRapi({super.key, this.besar = false});
  final bool besar;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(
        Icons.storefront_outlined,
        size: besar ? 32 : 22,
        color: hijauUtama,
      ),
      const SizedBox(width: 8),
      Text(
        'RakRapi',
        style: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: besar ? 28 : 19,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          color: hijauTua,
        ),
      ),
    ],
  );
}

class BadgeLabel extends StatelessWidget {
  const BadgeLabel(
    this.teks, {
    super.key,
    this.latar = hijauLembut,
    this.warnaTeks = hijauUtama,
  });
  final String teks;
  final Color latar;
  final Color warnaTeks;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: latar,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      teks,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: warnaTeks,
      ),
    ),
  );
}

class FotoUrlPrivat extends StatefulWidget {
  const FotoUrlPrivat({
    super.key,
    required this.api,
    required this.fotoUrl,
    this.tinggi = 160,
    this.lebar,
    this.fit = BoxFit.cover,
    this.radius = 14,
    this.mini = false,
  });
  final RakRapiApi api;
  final String fotoUrl;
  final double? tinggi;
  final double? lebar;
  final BoxFit fit;
  final double radius;
  final bool mini;

  @override
  State<FotoUrlPrivat> createState() => _FotoUrlPrivatState();
}

class _FotoUrlPrivatState extends State<FotoUrlPrivat> {
  late Future<Uint8List> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.fotoDariPath(widget.fotoUrl);
  }

  @override
  void didUpdateWidget(covariant FotoUrlPrivat oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fotoUrl != widget.fotoUrl) {
      _future = widget.api.fotoDariPath(widget.fotoUrl);
    }
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(widget.radius),
    child: Container(
      height: widget.tinggi,
      width: widget.lebar ?? double.infinity,
      color: latarGambar,
      child: FutureBuilder<Uint8List>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            if (widget.mini) {
              return const Center(
                child: Icon(Icons.broken_image_outlined, color: teksRedup),
              );
            }
            return Center(
              child: TextButton.icon(
                onPressed: () => setState(() {
                  widget.api.hapusCacheFoto(widget.fotoUrl);
                  _future = widget.api.fotoDariPath(widget.fotoUrl);
                }),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Muat foto'),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }
          return Image.memory(
            snap.requireData,
            fit: widget.fit,
            cacheWidth: widget.mini ? 240 : 900,
            errorBuilder: (_, _, _) => const Center(
              child: Icon(Icons.broken_image_outlined, color: teksRedup),
            ),
          );
        },
      ),
    ),
  );
}
