import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'ios27_colors.dart';
import 'ios27_typography.dart';

/// iOS 27 Design System - Complete Theme
///
/// Provides ready-to-use [ThemeData] and [CupertinoThemeData] configured
/// with iOS 27 color tokens, typography, and component styles.
///
/// Usage with MaterialApp:
///   MaterialApp(
///     theme: IOS27Theme.light(),
///     darkTheme: IOS27Theme.dark(),
///   )
///
/// Usage with CupertinoApp:
///   CupertinoApp(
///     theme: IOS27Theme.cupertinoLight(),
///   )
class IOS27Theme {
  IOS27Theme._();

  // ---------------------------------------------------------------------------
  // Material ThemeData
  // ---------------------------------------------------------------------------

  /// Light mode [ThemeData] with iOS 27 design tokens.
  static ThemeData light() {
    final colorScheme = ColorScheme.light(
      primary: IOS27Colors.blue,
      onPrimary: Colors.white,
      primaryContainer: IOS27Colors.blue.withValues(alpha: 0.12),
      onPrimaryContainer: IOS27Colors.blue,
      secondary: IOS27Colors.gray,
      onSecondary: Colors.white,
      secondaryContainer: IOS27Colors.gray6,
      onSecondaryContainer: IOS27Colors.labelPrimary,
      tertiary: IOS27Colors.teal,
      onTertiary: Colors.white,
      error: IOS27Colors.red,
      onError: Colors.white,
      errorContainer: IOS27Colors.red.withValues(alpha: 0.12),
      onErrorContainer: IOS27Colors.red,
      surface: IOS27Colors.backgroundPrimary,
      onSurface: IOS27Colors.labelPrimary,
      onSurfaceVariant: IOS27Colors.labelSecondary,
      outline: IOS27Colors.separatorOpaque,
      outlineVariant: IOS27Colors.separatorNonOpaque,
      surfaceContainerHighest: IOS27Colors.backgroundSecondary,
      surfaceContainerHigh: IOS27Colors.gray6,
      surfaceContainer: IOS27Colors.gray5,
      surfaceContainerLow: IOS27Colors.backgroundPrimary,
      surfaceContainerLowest: IOS27Colors.grayWhite,
    );

    final textTheme = IOS27Typography.textTheme(
      color: IOS27Colors.labelPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: IOS27Colors.backgroundGroupedPrimary,
      canvasColor: IOS27Colors.backgroundPrimary,
      cardColor: IOS27Colors.backgroundGroupedSecondary,
      dividerColor: IOS27Colors.separatorOpaque,
      splashFactory: NoSplash.splashFactory,
      highlightColor: IOS27Colors.fillPrimary,

      // AppBar
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: IOS27Colors.backgroundPrimary,
        foregroundColor: IOS27Colors.labelPrimary,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: IOS27Typography.headline.copyWith(
          color: IOS27Colors.labelPrimary,
        ),
        centerTitle: true,
      ),

      // TabBar
      tabBarTheme: TabBarTheme(
        labelColor: IOS27Colors.blue,
        unselectedLabelColor: IOS27Colors.gray,
        labelStyle: IOS27Typography.caption2Emphasized,
        unselectedLabelStyle: IOS27Typography.caption2,
        indicatorColor: IOS27Colors.blue,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
      ),

      // BottomNavigationBar
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: IOS27Colors.backgroundPrimary,
        selectedItemColor: IOS27Colors.blue,
        unselectedItemColor: IOS27Colors.gray,
        selectedLabelStyle: IOS27Typography.caption2,
        unselectedLabelStyle: IOS27Typography.caption2,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // Card
      cardTheme: CardTheme(
        elevation: 0,
        color: IOS27Colors.backgroundGroupedSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16),
      ),

