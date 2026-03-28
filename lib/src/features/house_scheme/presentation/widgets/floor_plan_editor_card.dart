import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/models/project.dart';
import '../floor_plan_geometry.dart';

class FloorPlanEditorCard extends StatefulWidget {
  const FloorPlanEditorCard({
    super.key,
    required this.project,
    required this.selectedRoomId,
    required this.selectedElementId,
    required this.onAddRoom,
    required this.onSelectRoom,
    required this.onSelectElement,
    required this.onUpdateRoomLayout,
    required this.onUpdateElementWallPlacement,
  });

  final Project project;
  final String? selectedRoomId;
  final String? selectedElementId;
  final VoidCallback onAddRoom;
  final ValueChanged<String> onSelectRoom;
  final void Function(String elementId, String roomId) onSelectElement;
  final Future<String?> Function(String roomId, RoomLayoutRect layout)
  onUpdateRoomLayout;
  final Future<String?> Function(
    HouseEnvelopeElement element,
    EnvelopeWallPlacement wallPlacement,
  )
  onUpdateElementWallPlacement;

  @override
  State<FloorPlanEditorCard> createState() => _FloorPlanEditorCardState();
}

class _FloorPlanEditorCardState extends State<FloorPlanEditorCard> {
  static const double _pixelsPerMeter = 32;
  static const double _canvasPadding = 24;
  static const double _minimumCanvasWidthMeters = 14;
  static const double _minimumCanvasHeightMeters = 10;
  static const double _wallThicknessPixels = 10;

  final Map<String, RoomLayoutRect> _draftLayouts = {};
  final Map<String, EnvelopeWallPlacement> _draftWallPlacements = {};
  String? _activeRoomId;
  _RoomGestureMode? _activeMode;
  String? _activeElementId;
  _WallGestureMode? _activeWallMode;
  String? _invalidRoomId;
  String? _invalidElementId;
  String? _lastCanvasError;

  RoomLayoutRect _layoutForRoom(Room room) {
    return _draftLayouts[room.id] ?? room.layout;
  }

  EnvelopeWallPlacement _wallPlacementForElement(HouseEnvelopeElement element) {
    return _draftWallPlacements[element.id] ?? element.wallPlacement!;
  }

  void _clearTransientCanvasState() {
    _invalidRoomId = null;
    _invalidElementId = null;
    _lastCanvasError = null;
  }

  void _markRoomCommitFailed(String roomId, String error) {
    setState(() {
      _invalidRoomId = roomId;
      _invalidElementId = null;
      _lastCanvasError = error;
    });
  }

  void _markWallCommitFailed(String elementId, String error) {
    setState(() {
      _invalidRoomId = null;
      _invalidElementId = elementId;
      _lastCanvasError = error;
    });
  }

  void _startGesture(Room room, _RoomGestureMode mode) {
    widget.onSelectRoom(room.id);
    setState(() {
      _clearTransientCanvasState();
      _activeRoomId = room.id;
      _activeMode = mode;
      _draftLayouts[room.id] = _layoutForRoom(room);
    });
  }

  void _updateGesture(Room room, DragUpdateDetails details) {
    if (_activeRoomId != room.id || _activeMode == null) {
      return;
    }
    final currentLayout = _layoutForRoom(room);
    final deltaXMeters = details.delta.dx / _pixelsPerMeter;
    final deltaYMeters = details.delta.dy / _pixelsPerMeter;
    final nextLayout = switch (_activeMode!) {
      _RoomGestureMode.move => snapRoomLayout(
        currentLayout.copyWith(
          xMeters: currentLayout.xMeters + deltaXMeters,
          yMeters: currentLayout.yMeters + deltaYMeters,
        ),
      ),
      _RoomGestureMode.resize => snapRoomLayout(
        currentLayout.copyWith(
          widthMeters: currentLayout.widthMeters + deltaXMeters,
          heightMeters: currentLayout.heightMeters + deltaYMeters,
        ),
      ),
    };
    setState(() {
      _draftLayouts[room.id] = nextLayout;
    });
  }

