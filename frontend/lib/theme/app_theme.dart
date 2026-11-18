import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Ubah palet di sini agar semua layar tetap konsisten.
const hijauUtama = Color(0xFF122B22);
const hijauLembut = Color(0xFFE8EFEA);
const latarAplikasi = Color(0xFFF6F6F3);
const garisKartu = Color(0xFFE2E5DF);

ThemeData temaRakRapi() {
  // Font disertakan dalam APK; layar masuk tidak perlu internet untuk font.
  GoogleFonts.config.allowRuntimeFetching = false;
  final dasar = ThemeData(useMaterial3: true);
  final bentuk = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(18),
  );
  return dasar.copyWith(
    colorScheme: ColorScheme.fromSeed(
      seedColor: hijauUtama,
      primary: hijauUtama,
      secondary: hijauLembut,
      surface: latarAplikasi,
    ),
    scaffoldBackgroundColor: latarAplikasi,
    textTheme: GoogleFonts.plusJakartaSansTextTheme(dasar.textTheme).apply(
      fontFamily: 'PlusJakartaSans',
      bodyColor: const Color(0xFF19221D),
      displayColor: const Color(0xFF19221D),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: latarAplikasi,
      foregroundColor: hijauUtama,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 19,
        fontWeight: FontWeight.w700,
        color: hijauUtama,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: garisKartu),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: hijauUtama,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 52),
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
        foregroundColor: hijauUtama,
        minimumSize: const Size(48, 48),
        shape: bentuk,
        side: const BorderSide(color: garisKartu),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: garisKartu),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: hijauUtama,
      side: const BorderSide(color: garisKartu),
      shape: const StadiumBorder(),
      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      height: 72,
      backgroundColor: Colors.white,
      indicatorColor: hijauLembut,
      surfaceTintColor: Colors.transparent,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    dividerTheme: const DividerThemeData(color: garisKartu),
  );
}