      // ListTile
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        minVerticalPadding: 11,
        titleTextStyle: IOS27Typography.body.copyWith(
          color: IOS27Colors.labelPrimary,
        ),
        subtitleTextStyle: IOS27Typography.subheadline.copyWith(
          color: IOS27Colors.labelSecondary,
        ),
        tileColor: IOS27Colors.backgroundGroupedSecondary,
      ),

      // Divider
      dividerTheme: DividerThemeData(
        color: IOS27Colors.separatorOpaque,
        thickness: 0.5,
        indent: 16,
        space: 0,
      ),

      // Dialog
      dialogTheme: DialogTheme(
        backgroundColor: IOS27Colors.backgroundPrimary,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        titleTextStyle: IOS27Typography.headline.copyWith(
          color: IOS27Colors.labelPrimary,
        ),
        contentTextStyle: IOS27Typography.subheadline.copyWith(
          color: IOS27Colors.labelSecondary,
        ),
      ),

      // BottomSheet
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: IOS27Colors.backgroundPrimary,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
        ),
        dragHandleColor: IOS27Colors.gray3,
        dragHandleSize: const Size(36, 5),
        showDragHandle: true,
      ),

      // ElevatedButton
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: IOS27Colors.blue,
          foregroundColor: Colors.white,
          elevation: 0,
          textStyle: IOS27Typography.bodyEmphasized,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),

      // TextButton
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: IOS27Colors.blue,
          textStyle: IOS27Typography.body,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
      ),

      // OutlinedButton
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: IOS27Colors.blue,
          textStyle: IOS27Typography.body,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          side: const BorderSide(color: IOS27Colors.separatorOpaque),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),

      // InputDecoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: IOS27Colors.fillTertiary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        hintStyle: IOS27Typography.body.copyWith(
          color: IOS27Colors.labelTertiary,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: IOS27Colors.blue, width: 1),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: IOS27Colors.red, width: 1),
        ),
      ),

      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IOS27Colors.green;
          }
          return IOS27Colors.fillSecondary;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: IOS27Colors.fillTertiary,
        selectedColor: IOS27Colors.blue.withValues(alpha: 0.15),
        labelStyle: IOS27Typography.subheadline,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: IOS27Colors.grayBlack.withValues(alpha: 0.85),
        contentTextStyle: IOS27Typography.subheadline.copyWith(
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),

      // ProgressIndicator
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: IOS27Colors.blue,
        linearTrackColor: IOS27Colors.fillTertiary,
      ),

      // Slider
      sliderTheme: SliderThemeData(
        activeTrackColor: IOS27Colors.blue,
        inactiveTrackColor: IOS27Colors.fillSecondary,
        thumbColor: Colors.white,
        overlayColor: IOS27Colors.blue.withValues(alpha: 0.12),
        trackHeight: 4,
      ),
    );
  }

  /// Dark mode [ThemeData] with iOS 27 design tokens.
  static ThemeData dark() {
    final colorScheme = ColorScheme.dark(
      primary: IOS27Colors.blue,
      onPrimary: Colors.white,
      primaryContainer: IOS27Colors.blue.withValues(alpha: 0.20),
      onPrimaryContainer: IOS27Colors.blue,
      secondary: IOS27Colors.gray,
      onSecondary: Colors.white,
      secondaryContainer: IOS27Colors.darkBackgroundSecondary,
      onSecondaryContainer: IOS27Colors.darkLabelPrimary,
      tertiary: IOS27Colors.teal,
      onTertiary: Colors.white,
      error: IOS27Colors.red,
      onError: Colors.white,
      errorContainer: IOS27Colors.red.withValues(alpha: 0.20),
      onErrorContainer: IOS27Colors.red,
      surface: IOS27Colors.darkBackgroundPrimary,
      onSurface: IOS27Colors.darkLabelPrimary,
      onSurfaceVariant: IOS27Colors.darkLabelSecondary,
      outline: IOS27Colors.darkSeparatorOpaque,
      outlineVariant: IOS27Colors.darkSeparatorNonOpaque,
      surfaceContainerHighest: IOS27Colors.darkBackgroundTertiary,
      surfaceContainerHigh: IOS27Colors.darkBackgroundSecondary,
      surfaceContainer: IOS27Colors.darkBackgroundSecondary,
      surfaceContainerLow: IOS27Colors.darkBackgroundPrimary,
      surfaceContainerLowest: IOS27Colors.grayBlack,
    );

    final textTheme = IOS27Typography.textTheme(
      color: IOS27Colors.darkLabelPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: IOS27Colors.darkBackgroundGroupedPrimary,
      canvasColor: IOS27Colors.darkBackgroundPrimary,
      cardColor: IOS27Colors.darkBackgroundGroupedSecondary,
      dividerColor: IOS27Colors.darkSeparatorOpaque,
      splashFactory: NoSplash.splashFactory,
      highlightColor: IOS27Colors.darkFillPrimary,

      // AppBar
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: IOS27Colors.darkBackgroundPrimary,
        foregroundColor: IOS27Colors.darkLabelPrimary,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: IOS27Typography.headline.copyWith(
          color: IOS27Colors.darkLabelPrimary,
        ),
        centerTitle: true,
      ),

      // TabBar
      tabBarTheme: TabBarTheme(
        labelColor: IOS27Colors.blue,
        unselectedLabelColor: IOS27Colors.gray,
        labelStyle: IOS27Typography.caption2Emphasized,
        unselectedLabelStyle: IOS27Typography.caption2,
        indicatorColor: IOS27Colors.blue,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
      ),

      // BottomNavigationBar
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: IOS27Colors.darkBackgroundPrimary,
        selectedItemColor: IOS27Colors.blue,
        unselectedItemColor: IOS27Colors.gray,
        selectedLabelStyle: IOS27Typography.caption2,
        unselectedLabelStyle: IOS27Typography.caption2,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // Card
      cardTheme: CardTheme(
        elevation: 0,
        color: IOS27Colors.darkBackgroundGroupedSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16),
      ),

      // ListTile
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        minVerticalPadding: 11,
        titleTextStyle: IOS27Typography.body.copyWith(
          color: IOS27Colors.darkLabelPrimary,
        ),
        subtitleTextStyle: IOS27Typography.subheadline.copyWith(
          color: IOS27Colors.darkLabelSecondary,
        ),
        tileColor: IOS27Colors.darkBackgroundGroupedSecondary,
      ),

      // Divider
      dividerTheme: DividerThemeData(
        color: IOS27Colors.darkSeparatorOpaque,
        thickness: 0.5,
        indent: 16,
        space: 0,
      ),

      // Dialog
      dialogTheme: DialogTheme(
        backgroundColor: IOS27Colors.darkBackgroundSecondary,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        titleTextStyle: IOS27Typography.headline.copyWith(
          color: IOS27Colors.darkLabelPrimary,
        ),
        contentTextStyle: IOS27Typography.subheadline.copyWith(
          color: IOS27Colors.darkLabelSecondary,
        ),
      ),

      // BottomSheet
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: IOS27Colors.darkBackgroundSecondary,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
        ),
        dragHandleColor: IOS27Colors.gray,
        dragHandleSize: const Size(36, 5),
        showDragHandle: true,
      ),

      // ElevatedButton
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: IOS27Colors.blue,
          foregroundColor: Colors.white,
          elevation: 0,
          textStyle: IOS27Typography.bodyEmphasized,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),

      // TextButton
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: IOS27Colors.blue,
          textStyle: IOS27Typography.body,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
      ),

      // OutlinedButton
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: IOS27Colors.blue,
          textStyle: IOS27Typography.body,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          side: const BorderSide(color: IOS27Colors.darkSeparatorOpaque),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),

      // InputDecoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: IOS27Colors.darkFillTertiary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        hintStyle: IOS27Typography.body.copyWith(
          color: IOS27Colors.darkLabelTertiary,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: IOS27Colors.blue, width: 1),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: IOS27Colors.red, width: 1),
        ),
      ),

      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IOS27Colors.green;
          }
          return IOS27Colors.darkFillSecondary;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: IOS27Colors.darkFillTertiary,
        selectedColor: IOS27Colors.blue.withValues(alpha: 0.25),
        labelStyle: IOS27Typography.subheadline.copyWith(
          color: IOS27Colors.darkLabelPrimary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: IOS27Colors.gray.withValues(alpha: 0.9),
        contentTextStyle: IOS27Typography.subheadline.copyWith(
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),

      // ProgressIndicator
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: IOS27Colors.blue,
        linearTrackColor: IOS27Colors.darkFillTertiary,
      ),

      // Slider
      sliderTheme: SliderThemeData(
        activeTrackColor: IOS27Colors.blue,
        inactiveTrackColor: IOS27Colors.darkFillSecondary,
        thumbColor: Colors.white,
        overlayColor: IOS27Colors.blue.withValues(alpha: 0.20),
        trackHeight: 4,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Cupertino ThemeData
  // ---------------------------------------------------------------------------

  /// Light mode [CupertinoThemeData] with iOS 27 design tokens.
  static CupertinoThemeData cupertinoLight() {
    return const CupertinoThemeData(
      brightness: Brightness.light,
      primaryColor: IOS27Colors.blue,
      primaryContrastingColor: CupertinoColors.white,
      scaffoldBackgroundColor: IOS27Colors.backgroundGroupedPrimary,
      barBackgroundColor: IOS27Colors.backgroundPrimary,
      textTheme: CupertinoTextThemeData(
        primaryColor: IOS27Colors.blue,
        textStyle: IOS27Typography.body,
        actionTextStyle: TextStyle(
          fontSize: 17,
          height: 22 / 17,
          letterSpacing: -0.43,
          fontWeight: FontWeight.w400,
          color: IOS27Colors.blue,
        ),
        tabLabelTextStyle: IOS27Typography.caption2,
        navTitleTextStyle: IOS27Typography.headline,
        navLargeTitleTextStyle: IOS27Typography.largeTitleEmphasized,
        navActionTextStyle: TextStyle(
          fontSize: 17,
          height: 22 / 17,
          letterSpacing: -0.43,
          fontWeight: FontWeight.w400,
          color: IOS27Colors.blue,
        ),
        pickerTextStyle: TextStyle(
          fontSize: 22,
          height: 28 / 22,
          letterSpacing: -0.26,
          fontWeight: FontWeight.w400,
          color: IOS27Colors.labelPrimary,
        ),
        dateTimePickerTextStyle: TextStyle(
          fontSize: 22,
          height: 28 / 22,
          letterSpacing: -0.26,
          fontWeight: FontWeight.w400,
          color: IOS27Colors.labelPrimary,
        ),
      ),
    );
  }

  /// Dark mode [CupertinoThemeData] with iOS 27 design tokens.
  static CupertinoThemeData cupertinoDark() {
    return const CupertinoThemeData(
      brightness: Brightness.dark,
      primaryColor: IOS27Colors.blue,
      primaryContrastingColor: CupertinoColors.white,
      scaffoldBackgroundColor: IOS27Colors.darkBackgroundGroupedPrimary,
      barBackgroundColor: IOS27Colors.darkBackgroundPrimary,
      textTheme: CupertinoTextThemeData(
        primaryColor: IOS27Colors.blue,
        textStyle: IOS27Typography.body,
        actionTextStyle: TextStyle(
          fontSize: 17,
          height: 22 / 17,
          letterSpacing: -0.43,
          fontWeight: FontWeight.w400,
          color: IOS27Colors.blue,
        ),
        tabLabelTextStyle: IOS27Typography.caption2,
        navTitleTextStyle: IOS27Typography.headline,
        navLargeTitleTextStyle: IOS27Typography.largeTitleEmphasized,
        navActionTextStyle: TextStyle(
          fontSize: 17,
          height: 22 / 17,
          letterSpacing: -0.43,
          fontWeight: FontWeight.w400,
          color: IOS27Colors.blue,
        ),
        pickerTextStyle: TextStyle(
          fontSize: 22,
          height: 28 / 22,
          letterSpacing: -0.26,
          fontWeight: FontWeight.w400,
          color: IOS27Colors.darkLabelPrimary,
        ),
        dateTimePickerTextStyle: TextStyle(
          fontSize: 22,
          height: 28 / 22,
          letterSpacing: -0.26,
          fontWeight: FontWeight.w400,
          color: IOS27Colors.darkLabelPrimary,
        ),
      ),
    );
  }
}
