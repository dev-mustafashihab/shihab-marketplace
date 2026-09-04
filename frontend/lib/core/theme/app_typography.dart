import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Typography — حسب المواصفة:
/// عربي: Cairo (Tajawal بديل) — إنجليزي/أرقام: Inter (Montserrat بديل)
class AppText {
  AppText._();

  static TextStyle displayL(Color c) => GoogleFonts.cairo(fontSize: 32, height: 40 / 32, fontWeight: FontWeight.w700, color: c);
  static TextStyle headingL(Color c) => GoogleFonts.cairo(fontSize: 24, height: 32 / 24, fontWeight: FontWeight.w700, color: c);
  static TextStyle headingM(Color c) => GoogleFonts.cairo(fontSize: 20, height: 28 / 20, fontWeight: FontWeight.w600, color: c);
  static TextStyle headingS(Color c) => GoogleFonts.cairo(fontSize: 17, height: 24 / 17, fontWeight: FontWeight.w600, color: c);
  static TextStyle bodyL(Color c) => GoogleFonts.cairo(fontSize: 16, height: 26 / 16, fontWeight: FontWeight.w400, color: c);
  static TextStyle bodyM(Color c) => GoogleFonts.cairo(fontSize: 14, height: 22 / 14, fontWeight: FontWeight.w400, color: c);
  static TextStyle caption(Color c) => GoogleFonts.cairo(fontSize: 12, height: 18 / 12, fontWeight: FontWeight.w400, color: c);
  static TextStyle button(Color c) => GoogleFonts.cairo(fontSize: 15, height: 20 / 15, fontWeight: FontWeight.w600, color: c);
  /// أسعار وأرقام — Inter
  static TextStyle price(Color c) => GoogleFonts.inter(fontSize: 18, height: 24 / 18, fontWeight: FontWeight.w600, color: c, fontFeatures: const [FontFeature.tabularFigures()]);
  static TextStyle en(Color c, {double size = 14, FontWeight weight = FontWeight.w400}) => GoogleFonts.inter(fontSize: size, fontWeight: weight, color: c);
}
