import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/catalog.dart';
import '../../../core/models/project.dart';
import '../../../core/providers.dart';
import '../../../core/services/house_summary_service.dart';
import '../../thermocalc/presentation/thermocalc_screen.dart';

class HouseSchemeScreen extends ConsumerWidget {
  const HouseSchemeScreen({super.key});

  Future<void> _handleAddRoom(
    BuildContext context,
    WidgetRef ref,
    Project project,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final room = await _showRoomEditor(
      context,
      initialLayout: _buildNextRoomLayout(project.houseModel.rooms),
    );
    if (!context.mounted) {
      return;
    }
    if (room == null) {
      return;
    }
    try {
      await ref.read(projectEditorProvider).addRoom(room);
    } catch (error) {
      _showError(messenger, error);
    }
  }

  Future<void> _handleEditRoom(
    BuildContext context,
    WidgetRef ref,
    Room room,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final updated = await _showRoomEditor(context, room: room);
    if (!context.mounted) {
      return;
    }
    if (updated == null) {
      return;
    }
    try {
      await ref.read(projectEditorProvider).updateRoom(updated);
    } catch (error) {
      _showError(messenger, error);
    }
  }

  Future<void> _handleDeleteRoom(
    BuildContext context,
    WidgetRef ref,
    Room room,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!context.mounted) {
      return;
    }
    try {
      await ref.read(projectEditorProvider).deleteRoom(room.id);
    } catch (error) {
      _showError(messenger, error);
    }
  }

  Future<void> _handleUpdateRoomLayout(
    BuildContext context,
    WidgetRef ref,
    String roomId,
    RoomLayoutRect layout,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(projectEditorProvider).updateRoomLayout(roomId, layout);
    } catch (error) {
      _showError(messenger, error);
    }
  }

  Future<void> _handleAddElement(
    BuildContext context,
    WidgetRef ref,
    Project project,
    CatalogSnapshot catalog,
    Room room,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final element = await _showElementEditor(
      context,
      project: project,
      catalog: catalog,
      roomId: room.id,
    );
    if (!context.mounted) {
      return;
    }
    if (element == null) {
      return;
    }
    try {
      await ref.read(projectEditorProvider).addEnvelopeElement(element);
    } catch (error) {
      _showError(messenger, error);
    }
  }

  Future<void> _handleEditElement(
    BuildContext context,
    WidgetRef ref,
    Project project,
    CatalogSnapshot catalog,
    HouseEnvelopeElement element,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final updated = await _showElementEditor(
      context,
      project: project,
      catalog: catalog,
      element: element,
      roomId: element.roomId,
    );
    if (!context.mounted) {
      return;
    }
    if (updated == null) {
      return;
    }
    try {
      await ref.read(projectEditorProvider).updateEnvelopeElement(updated);
    } catch (error) {
      _showError(messenger, error);
    }
  }

  Future<void> _handleDeleteElement(
    BuildContext context,
    WidgetRef ref,
    HouseEnvelopeElement element,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!context.mounted) {
      return;
    }
    try {
      await ref.read(projectEditorProvider).deleteEnvelopeElement(element.id);
    } catch (error) {
      _showError(messenger, error);
    }
  }

  Future<void> _handleAddOpening(
    BuildContext context,
    WidgetRef ref,
    HouseEnvelopeElement element,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final opening = await _showOpeningEditor(context, elementId: element.id);
    if (!context.mounted) {
      return;
    }
    if (opening == null) {
      return;
    }
    try {
      await ref.read(projectEditorProvider).addOpening(opening);
    } catch (error) {
      _showError(messenger, error);
    }
  }

  Future<void> _handleEditOpening(
    BuildContext context,
    WidgetRef ref,
    EnvelopeOpening opening,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final updated = await _showOpeningEditor(
      context,
      elementId: opening.elementId,
      opening: opening,
    );
    if (!context.mounted) {
      return;
    }
    if (updated == null) {
      return;
    }
    try {
      await ref.read(projectEditorProvider).updateOpening(updated);
    } catch (error) {
      _showError(messenger, error);
    }
  }

  Future<void> _handleDeleteOpening(
    BuildContext context,
    WidgetRef ref,
    EnvelopeOpening opening,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!context.mounted) {
      return;
    }
    try {
      await ref.read(projectEditorProvider).deleteOpening(opening.id);
    } catch (error) {
      _showError(messenger, error);
    }
  }

  Future<void> _handleAddConstruction(
    BuildContext context,
    WidgetRef ref,
    CatalogSnapshot catalog,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final construction = await _showConstructionEditor(
      context,
      catalog: catalog,
    );
    if (!context.mounted) {
      return;
    }
    if (construction == null) {
      return;
    }
    try {
      await ref.read(projectEditorProvider).addConstruction(construction);
    } catch (error) {
      _showError(messenger, error);
    }
  }

  Future<void> _handleEditConstruction(
    BuildContext context,
    WidgetRef ref,
    CatalogSnapshot catalog,
    Construction construction,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final updated = await _showConstructionEditor(
      context,
      catalog: catalog,
      construction: construction,
    );
    if (!context.mounted) {
      return;
    }
    if (updated == null) {
      return;
    }
    try {
      await ref.read(projectEditorProvider).updateConstruction(updated);
    } catch (error) {
      _showError(messenger, error);
    }
  }

  Future<void> _handleDeleteConstruction(
    BuildContext context,
    WidgetRef ref,
    Construction construction,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!context.mounted) {
      return;
    }
    try {
      await ref.read(projectEditorProvider).deleteConstruction(construction.id);
    } catch (error) {
      _showError(messenger, error);
    }
  }

  void _handleOpenThermocalc(
    BuildContext context,
    WidgetRef ref,
    HouseEnvelopeElement element,
  ) {
    ref.read(projectEditorProvider).selectEnvelopeElement(element);
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ThermocalcScreen()));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectAsync = ref.watch(selectedProjectProvider);
    final catalogAsync = ref.watch(catalogSnapshotProvider);
    final summaryAsync = ref.watch(houseThermalSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Сборка дома',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          const _StatusCard(),
          const SizedBox(height: 16),
          summaryAsync.when(
            data: (summary) => projectAsync.when(
              data: (project) {
                if (project == null || summary == null) {
                  return const Text('Активный проект не найден.');
                }
                return _SummaryCard(project: project, summary: summary);
              },
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text('Ошибка проекта: $error'),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text('Ошибка сводки: $error'),
          ),
          const SizedBox(height: 16),
          catalogAsync.when(
            data: (catalog) => projectAsync.when(
              data: (project) {
                if (project == null) {
                  return const Text('Активный проект не найден.');
                }
                return Column(
                  children: [
                    _PlanAndRoomsSection(
                      project: project,
                      onAddRoom: () => _handleAddRoom(context, ref, project),
                      onUpdateRoomLayout: (roomId, layout) =>
                          _handleUpdateRoomLayout(context, ref, roomId, layout),
                      onEditRoom: (room) => _handleEditRoom(context, ref, room),
                      onDeleteRoom: (room) =>
                          _handleDeleteRoom(context, ref, room),
                      onAddElement: (room) => _handleAddElement(
                        context,
                        ref,
                        project,
                        catalog,
                        room,
                      ),
                      onEditElement: (element) => _handleEditElement(
                        context,
                        ref,
                        project,
                        catalog,
                        element,
                      ),
                      onDeleteElement: (element) =>
                          _handleDeleteElement(context, ref, element),
                      onAddOpening: (element) =>
                          _handleAddOpening(context, ref, element),
                      onEditOpening: (opening) =>
                          _handleEditOpening(context, ref, opening),
                      onDeleteOpening: (opening) =>
                          _handleDeleteOpening(context, ref, opening),
                      onOpenThermocalc: (element) =>
                          _handleOpenThermocalc(context, ref, element),
                    ),
                    const SizedBox(height: 16),
                    _ConstructionsCard(
                      project: project,
                      catalog: catalog,
                      onAddConstruction: () =>
                          _handleAddConstruction(context, ref, catalog),
                      onEditConstruction: (construction) =>
                          _handleEditConstruction(
                            context,
                            ref,
                            catalog,
                            construction,
                          ),
                      onDeleteConstruction: (construction) =>
                          _handleDeleteConstruction(context, ref, construction),
                    ),
                  ],
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text('Ошибка проекта: $error'),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text('Ошибка каталога: $error'),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF2EEE4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Конструктор дома собирает проект сверху вниз: помещения, ограждения, окна/двери и переиспользуемые конструкции. Расчёт конструкции запускается прямо из выбранного ограждения, а сводка дома учитывает чистую площадь и проёмы.',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.project, required this.summary});

  final Project project;
  final HouseThermalSummary summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              project.houseModel.title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text('Проект: ${project.name}'),
            Text('Режим помещения для норм: ${project.roomPreset.label}'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _MetricTile(
                  label: 'Помещения',
                  value: '${project.houseModel.rooms.length}',
                ),
                _MetricTile(
                  label: 'Ограждения',
                  value: '${project.houseModel.elements.length}',
                ),
                _MetricTile(
                  label: 'Конструкции',
                  value: '${project.constructions.length}',
                ),
                _MetricTile(
                  label: 'Площадь помещений',
                  value:
                      '${summary.totalRoomAreaSquareMeters.toStringAsFixed(1)} м²',
                ),
                _MetricTile(
                  label: 'Площадь ограждений',
                  value:
                      '${summary.totalEnvelopeAreaSquareMeters.toStringAsFixed(1)} м²',
                ),
                _MetricTile(
                  label: 'Проёмы',
                  value:
                      '${summary.totalOpeningCount} / ${summary.totalOpeningAreaSquareMeters.toStringAsFixed(1)} м²',
                ),
                _MetricTile(
                  label: 'Чистая площадь',
                  value:
                      '${summary.totalOpaqueAreaSquareMeters.toStringAsFixed(1)} м²',
                ),
                _MetricTile(
                  label: 'Оценка потерь',
                  value: '${summary.totalHeatLossWatts.toStringAsFixed(0)} Вт',
                ),
                _MetricTile(
                  label: 'Через проёмы',
                  value:
                      '${summary.totalOpeningHeatLossWatts.toStringAsFixed(0)} Вт',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanAndRoomsSection extends StatefulWidget {
  const _PlanAndRoomsSection({
    required this.project,
    required this.onAddRoom,
    required this.onUpdateRoomLayout,
    required this.onEditRoom,
    required this.onDeleteRoom,
    required this.onAddElement,
    required this.onEditElement,
    required this.onDeleteElement,
    required this.onAddOpening,
    required this.onEditOpening,
    required this.onDeleteOpening,
    required this.onOpenThermocalc,
  });

  final Project project;
  final VoidCallback onAddRoom;
  final Future<void> Function(String roomId, RoomLayoutRect layout)
  onUpdateRoomLayout;
  final ValueChanged<Room> onEditRoom;
  final ValueChanged<Room> onDeleteRoom;
  final ValueChanged<Room> onAddElement;
  final ValueChanged<HouseEnvelopeElement> onEditElement;
  final ValueChanged<HouseEnvelopeElement> onDeleteElement;
  final ValueChanged<HouseEnvelopeElement> onAddOpening;
  final ValueChanged<EnvelopeOpening> onEditOpening;
  final ValueChanged<EnvelopeOpening> onDeleteOpening;
  final ValueChanged<HouseEnvelopeElement> onOpenThermocalc;

  @override
  State<_PlanAndRoomsSection> createState() => _PlanAndRoomsSectionState();
}

class _PlanAndRoomsSectionState extends State<_PlanAndRoomsSection> {
  String? _selectedRoomId;

  String? get _effectiveSelectedRoomId {
    final rooms = widget.project.houseModel.rooms;
    if (rooms.isEmpty) {
      return null;
    }
    final selectedRoomId = _selectedRoomId;
    final exists = rooms.any((room) => room.id == selectedRoomId);
    return exists ? selectedRoomId : rooms.first.id;
  }

  void _selectRoom(String roomId) {
    setState(() => _selectedRoomId = roomId);
  }

  @override
  Widget build(BuildContext context) {
    final selectedRoomId = _effectiveSelectedRoomId;
    return Column(
      children: [
        _FloorPlanCard(
          project: widget.project,
          selectedRoomId: selectedRoomId,
          onAddRoom: widget.onAddRoom,
          onSelectRoom: _selectRoom,
          onUpdateRoomLayout: widget.onUpdateRoomLayout,
        ),
        const SizedBox(height: 16),
        _RoomsCard(
          project: widget.project,
          selectedRoomId: selectedRoomId,
          onSelectRoom: _selectRoom,
          onAddRoom: widget.onAddRoom,
          onEditRoom: widget.onEditRoom,
          onDeleteRoom: widget.onDeleteRoom,
          onAddElement: widget.onAddElement,
          onEditElement: widget.onEditElement,
          onDeleteElement: widget.onDeleteElement,
          onAddOpening: widget.onAddOpening,
          onEditOpening: widget.onEditOpening,
          onDeleteOpening: widget.onDeleteOpening,
          onOpenThermocalc: widget.onOpenThermocalc,
        ),
      ],
    );
  }
}

class _FloorPlanCard extends StatefulWidget {
  const _FloorPlanCard({
    required this.project,
    required this.selectedRoomId,
    required this.onAddRoom,
    required this.onSelectRoom,
    required this.onUpdateRoomLayout,
  });

  final Project project;
  final String? selectedRoomId;
  final VoidCallback onAddRoom;
  final ValueChanged<String> onSelectRoom;
  final Future<void> Function(String roomId, RoomLayoutRect layout)
  onUpdateRoomLayout;

  @override
  State<_FloorPlanCard> createState() => _FloorPlanCardState();
}

class _FloorPlanCardState extends State<_FloorPlanCard> {
  static const double _pixelsPerMeter = 32;
  static const double _canvasPadding = 24;
  static const double _minimumCanvasWidthMeters = 14;
  static const double _minimumCanvasHeightMeters = 10;

  final Map<String, RoomLayoutRect> _draftLayouts = {};
  String? _activeRoomId;
  _RoomGestureMode? _activeMode;

  RoomLayoutRect _layoutForRoom(Room room) {
    return _draftLayouts[room.id] ?? room.layout;
  }

  void _startGesture(Room room, _RoomGestureMode mode) {
    widget.onSelectRoom(room.id);
    setState(() {
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
      _RoomGestureMode.move => _snapRoomLayout(
        currentLayout.copyWith(
          xMeters: currentLayout.xMeters + deltaXMeters,
          yMeters: currentLayout.yMeters + deltaYMeters,
        ),
      ),
      _RoomGestureMode.resize => _snapRoomLayout(
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
    if (draftLayout == null || _layoutsEqual(draftLayout, room.layout)) {
      return;
    }
    await widget.onUpdateRoomLayout(room.id, draftLayout);
  }

  @override
  Widget build(BuildContext context) {
    final rooms = widget.project.houseModel.rooms;
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
            _CardHeader(
              title: 'План дома',
              actionLabel: 'Добавить помещение',
              onAction: widget.onAddRoom,
            ),
            const SizedBox(height: 8),
            const Text(
              'Комнаты редактируются как прямоугольники на сетке 0.5 м. Потяните комнату для перемещения и маркер в углу для изменения размеров.',
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
                    boundaryMargin: const EdgeInsets.all(48),
                    child: SizedBox(
                      width: canvasWidth,
                      height: canvasHeight,
                      child: Stack(
                        children: [
                          CustomPaint(
                            size: Size(canvasWidth, canvasHeight),
                            painter: _FloorPlanGridPainter(
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
                              onTap: () => widget.onSelectRoom(room.id),
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

enum _RoomGestureMode { move, resize }

class _PositionedRoomTile extends StatelessWidget {
  const _PositionedRoomTile({
    required this.room,
    required this.layout,
    required this.pixelsPerMeter,
    required this.canvasPadding,
    required this.selected,
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
  final VoidCallback onTap;
  final VoidCallback onMoveStart;
  final GestureDragUpdateCallback onMoveUpdate;
  final VoidCallback onMoveEnd;
  final VoidCallback onResizeStart;
  final GestureDragUpdateCallback onResizeUpdate;
  final VoidCallback onResizeEnd;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: canvasPadding + layout.xMeters * pixelsPerMeter,
      top: canvasPadding + layout.yMeters * pixelsPerMeter,
      width: layout.widthMeters * pixelsPerMeter,
      height: layout.heightMeters * pixelsPerMeter,
      child: GestureDetector(
        onTap: onTap,
        onPanStart: (_) => onMoveStart(),
        onPanUpdate: onMoveUpdate,
        onPanEnd: (_) => onMoveEnd(),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFE9D5A8).withValues(alpha: 0.9)
                : const Color(0xFFDCC9A0).withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : const Color(0xFF6D6048),
              width: selected ? 2 : 1.2,
            ),
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
                  onPanStart: (_) => onResizeStart(),
                  onPanUpdate: onResizeUpdate,
                  onPanEnd: (_) => onResizeEnd(),
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
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

class _RoomsCard extends StatelessWidget {
  const _RoomsCard({
    required this.project,
    required this.selectedRoomId,
    required this.onSelectRoom,
    required this.onAddRoom,
    required this.onEditRoom,
    required this.onDeleteRoom,
    required this.onAddElement,
    required this.onEditElement,
    required this.onDeleteElement,
    required this.onAddOpening,
    required this.onEditOpening,
    required this.onDeleteOpening,
    required this.onOpenThermocalc,
  });

  final Project project;
  final String? selectedRoomId;
  final ValueChanged<String> onSelectRoom;
  final VoidCallback onAddRoom;
  final ValueChanged<Room> onEditRoom;
  final ValueChanged<Room> onDeleteRoom;
  final ValueChanged<Room> onAddElement;
  final ValueChanged<HouseEnvelopeElement> onEditElement;
  final ValueChanged<HouseEnvelopeElement> onDeleteElement;
  final ValueChanged<HouseEnvelopeElement> onAddOpening;
  final ValueChanged<EnvelopeOpening> onEditOpening;
  final ValueChanged<EnvelopeOpening> onDeleteOpening;
  final ValueChanged<HouseEnvelopeElement> onOpenThermocalc;

  @override
  Widget build(BuildContext context) {
    final constructionMap = {
      for (final construction in project.constructions)
        construction.id: construction,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardHeader(
              title: 'Помещения и ограждения',
              actionLabel: 'Добавить помещение',
              onAction: onAddRoom,
            ),
            const SizedBox(height: 12),
            ...project.houseModel.rooms.map((room) {
              final roomElements = project.houseModel.elements
                  .where((element) => element.roomId == room.id)
                  .toList(growable: false);
              final envelopeArea = roomElements.fold<double>(
                0,
                (sum, item) => sum + item.areaSquareMeters,
              );
              final roomElementIds = roomElements
                  .map((item) => item.id)
                  .toSet();
              final roomOpenings = project.houseModel.openings
                  .where(
                    (opening) => roomElementIds.contains(opening.elementId),
                  )
                  .toList(growable: false);
              final openingArea = roomOpenings.fold<double>(
                0,
                (sum, item) => sum + item.areaSquareMeters,
              );
              final opaqueArea = (envelopeArea - openingArea).clamp(
                0.0,
                envelopeArea,
              );
              final isSelected = selectedRoomId == room.id;

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => onSelectRoom(room.id),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFF1E8D6)
                          : const Color(0xFFF9F7F2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outlineVariant,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      room.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${room.kind.label} • ${room.areaSquareMeters.toStringAsFixed(1)} м² • h ${room.heightMeters.toStringAsFixed(1)} м',
                                    ),
                                    Text(
                                      'План: ${room.layout.widthMeters.toStringAsFixed(1)} x ${room.layout.heightMeters.toStringAsFixed(1)} м • позиция ${room.layout.xMeters.toStringAsFixed(1)} / ${room.layout.yMeters.toStringAsFixed(1)} м',
                                    ),
                                    Text(
                                      'Ограждений: ${roomElements.length}, проёмов: ${roomOpenings.length}, валовая площадь ${envelopeArea.toStringAsFixed(1)} м², чистая ${opaqueArea.toStringAsFixed(1)} м²',
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    onEditRoom(room);
                                  } else if (value == 'delete') {
                                    onDeleteRoom(room);
                                  }
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Редактировать помещение'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Удалить помещение'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          FilledButton.tonal(
                            onPressed: () => onAddElement(room),
                            child: const Text('Добавить ограждение'),
                          ),
                          const SizedBox(height: 12),
                          if (roomElements.isEmpty)
                            const Text('Пока нет ограждающих элементов.')
                          else
                            ...roomElements.map((element) {
                              final construction =
                                  constructionMap[element.constructionId];
                              final openings = project.houseModel.openings
                                  .where(
                                    (opening) =>
                                        opening.elementId == element.id,
                                  )
                                  .toList(growable: false);
                              final openingArea = openings.fold<double>(
                                0,
                                (sum, item) => sum + item.areaSquareMeters,
                              );
                              final opaqueArea =
                                  (element.areaSquareMeters - openingArea)
                                      .clamp(0.0, element.areaSquareMeters);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.outlineVariant,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        ListTile(
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 4,
                                                vertical: 0,
                                              ),
                                          title: Text(
                                            element.title,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          subtitle: Text(
                                            '${element.elementKind.label} • валовая площадь ${element.areaSquareMeters.toStringAsFixed(1)} м² • чистая ${opaqueArea.toStringAsFixed(1)} м²\n'
                                            'Проёмы: ${openings.length} / ${openingArea.toStringAsFixed(1)} м² • Конструкция: ${construction?.title ?? element.constructionId}',
                                          ),
                                          isThreeLine: true,
                                          trailing: PopupMenuButton<String>(
                                            onSelected: (value) {
                                              switch (value) {
                                                case 'calc':
                                                  onOpenThermocalc(element);
                                                case 'opening':
                                                  onAddOpening(element);
                                                case 'edit':
                                                  onEditElement(element);
                                                case 'delete':
                                                  onDeleteElement(element);
                                              }
                                            },
                                            itemBuilder: (context) => const [
                                              PopupMenuItem(
                                                value: 'calc',
                                                child: Text('Рассчитать'),
                                              ),
                                              PopupMenuItem(
                                                value: 'opening',
                                                child: Text('Добавить проём'),
                                              ),
                                              PopupMenuItem(
                                                value: 'edit',
                                                child: Text('Редактировать'),
                                              ),
                                              PopupMenuItem(
                                                value: 'delete',
                                                child: Text('Удалить'),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (openings.isEmpty)
                                          const Padding(
                                            padding: EdgeInsets.fromLTRB(
                                              16,
                                              4,
                                              16,
                                              4,
                                            ),
                                            child: Text('Проёмы не добавлены.'),
                                          )
                                        else
                                          ...openings.map(
                                            (opening) => Padding(
                                              padding: const EdgeInsets.only(
                                                left: 12,
                                                right: 12,
                                                bottom: 8,
                                              ),
                                              child: ListTile(
                                                tileColor: const Color(
                                                  0xFFF9F7F2,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                ),
                                                title: Text(
                                                  opening.title,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                subtitle: Text(
                                                  '${opening.kind.label} • ${opening.areaSquareMeters.toStringAsFixed(1)} м² • U ${opening.heatTransferCoefficient.toStringAsFixed(2)} Вт/м²·°C',
                                                ),
                                                trailing:
                                                    PopupMenuButton<String>(
                                                      onSelected: (value) {
                                                        if (value == 'edit') {
                                                          onEditOpening(
                                                            opening,
                                                          );
                                                        } else if (value ==
                                                            'delete') {
                                                          onDeleteOpening(
                                                            opening,
                                                          );
                                                        }
                                                      },
                                                      itemBuilder: (context) =>
                                                          const [
                                                            PopupMenuItem(
                                                              value: 'edit',
                                                              child: Text(
                                                                'Редактировать',
                                                              ),
                                                            ),
                                                            PopupMenuItem(
                                                              value: 'delete',
                                                              child: Text(
                                                                'Удалить',
                                                              ),
                                                            ),
                                                          ],
                                                    ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _ConstructionsCard extends StatelessWidget {
  const _ConstructionsCard({
    required this.project,
    required this.catalog,
    required this.onAddConstruction,
    required this.onEditConstruction,
    required this.onDeleteConstruction,
  });

  final Project project;
  final CatalogSnapshot catalog;
  final VoidCallback onAddConstruction;
  final ValueChanged<Construction> onEditConstruction;
  final ValueChanged<Construction> onDeleteConstruction;

  @override
  Widget build(BuildContext context) {
    final usageMap = <String, int>{};
    for (final element in project.houseModel.elements) {
      usageMap[element.constructionId] =
          (usageMap[element.constructionId] ?? 0) + 1;
    }
    final materialMap = {for (final item in catalog.materials) item.id: item};

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardHeader(
              title: 'Конструкции',
              actionLabel: 'Добавить конструкцию',
              onAction: onAddConstruction,
            ),
            const SizedBox(height: 12),
            ...project.constructions.map((construction) {
              final layerTitles = construction.layers
                  .map(
                    (layer) =>
                        materialMap[layer.materialId]?.name ?? layer.materialId,
                  )
                  .join(', ');
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  title: Text(
                    construction.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${construction.elementKind.label} • слоёв ${construction.layers.length} • используется ${usageMap[construction.id] ?? 0} раз(а)\n'
                    '$layerTitles',
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        onEditConstruction(construction);
                      } else if (value == 'delete') {
                        onDeleteConstruction(construction);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: Text('Редактировать конструкцию'),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Удалить конструкцию'),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        FilledButton.tonal(onPressed: onAction, child: Text(actionLabel)),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 148,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(label),
        ],
      ),
    );
  }
}

Future<Room?> _showRoomEditor(
  BuildContext context, {
  Room? room,
  RoomLayoutRect? initialLayout,
}) async {
  final titleController = TextEditingController(text: room?.title ?? '');
  final heightController = TextEditingController(
    text: (room?.heightMeters ?? defaultRoomHeightMeters).toString(),
  );
  var selectedKind = room?.kind ?? RoomKind.livingRoom;
  final effectiveLayout =
      room?.layout ?? initialLayout ?? RoomLayoutRect.defaultRect();

  final result = await showModalBottomSheet<Room>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              20 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  room == null ? 'Новое помещение' : 'Редактирование помещения',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Название'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<RoomKind>(
                  initialValue: selectedKind,
                  decoration: const InputDecoration(labelText: 'Тип помещения'),
                  items: RoomKind.values
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedKind = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Площадь на плане',
                  ),
                  child: Text(
                    '${effectiveLayout.areaSquareMeters.toStringAsFixed(1)} м²',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Размеры и позиция комнаты редактируются на плане.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: heightController,
                  decoration: const InputDecoration(labelText: 'Высота, м'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop(
                      Room(
                        id: room?.id ?? _buildId('room'),
                        title: _requiredText(
                          titleController.text,
                          fallback: selectedKind.label,
                        ),
                        kind: selectedKind,
                        heightMeters: _parseDouble(
                          heightController.text,
                          fallback: defaultRoomHeightMeters,
                        ),
                        layout: effectiveLayout,
                      ),
                    );
                  },
                  child: const Text('Сохранить'),
                ),
              ],
            ),
          );
        },
      );
    },
  );

  titleController.dispose();
  heightController.dispose();
  return result;
}

Future<HouseEnvelopeElement?> _showElementEditor(
  BuildContext context, {
  required Project project,
  required CatalogSnapshot catalog,
  required String roomId,
  HouseEnvelopeElement? element,
}) async {
  final titleController = TextEditingController(text: element?.title ?? '');
  final areaController = TextEditingController(
    text: (element?.areaSquareMeters ?? defaultHouseElementAreaSquareMeters)
        .toString(),
  );
  var selectedRoomId = element?.roomId ?? roomId;
  var selectedConstructionId =
      element?.constructionId ??
      (project.constructions.isEmpty ? null : project.constructions.first.id);
  var selectedKind = element?.elementKind ?? ConstructionElementKind.wall;

  final result = await showModalBottomSheet<HouseEnvelopeElement>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              20 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  element == null
                      ? 'Новое ограждение'
                      : 'Редактирование ограждения',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Название'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedRoomId,
                  decoration: const InputDecoration(labelText: 'Помещение'),
                  items: project.houseModel.rooms
                      .map(
                        (room) => DropdownMenuItem(
                          value: room.id,
                          child: Text(room.title),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedRoomId = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ConstructionElementKind>(
                  initialValue: selectedKind,
                  decoration: const InputDecoration(
                    labelText: 'Тип ограждения',
                  ),
                  items: ConstructionElementKind.values
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedKind = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedConstructionId,
                  decoration: const InputDecoration(labelText: 'Конструкция'),
                  items: project.constructions
                      .map(
                        (construction) => DropdownMenuItem(
                          value: construction.id,
                          child: Text(construction.title),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedConstructionId = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: areaController,
                  decoration: const InputDecoration(labelText: 'Площадь, м²'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: selectedConstructionId == null
                      ? null
                      : () {
                          final selectedConstruction = project.constructions
                              .firstWhere(
                                (item) => item.id == selectedConstructionId,
                              );
                          Navigator.of(context).pop(
                            HouseEnvelopeElement(
                              id: element?.id ?? _buildId('element'),
                              roomId: selectedRoomId,
                              title: _requiredText(
                                titleController.text,
                                fallback: selectedKind.label,
                              ),
                              elementKind: selectedConstruction.elementKind,
                              areaSquareMeters: _parseDouble(
                                areaController.text,
                                fallback: defaultHouseElementAreaSquareMeters,
                              ),
                              constructionId: selectedConstruction.id,
                            ),
                          );
                        },
                  child: const Text('Сохранить'),
                ),
                if (catalog.materials.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text('Каталог материалов пуст.'),
                  ),
              ],
            ),
          );
        },
      );
    },
  );

  titleController.dispose();
  areaController.dispose();
  return result;
}

Future<Construction?> _showConstructionEditor(
  BuildContext context, {
  required CatalogSnapshot catalog,
  Construction? construction,
}) async {
  final titleController = TextEditingController(
    text: construction?.title ?? '',
  );
  var selectedKind = construction?.elementKind ?? ConstructionElementKind.wall;
  final layers = [...?construction?.layers];
  if (layers.isEmpty && catalog.materials.isNotEmpty) {
    layers.add(
      ConstructionLayer(
        id: _buildId('layer'),
        materialId: catalog.materials.first.id,
        kind: LayerKind.solid,
        thicknessMm: 100,
      ),
    );
  }

  final result = await showModalBottomSheet<Construction>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          final materialMap = {
            for (final item in catalog.materials) item.id: item,
          };
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              20 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  construction == null
                      ? 'Новая конструкция'
                      : 'Редактирование конструкции',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Название'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ConstructionElementKind>(
                  initialValue: selectedKind,
                  decoration: const InputDecoration(
                    labelText: 'Тип конструкции',
                  ),
                  items: ConstructionElementKind.values
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedKind = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      'Слои конструкции',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () async {
                        final layer = await _showLayerEditor(
                          context,
                          catalog: catalog,
                        );
                        if (layer != null) {
                          setState(() => layers.add(layer));
                        }
                      },
                      child: const Text('Добавить слой'),
                    ),
                  ],
                ),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        ...layers.asMap().entries.map((entry) {
                          final index = entry.key;
                          final layer = entry.value;
                          final material = materialMap[layer.materialId];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              tileColor: const Color(0xFFF9F7F2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              title: Text(material?.name ?? layer.materialId),
                              subtitle: Text(
                                '${layer.kind.label} • ${layer.thicknessMm.toStringAsFixed(0)} мм • ${layer.enabled ? 'в расчёте' : 'выключен'}',
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) async {
                                  switch (value) {
                                    case 'up':
                                      if (index > 0) {
                                        final moved = layers.removeAt(index);
                                        layers.insert(index - 1, moved);
                                        setState(() {});
                                      }
                                    case 'down':
                                      if (index < layers.length - 1) {
                                        final moved = layers.removeAt(index);
                                        layers.insert(index + 1, moved);
                                        setState(() {});
                                      }
                                    case 'toggle':
                                      layers[index] = layer.copyWith(
                                        enabled: !layer.enabled,
                                      );
                                      setState(() {});
                                    case 'edit':
                                      final updated = await _showLayerEditor(
                                        context,
                                        catalog: catalog,
                                        layer: layer,
                                      );
                                      if (updated != null) {
                                        layers[index] = updated;
                                        setState(() {});
                                      }
                                    case 'delete':
                                      layers.removeAt(index);
                                      setState(() {});
                                  }
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    value: 'up',
                                    child: Text('Переместить внутрь'),
                                  ),
                                  PopupMenuItem(
                                    value: 'down',
                                    child: Text('Переместить наружу'),
                                  ),
                                  PopupMenuItem(
                                    value: 'toggle',
                                    child: Text('Вкл/выкл слой'),
                                  ),
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Редактировать слой'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Удалить слой'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: layers.isEmpty
                      ? null
                      : () {
                          Navigator.of(context).pop(
                            Construction(
                              id: construction?.id ?? _buildId('construction'),
                              title: _requiredText(
                                titleController.text,
                                fallback: selectedKind.label,
                              ),
                              elementKind: selectedKind,
                              layers: List.unmodifiable(layers),
                            ),
                          );
                        },
                  child: const Text('Сохранить'),
                ),
              ],
            ),
          );
        },
      );
    },
  );

  titleController.dispose();
  return result;
}

Future<EnvelopeOpening?> _showOpeningEditor(
  BuildContext context, {
  required String elementId,
  EnvelopeOpening? opening,
}) async {
  final titleController = TextEditingController(text: opening?.title ?? '');
  final areaController = TextEditingController(
    text: (opening?.areaSquareMeters ?? 2.0).toString(),
  );
  final coefficientController = TextEditingController(
    text:
        (opening?.heatTransferCoefficient ??
                (opening?.kind ?? OpeningKind.window)
                    .defaultHeatTransferCoefficient)
            .toString(),
  );
  var selectedKind = opening?.kind ?? OpeningKind.window;

  final result = await showModalBottomSheet<EnvelopeOpening>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              20 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  opening == null ? 'Новый проём' : 'Редактирование проёма',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<OpeningKind>(
                  initialValue: selectedKind,
                  decoration: const InputDecoration(labelText: 'Тип проёма'),
                  items: OpeningKind.values
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedKind = value;
                        if (opening == null &&
                            coefficientController.text.trim().isEmpty) {
                          coefficientController.text = value
                              .defaultHeatTransferCoefficient
                              .toString();
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Название'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: areaController,
                  decoration: const InputDecoration(labelText: 'Площадь, м²'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: coefficientController,
                  decoration: const InputDecoration(labelText: 'U, Вт/м²·°C'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop(
                      EnvelopeOpening(
                        id: opening?.id ?? _buildId('opening'),
                        elementId: elementId,
                        title: _requiredText(
                          titleController.text,
                          fallback: selectedKind.label,
                        ),
                        kind: selectedKind,
                        areaSquareMeters: _parseDouble(
                          areaController.text,
                          fallback: 2.0,
                        ),
                        heatTransferCoefficient: _parseDouble(
                          coefficientController.text,
                          fallback: selectedKind.defaultHeatTransferCoefficient,
                        ),
                      ),
                    );
                  },
                  child: const Text('Сохранить проём'),
                ),
              ],
            ),
          );
        },
      );
    },
  );

  titleController.dispose();
  areaController.dispose();
  coefficientController.dispose();
  return result;
}

Future<ConstructionLayer?> _showLayerEditor(
  BuildContext context, {
  required CatalogSnapshot catalog,
  ConstructionLayer? layer,
}) async {
  if (catalog.materials.isEmpty) {
    return null;
  }
  final thicknessController = TextEditingController(
    text: (layer?.thicknessMm ?? 100).toString(),
  );
  var selectedMaterialId = layer?.materialId ?? catalog.materials.first.id;
  var selectedKind = layer?.kind ?? LayerKind.solid;
  var enabled = layer?.enabled ?? true;

  final result = await showModalBottomSheet<ConstructionLayer>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              20 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedMaterialId,
                  decoration: const InputDecoration(labelText: 'Материал'),
                  items: catalog.materials
                      .map(
                        (item) => DropdownMenuItem(
                          value: item.id,
                          child: Text(item.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedMaterialId = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<LayerKind>(
                  initialValue: selectedKind,
                  decoration: const InputDecoration(labelText: 'Тип слоя'),
                  items: LayerKind.values
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedKind = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: thicknessController,
                  decoration: const InputDecoration(labelText: 'Толщина, мм'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Учитывать в расчёте'),
                  value: enabled,
                  onChanged: (value) => setState(() => enabled = value),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop(
                      ConstructionLayer(
                        id: layer?.id ?? _buildId('layer'),
                        materialId: selectedMaterialId,
                        kind: selectedKind,
                        thicknessMm: _parseDouble(
                          thicknessController.text,
                          fallback: 100,
                        ),
                        enabled: enabled,
                      ),
                    );
                  },
                  child: const Text('Сохранить слой'),
                ),
              ],
            ),
          );
        },
      );
    },
  );

  thicknessController.dispose();
  return result;
}

String _buildId(String prefix) {
  return '$prefix-${DateTime.now().microsecondsSinceEpoch}';
}

RoomLayoutRect _buildNextRoomLayout(List<Room> rooms) {
  if (rooms.isEmpty) {
    return RoomLayoutRect.defaultRect();
  }
  final lastRoom = rooms.last;
  return RoomLayoutRect.defaultRect(
    xMeters: lastRoom.layout.rightMeters + roomLayoutGapMeters,
    yMeters: lastRoom.layout.yMeters,
  );
}

RoomLayoutRect _snapRoomLayout(RoomLayoutRect layout) {
  return RoomLayoutRect(
    xMeters: _snapToStep(layout.xMeters),
    yMeters: _snapToStep(layout.yMeters),
    widthMeters: math.max(
      minimumRoomLayoutDimensionMeters,
      _snapToStep(layout.widthMeters),
    ),
    heightMeters: math.max(
      minimumRoomLayoutDimensionMeters,
      _snapToStep(layout.heightMeters),
    ),
  );
}

double _snapToStep(double value) {
  return (value / roomLayoutSnapStepMeters).round() * roomLayoutSnapStepMeters;
}

bool _layoutsEqual(RoomLayoutRect left, RoomLayoutRect right) {
  return left.xMeters == right.xMeters &&
      left.yMeters == right.yMeters &&
      left.widthMeters == right.widthMeters &&
      left.heightMeters == right.heightMeters;
}

double _parseDouble(String value, {required double fallback}) {
  return double.tryParse(value.replaceAll(',', '.')) ?? fallback;
}

String _requiredText(String value, {required String fallback}) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? fallback : trimmed;
}

void _showError(ScaffoldMessengerState messenger, Object error) {
  messenger.showSnackBar(
    SnackBar(content: Text('Не удалось выполнить действие: $error')),
  );
}
