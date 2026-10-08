import 'package:flutter/material.dart';

/// Colour tokens lifted straight from the `:root` block in style.css so the
/// app and the website stay visually identical.
class AppColors {
  const AppColors._();

  static const Color primary = Color(0xFFEF8354);
  static const Color accent = Color(0xFFF6BD60);
  static const Color text = Color(0xFFF7F3EC);
  static const Color mutedText = Color(0xFFB7B2AA);
  static const Color lightBg = Color(0xFF162A2A);
  static const Color darkBg = Color(0xFF102020);
  static const Color darkStrong = Color(0xFF0A1515);
  static const Color gradientTop = Color(0xFF102020);
  static const Color gradientBottom = Color(0xFF173332);
  static const Color footerStart = Color(0xFF203C39);

  static const Color panel = Color(0xEB172D2D);
  static const Color panelSoft = Color(0xD6223D3B);
  static const Color line = Color(0x1AFFFFFF);
  static const Color lineStrong = Color(0x24FFFFFF);

  static const Color success = Color(0xFF6FCF97);
  static const Color danger = Color(0xFFE87461);
}

/// The site body uses a radial orange wash over a vertical teal gradient.
const BoxDecoration appBackground = BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.gradientTop, AppColors.gradientBottom],
  ),
);

class AppTheme {
  const AppTheme._();

  /// style.css sets `font-family: Georgia, 'Times New Roman', serif` on every
  /// element. Named families resolve on desktop/web; the generic `serif`
  /// fallback covers Android and iOS.
  static const String _fontFamily = 'Georgia';
  static const List<String> _fontFallback = [
    'Times New Roman',
    'Iowan Old Style',
    'Noto Serif',
    'serif',
  ];

  static ThemeData build() {
    const scheme = ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: AppColors.darkStrong,
      secondary: AppColors.accent,
      onSecondary: AppColors.darkStrong,
      surface: AppColors.lightBg,
      onSurface: AppColors.text,
      error: AppColors.danger,
      onError: AppColors.text,
    );

    final base = ThemeData.from(colorScheme: scheme, useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.darkBg,
      canvasColor: AppColors.darkBg,
      splashFactory: InkSparkle.splashFactory,
      textTheme: base.textTheme
          .apply(
            fontFamily: _fontFamily,
            fontFamilyFallback: _fontFallback,
            bodyColor: AppColors.text,
            displayColor: AppColors.text,
          )
          .copyWith(
            displaySmall: const TextStyle(
              fontFamily: _fontFamily,
              fontFamilyFallback: _fontFallback,
              fontWeight: FontWeight.w700,
              height: 1.12,
              color: AppColors.text,
            ),
            titleLarge: const TextStyle(
              fontFamily: _fontFamily,
              fontFamilyFallback: _fontFallback,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
            bodyMedium: const TextStyle(
              fontFamily: _fontFamily,
              fontFamilyFallback: _fontFallback,
              height: 1.6,
              color: AppColors.text,
            ),
          ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: AppColors.text,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.line, space: 1, thickness: 1),
      cardTheme: CardThemeData(
        color: AppColors.panelSoft,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.line),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.darkStrong,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontFamilyFallback: _fontFallback,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.text,
          side: const BorderSide(color: AppColors.lineStrong),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontFamilyFallback: _fontFallback,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontFamilyFallback: _fontFallback,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0x14FFFFFF),
        hintStyle: const TextStyle(color: AppColors.mutedText),
        labelStyle: const TextStyle(color: AppColors.mutedText),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: _inputBorder(AppColors.line),
        enabledBorder: _inputBorder(AppColors.line),
        focusedBorder: _inputBorder(AppColors.primary),
        errorBorder: _inputBorder(AppColors.danger),
        focusedErrorBorder: _inputBorder(AppColors.danger),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.lightBg,
        contentTextStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontFamilyFallback: _fontFallback,
          color: AppColors.text,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.lightBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.lightBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.mutedText,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primary
              : Colors.transparent,
        ),
        checkColor: const WidgetStatePropertyAll(AppColors.darkStrong),
        side: const BorderSide(color: AppColors.mutedText, width: 1.5),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: color),
  );
}

/// Small uppercase kicker used above headings across the site.
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: AppColors.accent,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 2.2,
      ),
    );
  }
}
