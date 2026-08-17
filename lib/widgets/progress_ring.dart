import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../configs/app_tokens.dart';
import '../configs/text_styles.dart';

/// The day hero: a ring filled to the day's average, tap to save.
class ProgressRing extends StatelessWidget {
  final double? average;
  final bool saved;
  final bool dirty;
  final VoidCallback? onTap;
  final double size;

  const ProgressRing({
    super.key,
    required this.average,
    required this.saved,
    required this.dirty,
    required this.onTap,
    this.size = 200,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subtitle = !saved || dirty ? 'TAP TO SAVE' : 'SAVED · TAP TO EDIT';
    return Semantics(
      label: 'Save today',
      button: true,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(
            value: (average ?? 0) / 100,
            track: scheme.surfaceContainerLow,
            progress: context.tokens.qualityFor(average),
          ),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${average?.round() ?? 0}%',
                    style: context.textStyles.boldText
                        .copyWith(fontSize: 44, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: context.textStyles.thinText.copyWith(
                      fontSize: 11,
                      letterSpacing: 1.2,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value; // 0..1
  final Color track;
  final Color progress;

  const _RingPainter(
      {required this.value, required this.track, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = (math.min(size.width, size.height) - 14) / 2;
    final circle = Rect.fromCircle(center: rect.center, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(rect.center, radius, paint..color = track);
    if (value > 0) {
      canvas.drawArc(circle, -math.pi / 2, 2 * math.pi * value, false,
          paint..color = progress);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.track != track || old.progress != progress;
}
