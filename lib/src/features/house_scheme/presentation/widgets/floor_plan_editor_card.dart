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
    required this.onAddRoomCell,
    required this.onRemoveRoomCell,
    required this.onMergeRooms,
    required this.onSplitWall,
    this.placementDraftRoom,
    this.placementDraftLayout,
    this.placementDraftError,
    this.onUpdatePlacementDraft,
    this.onConfirmPlacementDraft,
    this.onCancelPlacementDraft,
    this.canvasHeight = 360,
    this.useCardDecoration = true,
  });

  final Project project;
  final String? selectedRoomId;
  final String? selectedElementId;
  final VoidCallback onAddRoom;
  final ValueChanged<String> onSelectRoom;
  final void Function(String elementId, String roomId) onSelectElement;
  final Future<String?> Function(String roomId, RoomLayoutRect layout)
  onUpdateRoomLayout;
  final Future<String?> Function(String roomId, RoomLayoutRect cell)
  onAddRoomCell;
  final Future<String?> Function(String roomId, RoomLayoutRect cell)
  onRemoveRoomCell;
  final Future<String?> Function(String primaryRoomId, String secondaryRoomId)
  onMergeRooms;
  final Future<String?> Function(String elementId, double splitOffsetMeters)
  onSplitWall;
  final Room? placementDraftRoom;
  final RoomLayoutRect? placementDraftLayout;
  final String? placementDraftError;
  final ValueChanged<RoomLayoutRect>? onUpdatePlacementDraft;
  final VoidCallback? onConfirmPlacementDraft;
  final VoidCallback? onCancelPlacementDraft;
  final double canvasHeight;
  final bool useCardDecoration;

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
  String? _activeRoomId;
  _RoomGestureMode? _activeMode;
  String? _invalidRoomId;
  String? _invalidElementId;
  String? _lastCanvasError;
  RoomPartitionSegment? _selectedPartition;
  double? _selectedWallSplitOffsetMeters;
  _CellEditMode? _cellEditMode;

  RoomLayoutRect _layoutForRoom(Room room) {
    return _draftLayouts[room.id] ?? room.layout;
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

  void _markElementCommitFailed(String elementId, String error) {
    setState(() {
      _invalidRoomId = null;
      _invalidElementId = elementId;
      _lastCanvasError = error;
    });
  }

  Future<void> _handleCellEdit(
    Room room,
    RoomLayoutRect cell,
    _CellEditMode mode,
  ) async {
    final error = mode == _CellEditMode.add
        ? await widget.onAddRoomCell(room.id, cell)
        : await widget.onRemoveRoomCell(room.id, cell);
    if (!mounted) {
      return;
    }
    if (error == null) {
      setState(() {
        _clearTransientCanvasState();
      });
      return;
    }
    _markRoomCommitFailed(room.id, error);
  }

  void _startGesture(Room room, _RoomGestureMode mode) {
    widget.onSelectRoom(room.id);
    setState(() {
      _clearTransientCanvasState();
      _selectedPartition = null;
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

  void _updatePlacementDraft(DragUpdateDetails details) {
    final room = widget.placementDraftRoom;
    final layout = widget.placementDraftLayout;
    final onUpdate = widget.onUpdatePlacementDraft;
    if (room == null || layout == null || onUpdate == null) {
      return;
    }
    final deltaXMeters = details.delta.dx / _pixelsPerMeter;
    final deltaYMeters = details.delta.dy / _pixelsPerMeter;
    onUpdate(
      snapRoomLayout(
        layout.copyWith(
          xMeters: layout.xMeters + deltaXMeters,
          yMeters: layout.yMeters + deltaYMeters,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rooms = widget.project.houseModel.rooms;
    final placementDraftLayout = widget.placementDraftLayout;
    Room? selectedRoom;
    if (widget.selectedRoomId != null) {
      for (final room in rooms) {
        if (room.id == widget.selectedRoomId) {
          selectedRoom = room;
          break;
        }
      }
    }
    final cellEditTargets = selectedRoom == null || _cellEditMode == null
        ? const <RoomLayoutRect>[]
        : buildRoomCellEditTargets(
            rooms,
            selectedRoom,
            removing: _cellEditMode == _CellEditMode.remove,
          );
    final wallElements = widget.project.houseModel.elements
        .where(
          (element) =>
              element.elementKind == ConstructionElementKind.wall &&
              element.lineSegment != null,
        )
        .toList(growable: false);
    final partitions = buildRoomPartitions(rooms);
    final maxRightMeters = math.max(
      _minimumCanvasWidthMeters,
      [
            ...rooms.map((room) => _layoutForRoom(room).rightMeters),
            if (placementDraftLayout != null) placementDraftLayout.rightMeters,
          ].fold<double>(0, math.max) +
          2,
    );
    final maxBottomMeters = math.max(
      _minimumCanvasHeightMeters,
      [
            ...rooms.map((room) => _layoutForRoom(room).bottomMeters),
            if (placementDraftLayout != null) placementDraftLayout.bottomMeters,
          ].fold<double>(0, math.max) +
          2,
    );
    final canvasWidth = maxRightMeters * _pixelsPerMeter + _canvasPadding * 2;
    final canvasHeight = maxBottomMeters * _pixelsPerMeter + _canvasPadding * 2;

    final content = Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FloorPlanHeader(
            onAddRoom: widget.onAddRoom,
            lastCanvasError: widget.placementDraftError ?? _lastCanvasError,
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
                height: widget.canvasHeight,
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
                          for (
                            var cellIndex = 0;
                            cellIndex < room.effectiveCells.length;
                            cellIndex++
                          )
                            _PositionedRoomTile(
                              room: room,
                              layout: room.effectiveCells.length == 1
                                  ? _layoutForRoom(room)
                                  : room.effectiveCells[cellIndex],
                              cellKeySuffix: room.effectiveCells.length == 1
                                  ? null
                                  : '$cellIndex',
                              pixelsPerMeter: _pixelsPerMeter,
                              canvasPadding: _canvasPadding,
                              selected: widget.selectedRoomId == room.id,
                              editing: _draftLayouts.containsKey(room.id),
                              invalid: _invalidRoomId == room.id,
                              movable: room.effectiveCells.length == 1,
                              onTap: () {
                                widget.onSelectRoom(room.id);
                                setState(() {
                                  _selectedPartition = null;
                                  _selectedWallSplitOffsetMeters = null;
                                  _cellEditMode = null;
                                  _clearTransientCanvasState();
                                });
                              },
                              onMoveStart: room.effectiveCells.length == 1
                                  ? () => _startGesture(
                                      room,
                                      _RoomGestureMode.move,
                                    )
                                  : null,
                              onMoveUpdate: room.effectiveCells.length == 1
                                  ? (details) => _updateGesture(room, details)
                                  : null,
                              onMoveEnd: room.effectiveCells.length == 1
                                  ? () => _commitGesture(room)
                                  : null,
                              onResizeStart: room.effectiveCells.length == 1
                                  ? () => _startGesture(
                                      room,
                                      _RoomGestureMode.resize,
                                    )
                                  : null,
                              onResizeUpdate: room.effectiveCells.length == 1
                                  ? (details) => _updateGesture(room, details)
                                  : null,
                              onResizeEnd: room.effectiveCells.length == 1
                                  ? () => _commitGesture(room)
                                  : null,
                            ),
                        if (selectedRoom != null && _cellEditMode != null)
                          for (final cell in cellEditTargets)
                            _PositionedCellEditTarget(
                              key: ValueKey(
                                'floor-plan-cell-${_cellEditMode!.name}-${cell.xMeters}-${cell.yMeters}',
                              ),
                              cell: cell,
                              pixelsPerMeter: _pixelsPerMeter,
                              canvasPadding: _canvasPadding,
                              removing: _cellEditMode == _CellEditMode.remove,
                              onTap: () => _handleCellEdit(
                                selectedRoom!,
                                cell,
                                _cellEditMode!,
                              ),
                            ),
                        for (final partition in partitions)
                          _PositionedPartitionSegment(
                            segment: partition.segment,
                            pixelsPerMeter: _pixelsPerMeter,
                            canvasPadding: _canvasPadding,
                            thicknessPixels: 6,
                            selected: _partitionsEqual(
                              _selectedPartition,
                              partition,
                            ),
                            onTap: () {
                              widget.onSelectRoom(partition.primaryRoomId);
                              setState(() {
                                _clearTransientCanvasState();
                                _selectedPartition = partition;
                                _selectedWallSplitOffsetMeters = null;
                                _cellEditMode = null;
                              });
                            },
                          ),
                        for (final element in wallElements)
                          _PositionedWallSegment(
                            elementId: element.id,
                            segment: element.lineSegment!,
                            pixelsPerMeter: _pixelsPerMeter,
                            canvasPadding: _canvasPadding,
                            thicknessPixels: _wallThicknessPixels,
                            selected: widget.selectedElementId == element.id,
                            invalid: _invalidElementId == element.id,
                            label: element.title,
                            onTap: (localPosition) {
                              widget.onSelectElement(element.id, element.roomId);
                              setState(() {
                                _clearTransientCanvasState();
                                _selectedPartition = null;
                                _cellEditMode = null;
                                _selectedWallSplitOffsetMeters =
                                    splitOffsetForSegmentTap(
                                      element.lineSegment!,
                                      localPosition,
                                      _pixelsPerMeter,
                                    );
                              });
                            },
                          ),
                        if (widget.placementDraftRoom case final Room draftRoom)
                          _PositionedRoomTile(
                            key: const ValueKey('floor-plan-placement-draft'),
                            room: draftRoom,
                            layout: placementDraftLayout ?? draftRoom.layout,
                            cellKeySuffix: 'draft',
                            pixelsPerMeter: _pixelsPerMeter,
                            canvasPadding: _canvasPadding,
                            selected: true,
                            editing: true,
                            invalid: widget.placementDraftError != null,
                            movable: true,
                            onTap: () {},
                            onMoveStart: () {},
                            onMoveUpdate: _updatePlacementDraft,
                            onMoveEnd: () {},
                            onResizeStart: null,
                            onResizeUpdate: null,
                            onResizeEnd: null,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (selectedRoom != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.tonalIcon(
                  key: const ValueKey('cell-edit-add-button'),
                  onPressed: () {
                    setState(() {
                      _selectedPartition = null;
                      _selectedWallSplitOffsetMeters = null;
                      _cellEditMode = _cellEditMode == _CellEditMode.add
                          ? null
                          : _CellEditMode.add;
                      _clearTransientCanvasState();
                    });
                  },
                  icon: const Icon(Icons.add_box_outlined),
                  label: Text(
                    _cellEditMode == _CellEditMode.add
                        ? 'Готово: добавление ячеек'
                        : 'Добавлять ячейки',
                  ),
                ),
                FilledButton.tonalIcon(
                  key: const ValueKey('cell-edit-remove-button'),
                  onPressed: () {
                    setState(() {
                      _selectedPartition = null;
                      _selectedWallSplitOffsetMeters = null;
                      _cellEditMode = _cellEditMode == _CellEditMode.remove
                          ? null
                          : _CellEditMode.remove;
                      _clearTransientCanvasState();
                    });
                  },
                  icon: const Icon(Icons.indeterminate_check_box_outlined),
                  label: Text(
                    _cellEditMode == _CellEditMode.remove
                        ? 'Готово: удаление ячеек'
                        : 'Убирать ячейки',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _cellEditMode == null
                  ? 'Для составного помещения можно напрямую добавлять и убирать ячейки сетки 0.5 м.'
                  : _cellEditMode == _CellEditMode.add
                  ? 'Режим добавления: тапните по свободной соседней ячейке.'
                  : 'Режим удаления: тапните по ячейке комнаты. Несвязные формы и внутренние пустоты будут отклонены.',
            ),
          ],
          if (widget.placementDraftRoom != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  key: const ValueKey('confirm-room-placement-button'),
                  onPressed: widget.onConfirmPlacementDraft,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('ОК: разместить'),
                ),
                FilledButton.tonalIcon(
                  key: const ValueKey('cancel-room-placement-button'),
                  onPressed: widget.onCancelPlacementDraft,
                  icon: const Icon(Icons.close),
                  label: const Text('Отмена'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Разместите помещение на сетке. Сохранение доступно только для валидного примыкания без пересечений.',
            ),
          ],
          if (_selectedPartition != null || widget.selectedElementId != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (_selectedPartition != null)
                  FilledButton.tonalIcon(
                    key: const ValueKey('merge-rooms-button'),
                    onPressed: () async {
                      final partition = _selectedPartition!;
                      final error = await widget.onMergeRooms(
                        partition.primaryRoomId,
                        partition.secondaryRoomId,
                      );
                      if (!mounted) {
                        return;
                      }
                      if (error == null) {
                        setState(() {
                          _selectedPartition = null;
                          _selectedWallSplitOffsetMeters = null;
                          _clearTransientCanvasState();
                        });
                      } else {
                        _markRoomCommitFailed(partition.primaryRoomId, error);
                      }
                    },
                    icon: const Icon(Icons.call_merge),
                    label: const Text('Удалить перегородку'),
                  ),
                if (widget.selectedElementId != null &&
                    _selectedWallSplitOffsetMeters != null)
                  FilledButton.tonalIcon(
                    key: const ValueKey('split-wall-button'),
                    onPressed: () async {
                      final error = await widget.onSplitWall(
                        widget.selectedElementId!,
                        _selectedWallSplitOffsetMeters!,
                      );
                      if (!mounted) {
                        return;
                      }
                      if (error == null) {
                        setState(() {
                          _selectedWallSplitOffsetMeters = null;
                          _clearTransientCanvasState();
                        });
                      } else {
                        _markElementCommitFailed(
                          widget.selectedElementId!,
                          error,
                        );
                      }
                    },
                    icon: const Icon(Icons.content_cut),
                    label: const Text('Добавить разрез'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
    if (widget.useCardDecoration) {
      return Card(child: content);
    }
    return content;
  }

  bool _partitionsEqual(
    RoomPartitionSegment? left,
    RoomPartitionSegment right,
  ) {
    if (left == null) {
      return false;
    }
    return left.primaryRoomId == right.primaryRoomId &&
        left.secondaryRoomId == right.secondaryRoomId &&
        left.segment.startXMeters == right.segment.startXMeters &&
        left.segment.startYMeters == right.segment.startYMeters &&
        left.segment.endXMeters == right.segment.endXMeters &&
        left.segment.endYMeters == right.segment.endYMeters;
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
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              'План дома',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            FilledButton.icon(
              onPressed: onAddRoom,
              icon: const Icon(Icons.add),
              label: const Text('Добавить помещение'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Комната может состоять из нескольких соседних ячеек. Тап по общей перегородке объединяет комнаты, а тап по наружной стене подготавливает разрез для разных конструкций на одной стороне.',
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

enum _RoomGestureMode { move, resize }

enum _CellEditMode { add, remove }

class _PositionedCellEditTarget extends StatelessWidget {
  const _PositionedCellEditTarget({
    super.key,
    required this.cell,
    required this.pixelsPerMeter,
    required this.canvasPadding,
    required this.removing,
    required this.onTap,
  });

  final RoomLayoutRect cell;
  final double pixelsPerMeter;
  final double canvasPadding;
  final bool removing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: canvasPadding + cell.xMeters * pixelsPerMeter,
      top: canvasPadding + cell.yMeters * pixelsPerMeter,
      width: cell.widthMeters * pixelsPerMeter,
      height: cell.heightMeters * pixelsPerMeter,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: removing
                ? const Color(0xFFD98686).withValues(alpha: 0.35)
                : const Color(0xFF73B27D).withValues(alpha: 0.28),
            border: Border.all(
              color: removing
                  ? const Color(0xFF9C2F2F)
                  : const Color(0xFF2E6E43),
            ),
          ),
          child: Center(
            child: Icon(
              removing ? Icons.remove : Icons.add,
              size: 14,
              color: removing
                  ? const Color(0xFF6F1E1E)
                  : const Color(0xFF1F4D2C),
            ),
          ),
        ),
      ),
    );
  }
}

class _PositionedRoomTile extends StatelessWidget {
  const _PositionedRoomTile({
    super.key,
    required this.room,
    required this.layout,
    required this.cellKeySuffix,
    required this.pixelsPerMeter,
    required this.canvasPadding,
    required this.selected,
    required this.editing,
    required this.invalid,
    required this.movable,
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
  final String? cellKeySuffix;
  final double pixelsPerMeter;
  final double canvasPadding;
  final bool selected;
  final bool editing;
  final bool invalid;
  final bool movable;
  final VoidCallback onTap;
  final VoidCallback? onMoveStart;
  final GestureDragUpdateCallback? onMoveUpdate;
  final VoidCallback? onMoveEnd;
  final VoidCallback? onResizeStart;
  final GestureDragUpdateCallback? onResizeUpdate;
  final VoidCallback? onResizeEnd;

  @override
  Widget build(BuildContext context) {
    final compactTile =
        layout.widthMeters * pixelsPerMeter < 110 ||
        layout.heightMeters * pixelsPerMeter < 90;
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
        key: ValueKey(
          cellKeySuffix == null
              ? 'floor-plan-room-${room.id}'
              : 'floor-plan-room-${room.id}-cell-$cellKeySuffix',
        ),
        onTap: onTap,
        onPanStart: movable ? (_) => onMoveStart?.call() : null,
        onPanUpdate: onMoveUpdate,
        onPanEnd: movable ? (_) => onMoveEnd?.call() : null,
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
                        maxLines: compactTile ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      if (!compactTile) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${layout.widthMeters.toStringAsFixed(1)} x ${layout.heightMeters.toStringAsFixed(1)} м',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (movable)
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: GestureDetector(
                    key: ValueKey('floor-plan-room-resize-${room.id}'),
                    onPanStart: (_) => onResizeStart?.call(),
                    onPanUpdate: onResizeUpdate,
                    onPanEnd: (_) => onResizeEnd?.call(),
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
    required this.segment,
    required this.pixelsPerMeter,
    required this.canvasPadding,
    required this.thicknessPixels,
    required this.selected,
    required this.invalid,
    required this.label,
    required this.onTap,
  });

  final String elementId;
  final HouseLineSegment segment;
  final double pixelsPerMeter;
  final double canvasPadding;
  final double thicknessPixels;
  final bool selected;
  final bool invalid;
  final String label;
  final ValueChanged<Offset> onTap;

  @override
  Widget build(BuildContext context) {
    final rect = wallSegmentRect(
      segment: segment,
      pixelsPerMeter: pixelsPerMeter,
      canvasPadding: canvasPadding,
      thicknessPixels: thicknessPixels,
    );
    final fillColor = invalid
        ? const Color(0xFFD98686)
        : selected
        ? const Color(0xFF8A5530)
        : const Color(0xFFB36A3C);
    final borderColor = invalid
        ? const Color(0xFF6F1E1E)
        : selected
        ? const Color(0xFFFFE7C2)
        : const Color(0xFF5A3116);
    final isHorizontal = segment.isHorizontal;

    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: GestureDetector(
        key: ValueKey('floor-plan-wall-$elementId'),
        onTapDown: (details) => onTap(details.localPosition),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: borderColor,
              width: invalid || selected ? 2.0 : 1.2,
            ),
          ),
          child: Stack(
            children: [
              if ((isHorizontal ? rect.width : rect.height) > 56)
                Center(
                  child: RotatedBox(
                    quarterTurns: isHorizontal ? 0 : 3,
                    child: Text(
                      '$label • ${segment.lengthMeters.toStringAsFixed(1)} м',
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
            ],
          ),
        ),
      ),
    );
  }
}

class _PositionedPartitionSegment extends StatelessWidget {
  const _PositionedPartitionSegment({
    required this.segment,
    required this.pixelsPerMeter,
    required this.canvasPadding,
    required this.thicknessPixels,
    required this.selected,
    required this.onTap,
  });

  final HouseLineSegment segment;
  final double pixelsPerMeter;
  final double canvasPadding;
  final double thicknessPixels;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rect = wallSegmentRect(
      segment: segment,
      pixelsPerMeter: pixelsPerMeter,
      canvasPadding: canvasPadding,
      thicknessPixels: thicknessPixels,
    );
    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: GestureDetector(
        key: ValueKey(
          'floor-plan-partition-${segment.startXMeters}-${segment.startYMeters}-${segment.endXMeters}-${segment.endYMeters}',
        ),
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF4F6FA5) : const Color(0xFF90A0B8),
            borderRadius: BorderRadius.circular(999),
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
    final gridPaint = Paint()
      ..color = const Color(0xFFDCCFB4)
      ..strokeWidth = 1;
    for (
      double x = canvasPadding;
      x <= size.width - canvasPadding;
      x += pixelsPerMeter
    ) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (
      double y = canvasPadding;
      y <= size.height - canvasPadding;
      y += pixelsPerMeter
    ) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _FloorPlanGridPainter oldDelegate) {
    return oldDelegate.pixelsPerMeter != pixelsPerMeter ||
        oldDelegate.canvasPadding != canvasPadding;
  }
}
