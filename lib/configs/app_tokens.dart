import 'package:flutter/material.dart';

import 'colors.dart';

/// Design tokens that don't fit ColorScheme: day-quality scale, streak
/// flame tiers, success. Values come from the approved tokens.md.
class AppTokens extends ThemeExtension<AppTokens> {
  final Color success;
  final Color cardBorder;
  final List<Color> quality; // q0 (no data) .. q4 (>= 75 %)
  final List<Color> onQuality; // readable ink over each quality colour
  final List<Color> flame; // f0 (0 days) .. f4 (100+ days)

  const AppTokens({
    required this.success,
    required this.cardBorder,
    required this.quality,
    required this.onQuality,
    required this.flame,
  });

  static const _ink = Color(0xFF1B1D1F);

  // Amber and cyan are too light for white; red and green are not.
  static const _onQuality = <Color>[
    Colors.white,
    Colors.white,
    _ink,
    _ink,
    Colors.white,
  ];

  static const _flame = <Color>[
    AppColors.flameGrey,
    AppColors.amber,
    AppColors.orange,
    AppColors.redColor,
    AppColors.primaryColor,
  ];

  static const light = AppTokens(
    success: AppColors.greenColor,
    cardBorder: AppColors.primaryColor,
    quality: [
      AppColors.q0Light,
      AppColors.redColor,
      AppColors.amber,
      AppColors.primaryColor,
      AppColors.greenColor,
    ],
    onQuality: _onQuality,
    flame: _flame,
  );

  static const dark = AppTokens(
    success: AppColors.greenColor,
    cardBorder: AppColors.primaryColor,
    quality: [
      AppColors.q0Dark,
      AppColors.redColor,
      AppColors.amber,
      AppColors.primaryColor,
      AppColors.greenColor,
    ],
    onQuality: _onQuality,
    flame: _flame,
  );

  /// null = no data for that day.
  static int qualityTier(double? avgPercent) {
    if (avgPercent == null) return 0;
    if (avgPercent < 25) return 1;
    if (avgPercent < 50) return 2;
    if (avgPercent < 75) return 3;
    return 4;
  }

  Color qualityFor(double? avgPercent) => quality[qualityTier(avgPercent)];

  /// Foreground to draw on top of [qualityFor] of the same value.
  Color onQualityFor(double? avgPercent) => onQuality[qualityTier(avgPercent)];

  static int flameTier(int streakDays) {
    if (streakDays <= 0) return 0;
    if (streakDays < 7) return 1;
    if (streakDays < 30) return 2;
    if (streakDays < 100) return 3;
    return 4;
  }

  Color flameFor(int streakDays) => flame[flameTier(streakDays)];

  @override
  AppTokens copyWith({
    Color? success,
    Color? cardBorder,
    List<Color>? quality,
    List<Color>? onQuality,
    List<Color>? flame,
  }) =>
      AppTokens(
        success: success ?? this.success,
        cardBorder: cardBorder ?? this.cardBorder,
        quality: quality ?? this.quality,
        onQuality: onQuality ?? this.onQuality,
        flame: flame ?? this.flame,
      );

  @override
  AppTokens lerp(AppTokens? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppTokens(
      success: l(success, other.success),
      cardBorder: l(cardBorder, other.cardBorder),
      quality: [
        for (var i = 0; i < quality.length; i++) l(quality[i], other.quality[i])
      ],
      onQuality: [
        for (var i = 0; i < onQuality.length; i++)
          l(onQuality[i], other.onQuality[i])
      ],
      flame: [
        for (var i = 0; i < flame.length; i++) l(flame[i], other.flame[i])
      ],
    );
  }
}

extension AppTokensX on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
}
