import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/models/calculation.dart';

class LineChartPainter extends CustomPainter {
  const LineChartPainter({
    required this.series,
    required this.color,
  });

  final GraphSeries series;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final framePaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final pathPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final dotPaint = Paint()..color = color;

    final chartRect = Rect.fromLTWH(12, 12, size.width - 24, size.height - 24);
    canvas.drawRRect(
      RRect.fromRectAndRadius(chartRect, const Radius.circular(20)),
      framePaint,
    );

    if (series.points.length < 2) {
      return;
    }

    final xs = series.points.map((point) => point.x);
    final ys = series.points.map((point) => point.y);
    final minX = xs.reduce(min);
    final maxX = xs.reduce(max);
    final minY = ys.reduce(min);
    final maxY = ys.reduce(max);

    final path = Path();
    for (var i = 0; i < series.points.length; i++) {
      final point = series.points[i];
      final dx = chartRect.left +
          ((point.x - minX) / _safeRange(minX, maxX)) * chartRect.width;
      final dy = chartRect.bottom -
          ((point.y - minY) / _safeRange(minY, maxY)) * chartRect.height;
      if (i == 0) {
        path.moveTo(dx, dy);
      } else {
        path.lineTo(dx, dy);
      }
      canvas.drawCircle(Offset(dx, dy), 4, dotPaint);
    }

    canvas.drawPath(path, pathPaint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: series.title,
        style: const TextStyle(
          color: Color(0xFF0F172A),
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(chartRect.left + 8, chartRect.top + 8));
  }

  @override
  bool shouldRepaint(covariant LineChartPainter oldDelegate) {
    return oldDelegate.series != series || oldDelegate.color != color;
  }
}

double _safeRange(double min, double max) {
  final range = max - min;
  return range == 0 ? 1 : range;
}