  Future<void> _commitGesture(Room room) async {
    final draftLayout = _draftLayouts.remove(room.id);
    setState(() {
      _activeRoomId = null;
      _activeMode = null;
    });
    if (draftLayout == null || layoutsEqual(draftLayout, room.layout)) {
      return;
    }

    final error = await widget.onUpdateRoomLayout(room.id, draftLayout);
    if (!mounted) {
      return;
    }
    if (error == null) {
      setState(_clearTransientCanvasState);
      return;
    }
    _markRoomCommitFailed(room.id, error);
  }

  void _startWallGesture(HouseEnvelopeElement element, _WallGestureMode mode) {
    widget.onSelectElement(element.id, element.roomId);
    setState(() {
      _clearTransientCanvasState();
      _activeElementId = element.id;
      _activeWallMode = mode;
      _draftWallPlacements[element.id] = _wallPlacementForElement(element);
    });
  }

  void _updateWallGesture(
    HouseEnvelopeElement element,
    Room room,
    DragUpdateDetails details,
  ) {
    if (_activeElementId != element.id || _activeWallMode == null) {
      return;
    }
    final currentPlacement = _wallPlacementForElement(element);
    final deltaMeters = deltaMetersForSide(
      currentPlacement.side,
      details.delta,
      _pixelsPerMeter,
    );
    final sideLength = room.layout.sideLength(currentPlacement.side);

    final nextPlacement = switch (_activeWallMode!) {
      _WallGestureMode.move => snapWallPlacement(
        currentPlacement.copyWith(
          offsetMeters: (currentPlacement.offsetMeters + deltaMeters)
              .clamp(
                0.0,
                math.max(0.0, sideLength - currentPlacement.lengthMeters),
              )
              .toDouble(),
        ),
        sideLength: sideLength,
      ),
      _WallGestureMode.resize => snapWallPlacement(
        currentPlacement.copyWith(
          lengthMeters: (currentPlacement.lengthMeters + deltaMeters)
              .clamp(
                roomLayoutSnapStepMeters,
                math.max(
                  roomLayoutSnapStepMeters,
                  sideLength - currentPlacement.offsetMeters,
                ),
              )
              .toDouble(),
        ),
        sideLength: sideLength,
      ),
    };

    setState(() {
      _draftWallPlacements[element.id] = nextPlacement;
    });
  }

  Future<void> _commitWallGesture(HouseEnvelopeElement element) async {
    final draftPlacement = _draftWallPlacements.remove(element.id);
    setState(() {
      _activeElementId = null;
      _activeWallMode = null;
    });
    if (draftPlacement == null ||
        wallPlacementsEqual(draftPlacement, element.wallPlacement!)) {
      return;
    }

    final error = await widget.onUpdateElementWallPlacement(
      element,
      draftPlacement,
    );
    if (!mounted) {
      return;
    }
    if (error == null) {
      setState(_clearTransientCanvasState);
      return;
    }
    _markWallCommitFailed(element.id, error);
  }

