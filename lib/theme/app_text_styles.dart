import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  // Use Google Fonts Nunito for friendly, modern typography
  static TextStyle get heading1 => GoogleFonts.nunito(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppColors.primary,
  );
  
  static TextStyle get heading => GoogleFonts.nunito(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.primary,
  );

  static TextStyle get subtitle => GoogleFonts.nunito(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.black87,
  );

  static TextStyle get body => GoogleFonts.nunito(
    fontSize: 14,
    color: Colors.black54,
  );
  
  static TextStyle get bodyBold => GoogleFonts.nunito(
    fontSize: 14,
    fontWeight: FontWeight.bold,
    color: Colors.black54,
  );
  
  static TextStyle get bodySmall => GoogleFonts.nunito(
    fontSize: 12,
    color: Colors.black54,
  );

  static TextStyle get button => GoogleFonts.nunito(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );
}
