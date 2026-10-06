import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:qabas/core/design_system/tokens/tokens.dart';

/// Font families declared in pubspec.yaml.
abstract final class QFonts {
  static const latin = 'Figtree';
  static const arabic = 'PlexArabic';
  static const latinDisplay = 'Fraunces';
  static const arabicDisplay = 'Amiri';
  static const quran = 'AmiriQuran';
}

/// Brand text styles that Material's [TextTheme] has no slot for.
@immutable
class QText extends ThemeExtension<QText> {
  const QText({
    required this.display,
    required this.displaySmall,
    required this.eyebrow,
    required this.quran,
    required this.hadith,
    required this.stat,
    required this.isArabic,
  });

  /// Special moments: serif (Latin) / classical Naskh (Arabic).
  final TextStyle display;
  final TextStyle displaySmall;

  /// Small all-caps label above a heading.
  final TextStyle eyebrow;

  /// Quran text — always the Uthmani font, never stylised or distorted.
  final TextStyle quran;

  /// Hadith text in Arabic.
  final TextStyle hadith;

  /// Big numbers (XP, streak counts).
  final TextStyle stat;

  final bool isArabic;

  @override
  QText copyWith() => this;

  @override
  QText lerp(QText? other, double t) => t < 0.5 ? this : (other ?? this);
}

abstract final class QTheme {
  static ThemeData light({required bool arabic}) {
    final ui = arabic ? QFonts.arabic : QFonts.latin;
    final fallback = [arabic ? QFonts.latin : QFonts.arabic];
    // Arabic needs more vertical room for its ascenders, descenders and marks.
    final double h = arabic ? 1.55 : 1.3;
    final double body = arabic ? 1.75 : 1.5;

    TextStyle s(double size, FontWeight w, {double? height, double spacing = 0, Color color = QColors.deepInk}) => TextStyle(
      fontFamily: ui,
      fontFamilyFallback: fallback,
      fontSize: size,
      fontWeight: w,
      height: height ?? h,
      letterSpacing: arabic ? 0 : spacing,
      color: color,
    );

    final textTheme = TextTheme(
      displayLarge: s(44, FontWeight.w800, spacing: -1.2),
      displayMedium: s(36, FontWeight.w800, spacing: -0.8),
      displaySmall: s(30, FontWeight.w800, spacing: -0.5),
      headlineLarge: s(28, FontWeight.w800, spacing: -0.5),
      headlineMedium: s(24, FontWeight.w800, spacing: -0.3),
      headlineSmall: s(21, FontWeight.w800, spacing: -0.2),
      titleLarge: s(19, FontWeight.w700, spacing: -0.1),
      titleMedium: s(17, FontWeight.w700),
      titleSmall: s(15, FontWeight.w700),
      bodyLarge: s(17.5, FontWeight.w500, height: body),
      bodyMedium: s(15.5, FontWeight.w500, height: body, color: QColors.slate),
      bodySmall: s(13.5, FontWeight.w500, height: body, color: QColors.slate),
      labelLarge: s(16, FontWeight.w800, spacing: 0.3),
      labelMedium: s(13.5, FontWeight.w700, spacing: 0.2),
      labelSmall: s(11.5, FontWeight.w800, spacing: 0.8),
    );

    final qText = QText(
      display: TextStyle(
        fontFamily: arabic ? QFonts.arabicDisplay : QFonts.latinDisplay,
        fontFamilyFallback: [arabic ? QFonts.latinDisplay : QFonts.arabicDisplay],
        fontSize: arabic ? 38 : 36,
        fontWeight: arabic ? FontWeight.w700 : FontWeight.w600,
        height: arabic ? 1.45 : 1.12,
        letterSpacing: arabic ? 0 : -0.6,
        color: QColors.deepInk,
      ),
      displaySmall: TextStyle(
        fontFamily: arabic ? QFonts.arabicDisplay : QFonts.latinDisplay,
        fontFamilyFallback: [arabic ? QFonts.latinDisplay : QFonts.arabicDisplay],
        fontSize: arabic ? 27 : 25,
        fontWeight: arabic ? FontWeight.w700 : FontWeight.w600,
        height: arabic ? 1.5 : 1.2,
        letterSpacing: arabic ? 0 : -0.3,
        color: QColors.deepInk,
      ),
      eyebrow: s(arabic ? 13 : 12, FontWeight.w800, spacing: 1.4, color: QColors.emerald500),
      quran: const TextStyle(fontFamily: QFonts.quran, fontSize: 27, height: 2.15, color: QColors.deepInk),
      hadith: const TextStyle(fontFamily: QFonts.arabicDisplay, fontSize: 22, height: 1.95, color: QColors.deepInk),
      stat: const TextStyle(
        fontFamily: QFonts.latin,
        fontFamilyFallback: [QFonts.arabic],
        fontSize: 22,
        fontWeight: FontWeight.w800,
        height: 1.1,
        fontFeatures: [FontFeature.tabularFigures()],
        color: QColors.deepInk,
      ),
      isArabic: arabic,
    );

    final scheme = ColorScheme.fromSeed(
      seedColor: QColors.emerald,
      primary: QColors.emerald,
      onPrimary: Colors.white,
      secondary: QColors.flameGold,
      onSecondary: QColors.deepInk,
      surface: QColors.surface,
      onSurface: QColors.deepInk,
      error: QColors.retry,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: QColors.morningMint,
      fontFamily: ui,
      fontFamilyFallback: fallback,
      textTheme: textTheme,
      extensions: [qText],
      splashFactory: InkSparkle.splashFactory,
      highlightColor: Colors.transparent,
      dividerTheme: const DividerThemeData(color: QColors.line, thickness: 1, space: 1),
      iconTheme: const IconThemeData(color: QColors.deepInk, size: 24),
      appBarTheme: AppBarTheme(
        backgroundColor: QColors.morningMint,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge,
        foregroundColor: QColors.deepInk,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: QColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
        shape: RoundedRectangleBorder(borderRadius: QRadius.sheet),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : QColors.surface),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? QColors.emerald500 : QColors.lineStrong),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: QColors.emerald500,
        inactiveTrackColor: QColors.line,
        thumbColor: QColors.flameGold,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: QColors.deepInk,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: QRadius.button),
        contentTextStyle: textTheme.titleSmall?.copyWith(color: Colors.white),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder(), TargetPlatform.iOS: CupertinoPageTransitionsBuilder()},
      ),
    );
  }
}

