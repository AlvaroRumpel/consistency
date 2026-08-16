import 'package:flutter/material.dart';

extension AppColors on Colors {
  static const primaryColor = MaterialColor(
    0xFF2CA8CB,
    <int, Color>{
      50: Color(0xFF68C4DE),
      100: Color(0xFF58BEDA),
      200: Color(0xFF90CAF9),
      300: Color(0xFF47B7D7),
      400: Color(0xFF36B1D3),
      500: Color(0xFF2CA8CB),
      600: Color(0xFF2899B8),
      700: Color(0xFF258BA7),
      800: Color(0xFF217D97),
      900: Color(0xFF1D6F86),
    },
  );

  static const blackColor = MaterialColor(
    0xFF39393A,
    <int, Color>{
      50: Color(0xFF6F6F71),
      100: Color(0xFF656567),
      200: Color(0xFF5B5B5D),
      300: Color(0xFF515152),
      400: Color(0xFF474748),
      500: Color(0xFF39393A),
      600: Color(0xFF323234),
      700: Color(0xFF282829),
      800: Color(0xFF1E1E1F),
      900: Color(0xFF141415),
    },
  );

  static const whiteColor = MaterialColor(
    0xFFF2F5F7,
    <int, Color>{
      50: Color(0xFFFFFFFF),
      100: Color(0xFFFCFCFC),
      200: Color(0xFFFAFAFA),
      300: Color(0xFFF8F8F8),
      400: Color(0xFFF5F6F8),
      500: Color(0xFFF2F5F7),
      600: Color(0xFFE6ECEF),
      700: Color(0xFFD9E2E8),
      800: Color(0xFFCCD8E0),
      900: Color(0xFFC0CED8),
    },
  );

  static const greenColor = MaterialColor(
    0xFF418F3F,
    <int, Color>{
      50: Color(0xFF73C171),
      100: Color(0xFF65BB63),
      200: Color(0xFF56B455),
      300: Color(0xFF4CAA4B),
      400: Color(0xFF469C44),
      500: Color(0xFF418F3F),
      600: Color(0xFF398038),
      700: Color(0xFF337132),
      800: Color(0xFF2C632C),
      900: Color(0xFF265426),
    },
  );

  static const redColor = MaterialColor(
    0xFFCB2E33,
    <int, Color>{
      50: Color(0xFFE58B8E),
      100: Color(0xFFE17A7D),
      200: Color(0xFFDD696D),
      300: Color(0xFFD9595D),
      400: Color(0xFFD5484D),
      500: Color(0xFFCB2E33),
      600: Color(0xFFC82D32),
      700: Color(0xFFB72A2E),
      800: Color(0xFFA6262A),
      900: Color(0xFF962226),
    },
  );

  // ---- v2 design tokens (Claude Design tokens.md) ----
  static const surfaceLight = Color(0xFFE8EEF2);
  static const surfaceDark = Color(0xFF39393A);
  static const cardLight = Color(0xFFF6F8FA);
  static const cardDark = Color(0xFF434345);
  static const insetLight = Color(0xFFDCE4EA);
  static const insetDark = Color(0xFF2E2E30);
  static const dividerLight = Color(0xFFB9C6CF);
  static const dividerDark = Color(0xFF5A5A5C);
  static const textLight = Color(0xFF26282B);
  static const textDark = Color(0xFFF2F5F7);
  static const text2Light = Color(0xFF5C646B);
  static const text2Dark = Color(0xFFB4BAC0);
  static const amber = Color(0xFFE0862E);
  static const orange = Color(0xFFE85D2A);
  static const flameGrey = Color(0xFF8A9299);
  static const q0Light = Color(0xFFC4CFD6);
  static const q0Dark = Color(0xFF55585B);
}
