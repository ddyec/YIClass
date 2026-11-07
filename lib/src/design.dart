import 'package:flutter/material.dart';

/// Shared Material 3 Expressive roles: tonal surfaces, generous shapes on
/// actions, compact connected groups, and stronger type for primary content.
ThemeData expressiveTheme(Color seed, Brightness brightness) {
  final generated = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
    contrastLevel: .15,
  );
  final dark = brightness == Brightness.dark;
  final colors = generated.copyWith(
    surface: dark ? const Color(0xff11151c) : const Color(0xfffcfdff),
    surfaceContainerLowest: dark ? const Color(0xff0d1117) : Colors.white,
    surfaceContainerLow: dark
        ? const Color(0xff191f28)
        : const Color(0xfff4f7fc),
    surfaceContainer: dark ? const Color(0xff202834) : const Color(0xffedf2f9),
    surfaceContainerHigh: dark
        ? const Color(0xff273240)
        : const Color(0xffe6edf7),
    surfaceContainerHighest: dark
        ? const Color(0xff303d4d)
        : const Color(0xffe1e9f4),
    onSurface: dark ? const Color(0xffe8edf6) : const Color(0xff192638),
    onSurfaceVariant: dark ? const Color(0xffb7c3d4) : const Color(0xff526175),
    outlineVariant: dark ? const Color(0xff394658) : const Color(0xffdce5f0),
    secondaryContainer: generated.primaryContainer,
    onSecondaryContainer: generated.onPrimaryContainer,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colors,
    fontFamily: 'NotoSansSC',
  );
  final text = base.textTheme.copyWith(
    headlineMedium: base.textTheme.headlineMedium!.copyWith(
      fontSize: 26,
      fontWeight: FontWeight.w700,
      height: 1.2,
    ),
    titleLarge: base.textTheme.titleLarge!.copyWith(
      fontSize: 21,
      fontWeight: FontWeight.w600,
      height: 1.25,
    ),
    titleMedium: base.textTheme.titleMedium!.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.3,
    ),
    bodyLarge: base.textTheme.bodyLarge!.copyWith(fontSize: 15, height: 1.35),
    bodyMedium: base.textTheme.bodyMedium!.copyWith(fontSize: 14, height: 1.3),
    labelLarge: base.textTheme.labelLarge!.copyWith(
      fontWeight: FontWeight.w700,
    ),
  );
  final actionShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
  );
  return base.copyWith(
    textTheme: text,
    scaffoldBackgroundColor: colors.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: colors.surface,
      foregroundColor: colors.onSurface,
      scrolledUnderElevation: 0,
      elevation: 0,
      toolbarHeight: 56,
      titleTextStyle: text.titleLarge,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: colors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surfaceContainerHighest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.primary, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: actionShape,
        minimumSize: const Size(48, 44),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: actionShape,
        minimumSize: const Size(48, 44),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: actionShape,
        minimumSize: const Size(40, 40),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        minimumSize: const Size(44, 44),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      elevation: 0,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      labelTextStyle: WidgetStatePropertyAll(
        text.labelMedium!.copyWith(fontSize: 11, fontWeight: FontWeight.w500),
      ),
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      minVerticalPadding: 8,
      horizontalTitleGap: 12,
      visualDensity: const VisualDensity(vertical: -1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.surface,
      showDragHandle: true,
      dragHandleColor: colors.outlineVariant,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: colors.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dividerTheme: DividerThemeData(
      color: colors.outlineVariant,
      space: 16,
      thickness: .6,
    ),
  );
}
