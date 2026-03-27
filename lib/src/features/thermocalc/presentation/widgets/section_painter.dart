import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/models/catalog.dart';
import '../../../../core/models/project.dart';

class SectionPainter extends CustomPainter {
  SectionPainter({
    required this.construction,
    required this.materials,
  });

  final Construction construction;
  final Map<String, MaterialEntry> materials;

  @override
  void paint(Canvas canvas, Size size) {
    final enabled = construction.layers.where((layer) => layer.enabled).toList();
    final totalThickness = enabled.fold<double>(
      0,
      (value, layer) => value + layer.thicknessMm,
    );
    if (enabled.isEmpty || totalThickness == 0) {
      return;
    }

    final paint = Paint()..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFF1F2937);
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '…',
    );

    var currentX = 0.0;
    for (var i = 0; i < enabled.length; i++) {
      final layer = enabled[i];
      final width = size.width * (layer.thicknessMm / totalThickness);
      final rect = Rect.fromLTWH(currentX, 0, max(width, 24), size.height);
      paint.color = _palette[i % _palette.length];
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(18)),
        paint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(18)),
        borderPaint,
      );

      final label = materials[layer.materialId]?.name ?? layer.materialId;
      textPainter.text = TextSpan(
        text: '$label\n${layer.thicknessMm.toStringAsFixed(0)} мм',
        style: const TextStyle(
          color: Color(0xFF111827),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      );
      textPainter.layout(minWidth: 0, maxWidth: rect.width - 12);
      textPainter.paint(
        canvas,
        Offset(rect.left + 6, rect.top + 10),
      );

      currentX += width;
    }
  }

  @override
  bool shouldRepaint(covariant SectionPainter oldDelegate) {
    return oldDelegate.construction != construction ||
        oldDelegate.materials != materials;
  }
}

const _palette = <Color>[
  Color(0xFFE7C66B),
  Color(0xFFC2D7C6),
  Color(0xFF9CB4CC),
  Color(0xFFF0B8A9),
  Color(0xFFD5C7F1),
];
