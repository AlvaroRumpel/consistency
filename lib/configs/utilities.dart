import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// Kept for callers that have no BuildContext (calendar controller). q1–q4
/// are theme-independent, so the light table is safe here.
class Utilities {
  static Color activeColor(double value) => AppTokens.light.qualityFor(value);
}
