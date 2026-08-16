import 'package:consistency/configs/app_tokens.dart';
import 'package:consistency/configs/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('qualityFor follows the 25/50/75 scale and grey for no data', () {
    const t = AppTokens.light;
    expect(t.qualityFor(null), t.quality[0]);
    expect(t.qualityFor(0), t.quality[1]);
    expect(t.qualityFor(24.9), t.quality[1]);
    expect(t.qualityFor(25), t.quality[2]);
    expect(t.qualityFor(50), t.quality[3]);
    expect(t.qualityFor(74.9), t.quality[3]);
    expect(t.qualityFor(75), t.quality[4]);
    expect(t.qualityFor(100), t.quality[4]);
  });

  test('flame tiers', () {
    expect(AppTokens.flameTier(0), 0);
    expect(AppTokens.flameTier(1), 1);
    expect(AppTokens.flameTier(6), 1);
    expect(AppTokens.flameTier(7), 2);
    expect(AppTokens.flameTier(29), 2);
    expect(AppTokens.flameTier(30), 3);
    expect(AppTokens.flameTier(99), 3);
    expect(AppTokens.flameTier(100), 4);
    expect(AppTokens.flameTier(365), 4);
  });

  test('both themes expose AppTokens and the design surface values', () {
    expect(themeLight.extension<AppTokens>(), same(AppTokens.light));
    expect(themeDark.extension<AppTokens>(), same(AppTokens.dark));
    expect(themeLight.colorScheme.surface, const Color(0xFFE8EEF2));
    expect(themeDark.colorScheme.surface, const Color(0xFF39393A));
    expect(themeLight.cardColor, const Color(0xFFF6F8FA));
    expect(themeDark.cardColor, const Color(0xFF434345));
    expect(themeLight.colorScheme.primary, const Color(0xFF2CA8CB));
    expect(themeDark.colorScheme.onSurface, const Color(0xFFF2F5F7));
  });
}