extension QThemeX on BuildContext {
  TextTheme get text => Theme.of(this).textTheme;
  QText get qText => Theme.of(this).extension<QText>()!;
}

/// Wordmark typography is fixed to its script, independent of UI locale.
abstract final class QBrandText {
  static const splashArabic = TextStyle(
    fontFamily: QFonts.arabicDisplay,
    fontSize: 64,
    fontWeight: FontWeight.w700,
    color: QColors.softEmber,
    height: 1.15,
  );
  static TextStyle splashLatin(double progress) => TextStyle(
    fontFamily: QFonts.latinDisplay,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: 2 + 8 * progress,
    color: QColors.softEmber.withValues(alpha: 0.8),
  );
  static TextStyle languageTitle(TextStyle base, {required bool arabic}) =>
      base.copyWith(fontFamily: arabic ? QFonts.arabic : QFonts.latin);
  static const latinLanguageGlyph = TextStyle(
    fontFamily: QFonts.latinDisplay,
    fontSize: 22,
    color: QColors.flameGold,
    fontWeight: FontWeight.w600,
  );
  static const arabicLanguageGlyph = TextStyle(fontFamily: QFonts.arabicDisplay, fontSize: 26, color: QColors.flameGold, height: 1.2);
  static TextStyle arabicWordmark(double scale, Color ink) =>
      TextStyle(fontFamily: QFonts.arabicDisplay, fontSize: 54 * scale, fontWeight: FontWeight.w700, color: ink, height: 1.1);
  static TextStyle latinWordmark(double scale, Color ink) => TextStyle(
    fontFamily: QFonts.latinDisplay,
    fontSize: 22 * scale,
    fontWeight: FontWeight.w600,
    letterSpacing: 4 * scale,
    color: ink,
    height: 1,
  );
  static TextStyle inlineWordmark(double scale, Color ink) =>
      TextStyle(fontFamily: QFonts.latinDisplay, fontSize: 24 * scale, fontWeight: FontWeight.w600, color: ink);
}

abstract final class QContentText {
  static const termArabic = TextStyle(fontFamily: QFonts.arabicDisplay, fontSize: QLesson.termArabic, height: 1.3, color: QColors.emerald);
}
