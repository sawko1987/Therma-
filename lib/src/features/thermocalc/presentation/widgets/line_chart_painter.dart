import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/models/calculation.dart';

class ChartLine {
  const ChartLine({required this.series, required this.color});

  final GraphSeries series;
  final Color color;
}

class LineChartPainter extends CustomPainter {
  const LineChartPainter({required this.lines});

  final List<ChartLine> lines;

  @override
  void paint(Canvas canvas, Size size) {
    final framePaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final chartRect = Rect.fromLTWH(12, 12, size.width - 24, size.height - 24);
    canvas.drawRRect(
      RRect.fromRectAndRadius(chartRect, const Radius.circular(20)),
      framePaint,
    );

    final visibleLines = lines
        .where((line) => line.series.points.length >= 2)
        .toList();
    if (visibleLines.isEmpty) {
      return;
    }

    final xs = visibleLines.expand(
      (line) => line.series.points.map((point) => point.x),
    );
    final ys = visibleLines.expand(
      (line) => line.series.points.map((point) => point.y),
    );
    final minX = xs.reduce(min);
    final maxX = xs.reduce(max);
    final minY = ys.reduce(min);
    final maxY = ys.reduce(max);

    for (final line in visibleLines) {
      final pathPaint = Paint()
        ..color = line.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      final dotPaint = Paint()..color = line.color;
      final path = Path();

      for (var i = 0; i < line.series.points.length; i++) {
        final point = line.series.points[i];
        final dx =
            chartRect.left +
            ((point.x - minX) / _safeRange(minX, maxX)) * chartRect.width;
        final dy =
            chartRect.bottom -
            ((point.y - minY) / _safeRange(minY, maxY)) * chartRect.height;
        if (i == 0) {
          path.moveTo(dx, dy);
        } else {
          path.lineTo(dx, dy);
        }
        canvas.drawCircle(Offset(dx, dy), 4, dotPaint);
      }

      canvas.drawPath(path, pathPaint);
    }

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    var legendOffsetY = chartRect.top + 8;
    for (final line in visibleLines) {
      textPainter.text = TextSpan(
        text: line.series.title,
        style: TextStyle(
          color: line.color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      );
      textPainter.layout(maxWidth: chartRect.width - 16);
      textPainter.paint(canvas, Offset(chartRect.left + 8, legendOffsetY));
      legendOffsetY += textPainter.height + 2;
    }
  }

  @override
  bool shouldRepaint(covariant LineChartPainter oldDelegate) {
    return oldDelegate.lines != lines;
  }
}

double _safeRange(double min, double max) {
  final range = max - min;
  return range == 0 ? 1 : range;
}