  @override
  Widget build(BuildContext context) {
    final rooms = widget.project.houseModel.rooms;
    final roomMap = {for (final room in rooms) room.id: room};
    final wallElements = widget.project.houseModel.elements
        .where(
          (element) =>
              element.elementKind == ConstructionElementKind.wall &&
              element.wallPlacement != null &&
              roomMap.containsKey(element.roomId),
        )
        .toList(growable: false);
    final maxRightMeters = math.max(
      _minimumCanvasWidthMeters,
      rooms.fold<double>(
            0,
            (maxValue, room) =>
                math.max(maxValue, _layoutForRoom(room).rightMeters),
          ) +
          2,
    );
    final maxBottomMeters = math.max(
      _minimumCanvasHeightMeters,
      rooms.fold<double>(
            0,
            (maxValue, room) =>
                math.max(maxValue, _layoutForRoom(room).bottomMeters),
          ) +
          2,
    );
    final canvasWidth = maxRightMeters * _pixelsPerMeter + _canvasPadding * 2;
    final canvasHeight = maxBottomMeters * _pixelsPerMeter + _canvasPadding * 2;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FloorPlanHeader(
              onAddRoom: widget.onAddRoom,
              lastCanvasError: _lastCanvasError,
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F3EA),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: SizedBox(
                  height: 360,
                  child: InteractiveViewer(
                    minScale: 0.7,
                    maxScale: 2.5,
                    panEnabled: false,
                    boundaryMargin: const EdgeInsets.all(48),
                    child: SizedBox(
                      key: const ValueKey('floor-plan-canvas'),
                      width: canvasWidth,
                      height: canvasHeight,
                      child: Stack(
                        children: [
                          CustomPaint(
                            size: Size(canvasWidth, canvasHeight),
                            painter: const _FloorPlanGridPainter(
                              pixelsPerMeter: _pixelsPerMeter,
                              canvasPadding: _canvasPadding,
                            ),
                          ),
                          for (final room in rooms)
                            _PositionedRoomTile(
                              room: room,
                              layout: _layoutForRoom(room),
                              pixelsPerMeter: _pixelsPerMeter,
                              canvasPadding: _canvasPadding,
                              selected: widget.selectedRoomId == room.id,
                              editing: _draftLayouts.containsKey(room.id),
                              invalid: _invalidRoomId == room.id,
                              onTap: () {
                                widget.onSelectRoom(room.id);
                                setState(_clearTransientCanvasState);
                              },
                              onMoveStart: () =>
                                  _startGesture(room, _RoomGestureMode.move),
                              onMoveUpdate: (details) =>
                                  _updateGesture(room, details),
                              onMoveEnd: () => _commitGesture(room),
                              onResizeStart: () =>
                                  _startGesture(room, _RoomGestureMode.resize),
                              onResizeUpdate: (details) =>
                                  _updateGesture(room, details),
                              onResizeEnd: () => _commitGesture(room),
                            ),
                          for (final element in wallElements)
                            _PositionedWallSegment(
                              elementId: element.id,
                              room: roomMap[element.roomId]!,
                              placement: _wallPlacementForElement(element),
                              pixelsPerMeter: _pixelsPerMeter,
                              canvasPadding: _canvasPadding,
                              thicknessPixels: _wallThicknessPixels,
                              selected: widget.selectedElementId == element.id,
                              editing: _draftWallPlacements.containsKey(
                                element.id,
                              ),
                              invalid: _invalidElementId == element.id,
                              label: element.title,
                              onTap: () {
                                widget.onSelectElement(
                                  element.id,
                                  element.roomId,
                                );
                                setState(_clearTransientCanvasState);
                              },
                              onMoveStart: () => _startWallGesture(
                                element,
                                _WallGestureMode.move,
                              ),
                              onMoveUpdate: (details) => _updateWallGesture(
                                element,
                                roomMap[element.roomId]!,
                                details,
                              ),
                              onMoveEnd: () => _commitWallGesture(element),
                              onResizeStart: () => _startWallGesture(
                                element,
                                _WallGestureMode.resize,
                              ),
                              onResizeUpdate: (details) => _updateWallGesture(
                                element,
                                roomMap[element.roomId]!,
                                details,
                              ),
                              onResizeEnd: () => _commitWallGesture(element),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FloorPlanHeader extends StatelessWidget {
  const _FloorPlanHeader({
    required this.onAddRoom,
    required this.lastCanvasError,
  });

  final VoidCallback onAddRoom;
  final String? lastCanvasError;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HeaderRow(onAddRoom: onAddRoom),
        const SizedBox(height: 8),
        const Text(
          'Комнаты редактируются как прямоугольники на сетке 0.5 м. Наружные стены живут на сторонах помещений: сегмент можно сдвигать вдоль стороны и растягивать за маркер.',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: const [
            _FloorPlanLegendChip(
              label: 'Выбрано',
              backgroundColor: Color(0xFFE9D5A8),
              borderColor: Color(0xFF7C5A26),
            ),
            _FloorPlanLegendChip(
              label: 'Черновик',
              backgroundColor: Color(0xFFD8E9F8),
              borderColor: Color(0xFF245B8E),
            ),
            _FloorPlanLegendChip(
              label: 'Ошибка commit',
              backgroundColor: Color(0xFFF4D4D4),
              borderColor: Color(0xFF9C2F2F),
            ),
          ],
        ),
        if (lastCanvasError != null) ...[
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFFDF0F0),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD98686)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Color(0xFF9C2F2F),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      lastCanvasError!,
                      key: const ValueKey('floor-plan-inline-error'),
                      style: const TextStyle(
                        color: Color(0xFF6F1E1E),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.onAddRoom});

  final VoidCallback onAddRoom;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'План дома',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ),
        FilledButton.icon(
          onPressed: onAddRoom,
          icon: const Icon(Icons.add),
          label: const Text('Добавить помещение'),
        ),
      ],
    );
  }
}

class _FloorPlanLegendChip extends StatelessWidget {
  const _FloorPlanLegendChip({
    required this.label,
    required this.backgroundColor,
    required this.borderColor,
  });

  final String label;
  final Color backgroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

enum _RoomGestureMode { move, resize }

enum _WallGestureMode { move, resize }

class _PositionedRoomTile extends StatelessWidget {
  const _PositionedRoomTile({
    required this.room,
    required this.layout,
    required this.pixelsPerMeter,
    required this.canvasPadding,
    required this.selected,
    required this.editing,
    required this.invalid,
    required this.onTap,
    required this.onMoveStart,
    required this.onMoveUpdate,
    required this.onMoveEnd,
    required this.onResizeStart,
    required this.onResizeUpdate,
    required this.onResizeEnd,
  });

  final Room room;
  final RoomLayoutRect layout;
  final double pixelsPerMeter;
  final double canvasPadding;
  final bool selected;
  final bool editing;
  final bool invalid;
  final VoidCallback onTap;
  final VoidCallback onMoveStart;
  final GestureDragUpdateCallback onMoveUpdate;
  final VoidCallback onMoveEnd;
  final VoidCallback onResizeStart;
  final GestureDragUpdateCallback onResizeUpdate;
  final VoidCallback onResizeEnd;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = invalid
        ? const Color(0xFFF4D4D4).withValues(alpha: 0.95)
        : editing
        ? const Color(0xFFD8E9F8).withValues(alpha: 0.95)
        : selected
        ? const Color(0xFFE9D5A8).withValues(alpha: 0.9)
        : const Color(0xFFDCC9A0).withValues(alpha: 0.8);
    final borderColor = invalid
        ? const Color(0xFF9C2F2F)
        : editing
        ? const Color(0xFF245B8E)
        : selected
        ? Theme.of(context).colorScheme.primary
        : const Color(0xFF6D6048);
    final borderWidth = invalid || editing || selected ? 2.0 : 1.2;

    return Positioned(
      left: canvasPadding + layout.xMeters * pixelsPerMeter,
      top: canvasPadding + layout.yMeters * pixelsPerMeter,
      width: layout.widthMeters * pixelsPerMeter,
      height: layout.heightMeters * pixelsPerMeter,
      child: GestureDetector(
        key: ValueKey('floor-plan-room-${room.id}'),
        onTap: onTap,
        onPanStart: (_) => onMoveStart(),
        onPanUpdate: onMoveUpdate,
        onPanEnd: (_) => onMoveEnd(),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: borderWidth),
          ),
          child: Stack(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        room.title,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${layout.widthMeters.toStringAsFixed(1)} x ${layout.heightMeters.toStringAsFixed(1)} м',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: 6,
                bottom: 6,
                child: GestureDetector(
                  key: ValueKey('floor-plan-room-resize-${room.id}'),
                  onPanStart: (_) => onResizeStart(),
                  onPanUpdate: onResizeUpdate,
                  onPanEnd: (_) => onResizeEnd(),
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: borderColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.open_in_full, size: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PositionedWallSegment extends StatelessWidget {
  const _PositionedWallSegment({
    required this.elementId,
    required this.room,
    required this.placement,
    required this.pixelsPerMeter,
    required this.canvasPadding,
    required this.thicknessPixels,
    required this.selected,
    required this.editing,
    required this.invalid,
    required this.label,
    required this.onTap,
    required this.onMoveStart,
    required this.onMoveUpdate,
    required this.onMoveEnd,
    required this.onResizeStart,
    required this.onResizeUpdate,
    required this.onResizeEnd,
  });

  final String elementId;
  final Room room;
  final EnvelopeWallPlacement placement;
  final double pixelsPerMeter;
  final double canvasPadding;
  final double thicknessPixels;
  final bool selected;
  final bool editing;
  final bool invalid;
  final String label;
  final VoidCallback onTap;
  final VoidCallback onMoveStart;
  final GestureDragUpdateCallback onMoveUpdate;
  final VoidCallback onMoveEnd;
  final VoidCallback onResizeStart;
  final GestureDragUpdateCallback onResizeUpdate;
  final VoidCallback onResizeEnd;

  @override
  Widget build(BuildContext context) {
    final rect = wallSegmentRect(
      room: room,
      placement: placement,
      pixelsPerMeter: pixelsPerMeter,
      canvasPadding: canvasPadding,
      thicknessPixels: thicknessPixels,
    );
    final isHorizontal = placement.side.isHorizontal;
    final fillColor = invalid
        ? const Color(0xFFD98686)
        : editing
        ? const Color(0xFF3F7CB8)
        : selected
        ? const Color(0xFF8A5530)
        : const Color(0xFFB36A3C);
    final borderColor = invalid
        ? const Color(0xFF6F1E1E)
        : editing
        ? const Color(0xFF143E67)
        : selected
        ? const Color(0xFFFFE7C2)
        : const Color(0xFF5A3116);

    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: GestureDetector(
        key: ValueKey('floor-plan-wall-$elementId'),
        onTap: onTap,
        onPanStart: (_) => onMoveStart(),
        onPanUpdate: onMoveUpdate,
        onPanEnd: (_) => onMoveEnd(),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: borderColor,
              width: invalid || editing || selected ? 2.0 : 1.2,
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if ((isHorizontal ? rect.width : rect.height) > 56)
                Center(
                  child: RotatedBox(
                    quarterTurns: isHorizontal ? 0 : 3,
                    child: Text(
                      '$label • ${placement.lengthMeters.toStringAsFixed(1)} м',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              Positioned(
                right: isHorizontal ? -6 : null,
                bottom: isHorizontal ? null : -6,
                top: isHorizontal ? null : 6,
                left: isHorizontal ? null : 6,
                child: GestureDetector(
                  key: ValueKey('floor-plan-wall-resize-$elementId'),
                  onPanStart: (_) => onResizeStart(),
                  onPanUpdate: onResizeUpdate,
                  onPanEnd: (_) => onResizeEnd(),
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE7C2),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: borderColor),
                    ),
                    child: Icon(
                      isHorizontal ? Icons.drag_handle : Icons.more_horiz,
                      size: 12,
                      color: borderColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FloorPlanGridPainter extends CustomPainter {
  const _FloorPlanGridPainter({
    required this.pixelsPerMeter,
    required this.canvasPadding,
  });

  final double pixelsPerMeter;
  final double canvasPadding;

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()..color = const Color(0xFFF7F3EA);
    final minorPaint = Paint()
      ..color = const Color(0xFFE6DDCB)
      ..strokeWidth = 1;
    final majorPaint = Paint()
      ..color = const Color(0xFFD0C3AA)
      ..strokeWidth = 1.2;

    canvas.drawRect(Offset.zero & size, backgroundPaint);

    for (
      double x = canvasPadding;
      x <= size.width - canvasPadding;
      x += pixelsPerMeter * roomLayoutSnapStepMeters
    ) {
      final index =
          ((x - canvasPadding) / (pixelsPerMeter * roomLayoutSnapStepMeters))
              .round();
      final paint = index.isEven ? majorPaint : minorPaint;
      canvas.drawLine(
        Offset(x, canvasPadding),
        Offset(x, size.height - canvasPadding),
        paint,
      );
    }

    for (
      double y = canvasPadding;
      y <= size.height - canvasPadding;
      y += pixelsPerMeter * roomLayoutSnapStepMeters
    ) {
      final index =
          ((y - canvasPadding) / (pixelsPerMeter * roomLayoutSnapStepMeters))
              .round();
      final paint = index.isEven ? majorPaint : minorPaint;
      canvas.drawLine(
        Offset(canvasPadding, y),
        Offset(size.width - canvasPadding, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FloorPlanGridPainter oldDelegate) {
    return oldDelegate.pixelsPerMeter != pixelsPerMeter ||
        oldDelegate.canvasPadding != canvasPadding;
  }
}
