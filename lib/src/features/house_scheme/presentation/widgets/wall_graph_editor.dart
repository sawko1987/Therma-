import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/catalog.dart';
import '../../../../core/models/project.dart';
import '../../../../core/providers.dart';
import '../floor_plan_geometry.dart';

class WallGraphEditorScreen extends ConsumerWidget {
  const WallGraphEditorScreen({
    super.key,
    required this.project,
    required this.catalog,
    this.startInDrawMode = false,
  });

  final Project project;
  final CatalogSnapshot catalog;
  final bool startInDrawMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentProject = ref
        .watch(selectedProjectProvider)
        .maybeWhen(data: (value) => value ?? project, orElse: () => project);
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Редактор плана',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: WallGraphEditor(
            project: currentProject,
            catalog: catalog,
            startInDrawMode: startInDrawMode,
            useCardDecoration: false,
          ),
        ),
      ),
    );
  }
}

class WallGraphOverviewCard extends StatelessWidget {
  const WallGraphOverviewCard({
    super.key,
    required this.project,
    required this.onCreateContour,
    required this.onOpenEditor,
  });

  final Project project;
  final VoidCallback onCreateContour;
  final VoidCallback onOpenEditor;

  @override
  Widget build(BuildContext context) {
    final roomCount = project.houseModel.rooms.length;
    final wallCount = project.houseModel.planWalls.length;
    final openingCount = project.houseModel.planWallOpenings.length;
    final roomArea = project.houseModel.totalRoomAreaSquareMeters;
    final hasPlan = roomCount > 0 || wallCount > 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'План дома',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              hasPlan
                  ? 'Контур плана показан в обзорном режиме. Для редактирования откройте отдельный экран.'
                  : 'Контур ещё не создан. Начните с кнопки «Новый контур».',
            ),
            const SizedBox(height: 12),
            GestureDetector(
              key: const ValueKey('wall-graph-overview-preview'),
              onTap: onOpenEditor,
              child: AbsorbPointer(
                child: WallGraphPreview(
                  project: project,
                  height: 320,
                  emptyLabel:
                      'Контур здания ещё не нарисован. Нажмите «Новый контур».',
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _OverviewMetric(label: 'Помещения', value: '$roomCount'),
                _OverviewMetric(label: 'Стены', value: '$wallCount'),
                _OverviewMetric(label: 'Проёмы', value: '$openingCount'),
                _OverviewMetric(
                  label: 'Площадь',
                  value: '${roomArea.toStringAsFixed(1)} м²',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  key: const ValueKey('open-wall-graph-create-contour-button'),
                  onPressed: onCreateContour,
                  icon: const Icon(Icons.draw_outlined),
                  label: const Text('Новый контур'),
                ),
                FilledButton.tonalIcon(
                  key: const ValueKey('open-wall-graph-editor-button'),
                  onPressed: onOpenEditor,
                  icon: const Icon(Icons.fullscreen),
                  label: const Text('Открыть редактор'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class WallGraphPreview extends StatelessWidget {
  const WallGraphPreview({
    super.key,
    required this.project,
    this.height = 520,
    this.emptyLabel,
  });

  final Project project;
  final double height;
  final String? emptyLabel;

  @override
  Widget build(BuildContext context) {
    final canvas = _WallGraphCanvas(
      project: project,
      selectedRoomId: null,
      selectedWallIds: const {},
      selectedNodeId: null,
      draftPoints: const [],
      canvasKey: const ValueKey('wall-graph-preview-canvas'),
      onCanvasTapDown: null,
      onRoomTap: null,
      onWallTap: null,
      onWallLongPress: null,
      onWallDrag: null,
      onNodeTap: null,
      onNodeDrag: null,
      gridStepMeters: 0.2,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF7F3EA),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: SizedBox(
          height: height,
          child: Stack(
            children: [
              Positioned.fill(child: canvas),
              if (project.houseModel.planWalls.isEmpty &&
                  project.houseModel.rooms.isEmpty)
                Positioned.fill(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        emptyLabel ?? 'План пока пуст.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
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

class WallGraphEditor extends ConsumerStatefulWidget {
  const WallGraphEditor({
    super.key,
    required this.project,
    required this.catalog,
    this.startInDrawMode = false,
    this.useCardDecoration = true,
  });

  final Project project;
  final CatalogSnapshot catalog;
  final bool startInDrawMode;
  final bool useCardDecoration;

  @override
  ConsumerState<WallGraphEditor> createState() => _WallGraphEditorState();
}

class _WallGraphEditorState extends ConsumerState<WallGraphEditor> {
  final TextEditingController _roomTitleController = TextEditingController();
  final TextEditingController _roomHeightController = TextEditingController();
  static const List<double> _availableGridStepsMeters = [0.1, 0.2, 0.5];

  late bool _drawMode = widget.startInDrawMode;
  List<Offset> _draftPoints = const [];
  String? _selectedRoomId;
  String? _selectedWallId;
  String? _selectedNodeId;
  bool _multiSelectMode = false;
  bool _orthogonalConstraint = true;
  double _gridStepMeters = 0.2;
  final Set<String> _selectedWallIds = {};
  RoomKind _selectedRoomKind = RoomKind.livingRoom;
  String? _selectedFloorConstructionId;
  String? _selectedTopConstructionId;

  @override
  void didUpdateWidget(covariant WallGraphEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.startInDrawMode && !oldWidget.startInDrawMode) {
      _drawMode = true;
    }
  }

  @override
  void dispose() {
    _roomTitleController.dispose();
    _roomHeightController.dispose();
    super.dispose();
  }

  List<PlanNode> get _nodes => widget.project.houseModel.planNodes;
  List<PlanWall> get _walls => widget.project.houseModel.planWalls;
  List<PlanWallOpening> get _openings =>
      widget.project.houseModel.planWallOpenings;

  Map<String, PlanNode> get _nodeMap => {
    for (final node in _nodes) node.id: node,
  };

  PlanWall? get _selectedWall => _selectedWallId == null
      ? null
      : _walls.where((item) => item.id == _selectedWallId).firstOrNull;

  Room? get _selectedRoom => _selectedRoomId == null
      ? null
      : widget.project.houseModel.rooms
            .where((item) => item.id == _selectedRoomId)
            .firstOrNull;

  Future<void> _saveWallPlan({
    required List<PlanNode> nodes,
    required List<PlanWall> walls,
    required List<PlanWallOpening> openings,
  }) async {
    try {
      final updated = await ref
          .read(projectEditorProvider)
          .syncWallPlan(nodes: nodes, walls: walls, openings: openings);
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedRoomId =
            updated.houseModel.rooms.any((item) => item.id == _selectedRoomId)
            ? _selectedRoomId
            : updated.houseModel.rooms.firstOrNull?.id;
        _selectedWallId =
            updated.houseModel.planWalls.any(
              (item) => item.id == _selectedWallId,
            )
            ? _selectedWallId
            : null;
        _selectedWallIds.removeWhere(
          (wallId) =>
              !updated.houseModel.planWalls.any((item) => item.id == wallId),
        );
        _selectedNodeId =
            updated.houseModel.planNodes.any(
              (item) => item.id == _selectedNodeId,
            )
            ? _selectedNodeId
            : null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  void _toggleDrawMode() {
    setState(() {
      _drawMode = !_drawMode;
      if (!_drawMode) {
        _draftPoints = const [];
      }
      _selectedRoomId = null;
      _selectedWallId = null;
      _selectedNodeId = null;
      _selectedWallIds.clear();
      _multiSelectMode = false;
    });
  }

  void _handleCanvasTap(TapDownDetails details) {
    if (!_drawMode) {
      setState(() {
        _selectedRoomId = null;
        _selectedWallId = null;
        if (!_multiSelectMode) {
          _selectedWallIds.clear();
        }
      });
      return;
    }
    final snapped = _snapLocalOffset(details.localPosition);
    setState(() {
      if (_draftPoints.isEmpty) {
        _draftPoints = [snapped];
        return;
      }
      final last = _draftPoints.last;
      var next = snapped;
      if (_orthogonalConstraint) {
        final dx = (snapped.dx - last.dx).abs();
        final dy = (snapped.dy - last.dy).abs();
        if (dx >= dy) {
          next = Offset(snapped.dx, last.dy);
        } else {
          next = Offset(last.dx, snapped.dy);
        }
      }
      if (_draftPoints.length >= 3 &&
          (next - _draftPoints.first).distance <= _gridStepMeters * 1.5) {
        next = _draftPoints.first;
      }
      if (next == last) {
        return;
      }
      _draftPoints = [..._draftPoints, next];
    });
  }

  Offset _snapLocalOffset(Offset localPosition) {
    const xPadding = _WallGraphCanvas.canvasPadding;
    const yPadding = _WallGraphCanvas.canvasPadding;
    const ppm = _WallGraphCanvas.pixelsPerMeter;
    final xMeters = _snapToGrid((localPosition.dx - xPadding) / ppm);
    final yMeters = _snapToGrid((localPosition.dy - yPadding) / ppm);
    return Offset(math.max(0, xMeters), math.max(0, yMeters));
  }

  double _snapToGrid(double value) {
    return (value / _gridStepMeters).round() * _gridStepMeters;
  }

  Future<void> _commitContour() async {
    if (_draftPoints.length < 4 || _draftPoints.last != _draftPoints.first) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Замкните контур комнаты.')));
      return;
    }
    final defaultWallConstruction = widget.project.constructions
        .where((item) => item.elementKind == ConstructionElementKind.wall)
        .firstOrNull;
    if (defaultWallConstruction == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Сначала добавьте хотя бы одну стеновую конструкцию.'),
        ),
      );
      return;
    }
    final nodes = [..._nodes];
    final walls = [..._walls];
    final nodeIdByKey = {
      for (final node in nodes) '${node.xMeters}:${node.yMeters}': node.id,
    };
    String ensureNodeId(Offset point) {
      final key = '${point.dx}:${point.dy}';
      final existing = nodeIdByKey[key];
      if (existing != null) {
        return existing;
      }
      final id =
          'plan-node-${DateTime.now().microsecondsSinceEpoch}-${nodes.length}';
      nodes.add(PlanNode(id: id, xMeters: point.dx, yMeters: point.dy));
      nodeIdByKey[key] = id;
      return id;
    }

    for (var index = 0; index < _draftPoints.length - 1; index++) {
      final startId = ensureNodeId(_draftPoints[index]);
      final endId = ensureNodeId(_draftPoints[index + 1]);
      walls.add(
        PlanWall(
          id: 'plan-wall-${DateTime.now().microsecondsSinceEpoch}-$index',
          startNodeId: startId,
          endNodeId: endId,
          constructionId: defaultWallConstruction.id,
        ),
      );
    }
    await _saveWallPlan(nodes: nodes, walls: walls, openings: _openings);
    if (!mounted) {
      return;
    }
    setState(() {
      _draftPoints = const [];
      _drawMode = false;
    });
  }

  Future<void> _moveWall(PlanWall wall, DragUpdateDetails details) async {
    final nodeMap = _nodeMap;
    final start = nodeMap[wall.startNodeId]!;
    final end = nodeMap[wall.endNodeId]!;
    final segment = HouseLineSegment(
      startXMeters: start.xMeters,
      startYMeters: start.yMeters,
      endXMeters: end.xMeters,
      endYMeters: end.yMeters,
    ).normalized();
    final deltaMeters = segment.isHorizontal
        ? _snapToGrid(details.delta.dy / _WallGraphCanvas.pixelsPerMeter)
        : segment.isVertical
        ? _snapToGrid(details.delta.dx / _WallGraphCanvas.pixelsPerMeter)
        : 0.0;
    if (deltaMeters == 0) {
      return;
    }
    final nextNodes = [
      for (final node in _nodes)
        if (node.id == start.id || node.id == end.id)
          segment.isHorizontal
              ? node.copyWith(yMeters: math.max(0, node.yMeters + deltaMeters))
              : node.copyWith(xMeters: math.max(0, node.xMeters + deltaMeters))
        else
          node,
    ];
    await _saveWallPlan(nodes: nextNodes, walls: _walls, openings: _openings);
  }

  Future<void> _deleteSelectedWall() async {
    final wall = _selectedWall;
    if (wall == null) {
      return;
    }
    final nextWalls = [
      for (final item in _walls)
        if (item.id != wall.id) item,
    ];
    final usedNodeIds = {
      for (final item in nextWalls) item.startNodeId,
      for (final item in nextWalls) item.endNodeId,
    };
    final nextNodes = [
      for (final item in _nodes)
        if (usedNodeIds.contains(item.id)) item,
    ];
    final nextOpenings = [
      for (final item in _openings)
        if (item.wallId != wall.id) item,
    ];
    await _saveWallPlan(
      nodes: nextNodes,
      walls: nextWalls,
      openings: nextOpenings,
    );
  }

  Future<void> _applyConstructionToSelectedWalls(String constructionId) async {
    if (_selectedWallIds.isEmpty) {
      return;
    }
    try {
      await ref
          .read(projectEditorProvider)
          .assignConstructionToPlanWalls(_selectedWallIds, constructionId);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _saveSelectedRoom() async {
    final room = _selectedRoom;
    if (room == null) {
      return;
    }
    try {
      await ref
          .read(projectEditorProvider)
          .updateRoom(
            room.copyWith(
              title: _roomTitleController.text.trim().isEmpty
                  ? room.title
                  : _roomTitleController.text.trim(),
              kind: _selectedRoomKind,
              heightMeters:
                  double.tryParse(
                    _roomHeightController.text.replaceAll(',', '.'),
                  ) ??
                  room.heightMeters,
            ),
          );
      await ref
          .read(projectEditorProvider)
          .configureRoomEnvelope(
            room.id,
            floorConstructionId: _selectedFloorConstructionId,
            topConstructionId: _selectedTopConstructionId,
          );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _addOpeningToSelectedWall(OpeningKind kind) async {
    final wall = _selectedWall;
    if (wall == null) {
      return;
    }
    final titleController = TextEditingController(text: kind.label);
    final areaController = TextEditingController(
      text: kind == OpeningKind.window ? '2.0' : '1.8',
    );
    final coefficientController = TextEditingController(
      text: kind.defaultHeatTransferCoefficient.toStringAsFixed(2),
    );
    var selectedLeakage = OpeningLeakagePreset.standard;
    final result = await showModalBottomSheet<PlanWallOpening>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('wall-graph-opening-title-field'),
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Название'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('wall-graph-opening-area-field'),
              controller: areaController,
              decoration: const InputDecoration(labelText: 'Площадь, м²'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('wall-graph-opening-u-field'),
              controller: coefficientController,
              decoration: const InputDecoration(labelText: 'U, Вт/м²·°C'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<OpeningLeakagePreset>(
              key: const ValueKey('wall-graph-opening-leakage-field'),
              initialValue: selectedLeakage,
              decoration: const InputDecoration(labelText: 'Герметичность'),
              items: OpeningLeakagePreset.values
                  .map(
                    (item) =>
                        DropdownMenuItem(value: item, child: Text(item.label)),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) {
                  selectedLeakage = value;
                }
              },
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const ValueKey('wall-graph-save-opening-button'),
              onPressed: () {
                Navigator.of(context).pop(
                  PlanWallOpening(
                    id: 'plan-opening-${DateTime.now().microsecondsSinceEpoch}',
                    wallId: wall.id,
                    title: titleController.text.trim().isEmpty
                        ? kind.label
                        : titleController.text.trim(),
                    kind: kind,
                    areaSquareMeters:
                        double.tryParse(
                          areaController.text.replaceAll(',', '.'),
                        ) ??
                        2.0,
                    heatTransferCoefficient:
                        double.tryParse(
                          coefficientController.text.replaceAll(',', '.'),
                        ) ??
                        kind.defaultHeatTransferCoefficient,
                    leakagePreset: selectedLeakage,
                  ),
                );
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
    titleController.dispose();
    areaController.dispose();
    coefficientController.dispose();
    if (result == null) {
      return;
    }
    try {
      await ref.read(projectEditorProvider).addPlanWallOpening(result);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  void _selectRoom(Room room) {
    setState(() {
      _selectedRoomId = room.id;
      _selectedWallId = null;
      _selectedNodeId = null;
      if (!_multiSelectMode) {
        _selectedWallIds.clear();
      }
      _roomTitleController.text = room.title;
      _roomHeightController.text = room.heightMeters.toStringAsFixed(1);
      _selectedRoomKind = room.kind;
      _selectedFloorConstructionId = widget.project.houseModel.elements
          .where((item) => item.id == 'auto-floor-${room.id}')
          .firstOrNull
          ?.constructionId;
      _selectedTopConstructionId = widget.project.houseModel.elements
          .where((item) => item.id == 'auto-top-${room.id}')
          .firstOrNull
          ?.constructionId;
    });
  }

  void _selectWall(String wallId) {
    setState(() {
      _selectedWallId = wallId;
      _selectedRoomId = null;
      _selectedNodeId = null;
      if (_multiSelectMode) {
        if (_selectedWallIds.contains(wallId)) {
          _selectedWallIds.remove(wallId);
        } else {
          _selectedWallIds.add(wallId);
        }
      } else {
        _selectedWallIds
          ..clear()
          ..add(wallId);
      }
    });
  }

  void _selectNode(String nodeId) {
    setState(() {
      _selectedNodeId = nodeId;
      _selectedRoomId = null;
      _selectedWallId = null;
      if (!_multiSelectMode) {
        _selectedWallIds.clear();
      }
    });
  }

  Future<void> _moveNode(String nodeId, DragUpdateDetails details) async {
    final dx = _snapToGrid(details.delta.dx / _WallGraphCanvas.pixelsPerMeter);
    final dy = _snapToGrid(details.delta.dy / _WallGraphCanvas.pixelsPerMeter);
    if (dx == 0 && dy == 0) {
      return;
    }
    final nextNodes = [
      for (final node in _nodes)
        if (node.id == nodeId)
          node.copyWith(
            xMeters: math.max(0, node.xMeters + dx),
            yMeters: math.max(0, node.yMeters + dy),
          )
        else
          node,
    ];
    await _saveWallPlan(nodes: nextNodes, walls: _walls, openings: _openings);
  }

  Future<void> _splitSelectedWall() async {
    final wall = _selectedWall;
    if (wall == null) {
      return;
    }
    if (_openings.any((item) => item.wallId == wall.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Нельзя разрезать стену с проёмами. Сначала удалите проёмы.',
          ),
        ),
      );
      return;
    }
    final start = _nodeMap[wall.startNodeId];
    final end = _nodeMap[wall.endNodeId];
    if (start == null || end == null) {
      return;
    }
    final midpoint = Offset(
      _snapToGrid((start.xMeters + end.xMeters) / 2),
      _snapToGrid((start.yMeters + end.yMeters) / 2),
    );
    final midpointKey = '${midpoint.dx}:${midpoint.dy}';
    final nodeIdByKey = {
      for (final node in _nodes) '${node.xMeters}:${node.yMeters}': node.id,
    };
    var midpointId = nodeIdByKey[midpointKey];
    final nextNodes = [..._nodes];
    if (midpointId == null) {
      midpointId = 'plan-node-${DateTime.now().microsecondsSinceEpoch}-split';
      nextNodes.add(
        PlanNode(id: midpointId, xMeters: midpoint.dx, yMeters: midpoint.dy),
      );
    }
    if (midpointId == wall.startNodeId || midpointId == wall.endNodeId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Слишком короткая стена для разреза на текущем шаге сетки.',
          ),
        ),
      );
      return;
    }
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final nextWalls = <PlanWall>[
      for (final item in _walls)
        if (item.id != wall.id) item,
      PlanWall(
        id: '${wall.id}-a-$timestamp',
        startNodeId: wall.startNodeId,
        endNodeId: midpointId,
        constructionId: wall.constructionId,
      ),
      PlanWall(
        id: '${wall.id}-b-$timestamp',
        startNodeId: midpointId,
        endNodeId: wall.endNodeId,
        constructionId: wall.constructionId,
      ),
    ];
    await _saveWallPlan(
      nodes: nextNodes,
      walls: nextWalls,
      openings: _openings,
    );
  }

  @override
  Widget build(BuildContext context) {
    final wallConstructions = widget.project.constructions
        .where((item) => item.elementKind == ConstructionElementKind.wall)
        .toList(growable: false);
    final floorConstructions = widget.project.constructions
        .where((item) => item.elementKind == ConstructionElementKind.floor)
        .toList(growable: false);
    final topConstructions = widget.project.constructions
        .where(
          (item) =>
              item.elementKind == ConstructionElementKind.ceiling ||
              item.elementKind == ConstructionElementKind.roof,
        )
        .toList(growable: false);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              key: const ValueKey('wall-graph-new-contour-button'),
              onPressed: _toggleDrawMode,
              icon: Icon(_drawMode ? Icons.close : Icons.draw_outlined),
              label: Text(_drawMode ? 'Отменить контур' : 'Новый контур'),
            ),
            if (_drawMode)
              FilledButton.tonalIcon(
                key: const ValueKey('wall-graph-commit-contour-button'),
                onPressed: _commitContour,
                icon: const Icon(Icons.check),
                label: const Text('Замкнуть и сохранить'),
              ),
            if (_multiSelectMode)
              FilledButton.tonalIcon(
                key: const ValueKey('wall-graph-clear-multiselect-button'),
                onPressed: () {
                  setState(() {
                    _multiSelectMode = false;
                    _selectedWallIds.clear();
                  });
                },
                icon: const Icon(Icons.layers_clear_outlined),
                label: const Text('Сбросить мультивыбор'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ChoiceChip(
              key: const ValueKey('wall-graph-orthogonal-mode-chip'),
              label: const Text('90°'),
              selected: _orthogonalConstraint,
              onSelected: (value) {
                if (!value) {
                  return;
                }
                setState(() => _orthogonalConstraint = true);
              },
            ),
            ChoiceChip(
              key: const ValueKey('wall-graph-free-angle-mode-chip'),
              label: const Text('Свободный угол'),
              selected: !_orthogonalConstraint,
              onSelected: (value) {
                if (!value) {
                  return;
                }
                setState(() => _orthogonalConstraint = false);
              },
            ),
            DropdownButton<double>(
              key: const ValueKey('wall-graph-grid-step-dropdown'),
              value: _gridStepMeters,
              items: [
                for (final step in _availableGridStepsMeters)
                  DropdownMenuItem(
                    value: step,
                    child: Text('Сетка ${step.toStringAsFixed(1)} м'),
                  ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _gridStepMeters = value);
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'План строится стенами. Замкнутый контур образует помещение. '
          'Тап по помещению редактирует параметры, тап по стене выбирает стену, '
          'долгий тап включает мультивыбор, узлы можно перетаскивать.',
        ),
        const SizedBox(height: 16),
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
              height: 520,
              child: _WallGraphCanvas(
                project: widget.project,
                selectedRoomId: _selectedRoomId,
                selectedWallIds: _selectedWallIds,
                draftPoints: _draftPoints,
                onCanvasTapDown: _handleCanvasTap,
                onRoomTap: _selectRoom,
                onWallTap: _selectWall,
                onWallLongPress: (wallId) {
                  setState(() {
                    _multiSelectMode = true;
                    _selectedWallId = wallId;
                    _selectedWallIds.add(wallId);
                    _selectedNodeId = null;
                    _selectedRoomId = null;
                  });
                },
                onWallDrag: (wall) => !_multiSelectMode
                    ? (details) => _moveWall(wall, details)
                    : null,
                onNodeTap: _selectNode,
                onNodeDrag: (nodeId) =>
                    (details) => _moveNode(nodeId, details),
                selectedNodeId: _selectedNodeId,
                gridStepMeters: _gridStepMeters,
              ),
            ),
          ),
        ),
        if (_selectedNodeId != null) ...[
          const SizedBox(height: 16),
          Text(
            'Выбран узел: $_selectedNodeId',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
        if (_selectedWallIds.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            _selectedWallIds.length > 1
                ? 'Выбрано стен: ${_selectedWallIds.length}'
                : 'Выбрана стена',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const ValueKey('wall-graph-wall-construction-field'),
            initialValue: _selectedWall?.constructionId,
            decoration: const InputDecoration(labelText: 'Конструкция стены'),
            items: wallConstructions
                .map(
                  (item) =>
                      DropdownMenuItem(value: item.id, child: Text(item.title)),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value != null) {
                _applyConstructionToSelectedWalls(value);
              }
            },
          ),
          if (_selectedWallIds.length == 1) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.tonal(
                  key: const ValueKey('wall-graph-add-window-button'),
                  onPressed: () =>
                      _addOpeningToSelectedWall(OpeningKind.window),
                  child: const Text('Добавить окно'),
                ),
                FilledButton.tonal(
                  key: const ValueKey('wall-graph-add-door-button'),
                  onPressed: () => _addOpeningToSelectedWall(OpeningKind.door),
                  child: const Text('Добавить дверь'),
                ),
                OutlinedButton(
                  key: const ValueKey('wall-graph-split-wall-button'),
                  onPressed: _splitSelectedWall,
                  child: const Text('Разрезать стену'),
                ),
                OutlinedButton(
                  key: const ValueKey('wall-graph-delete-wall-button'),
                  onPressed: _deleteSelectedWall,
                  child: const Text('Удалить стену'),
                ),
              ],
            ),
          ],
        ],
        if (_selectedRoom != null) ...[
          const SizedBox(height: 16),
          Text(
            'Помещение',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('wall-graph-room-title-field'),
            controller: _roomTitleController,
            decoration: const InputDecoration(labelText: 'Название'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<RoomKind>(
            key: const ValueKey('wall-graph-room-kind-field'),
            initialValue: _selectedRoomKind,
            decoration: const InputDecoration(labelText: 'Тип помещения'),
            items: RoomKind.values
                .map(
                  (item) =>
                      DropdownMenuItem(value: item, child: Text(item.label)),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedRoomKind = value);
              }
            },
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('wall-graph-room-height-field'),
            controller: _roomHeightController,
            decoration: const InputDecoration(labelText: 'Высота помещения, м'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const ValueKey('wall-graph-room-floor-field'),
            initialValue: _selectedFloorConstructionId,
            decoration: const InputDecoration(labelText: 'Пол'),
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('Без пола'),
              ),
              ...floorConstructions.map(
                (item) =>
                    DropdownMenuItem(value: item.id, child: Text(item.title)),
              ),
            ],
            onChanged: (value) {
              setState(() => _selectedFloorConstructionId = value);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const ValueKey('wall-graph-room-top-field'),
            initialValue: _selectedTopConstructionId,
            decoration: const InputDecoration(labelText: 'Перекрытие / кровля'),
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('Без верха'),
              ),
              ...topConstructions.map(
                (item) =>
                    DropdownMenuItem(value: item.id, child: Text(item.title)),
              ),
            ],
            onChanged: (value) {
              setState(() => _selectedTopConstructionId = value);
            },
          ),
          const SizedBox(height: 12),
          Text(
            'Площадь: ${_selectedRoom!.areaSquareMeters.toStringAsFixed(1)} м²',
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const ValueKey('wall-graph-save-room-button'),
            onPressed: _saveSelectedRoom,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Сохранить помещение'),
          ),
        ],
      ],
    );

    if (!widget.useCardDecoration) {
      return content;
    }
    return Card(
      child: Padding(padding: const EdgeInsets.all(20), child: content),
    );
  }
}

class _WallGraphCanvas extends StatelessWidget {
  const _WallGraphCanvas({
    required this.project,
    required this.selectedRoomId,
    required this.selectedWallIds,
    required this.selectedNodeId,
    required this.draftPoints,
    required this.onCanvasTapDown,
    required this.onRoomTap,
    required this.onWallTap,
    required this.onWallLongPress,
    required this.onWallDrag,
    required this.onNodeTap,
    required this.onNodeDrag,
    required this.gridStepMeters,
    this.canvasKey = const ValueKey('wall-graph-canvas'),
  });

  static const double pixelsPerMeter = 36;
  static const double canvasPadding = 24;
  static const double wallThickness = 12;
  static const double minCanvasWidthMeters = 14;
  static const double minCanvasHeightMeters = 10;

  final Project project;
  final String? selectedRoomId;
  final Set<String> selectedWallIds;
  final String? selectedNodeId;
  final List<Offset> draftPoints;
  final GestureTapDownCallback? onCanvasTapDown;
  final ValueChanged<Room>? onRoomTap;
  final ValueChanged<String>? onWallTap;
  final ValueChanged<String>? onWallLongPress;
  final GestureDragUpdateCallback? Function(PlanWall wall)? onWallDrag;
  final ValueChanged<String>? onNodeTap;
  final GestureDragUpdateCallback? Function(String nodeId)? onNodeDrag;
  final double gridStepMeters;
  final Key canvasKey;

  Map<String, PlanNode> get _nodeMap => {
    for (final node in project.houseModel.planNodes) node.id: node,
  };

  double get _maxRightMeters {
    final nodeMax = project.houseModel.planNodes.fold<double>(
      0,
      (value, item) => math.max(value, item.xMeters),
    );
    final roomMax = project.houseModel.rooms.fold<double>(
      0,
      (value, item) => math.max(value, item.layout.rightMeters),
    );
    return math.max(minCanvasWidthMeters, math.max(nodeMax, roomMax) + 2);
  }

  double get _maxBottomMeters {
    final nodeMax = project.houseModel.planNodes.fold<double>(
      0,
      (value, item) => math.max(value, item.yMeters),
    );
    final roomMax = project.houseModel.rooms.fold<double>(
      0,
      (value, item) => math.max(value, item.layout.bottomMeters),
    );
    return math.max(minCanvasHeightMeters, math.max(nodeMax, roomMax) + 2);
  }

  HouseLineSegment _segmentForWall(PlanWall wall) {
    final start = _nodeMap[wall.startNodeId]!;
    final end = _nodeMap[wall.endNodeId]!;
    return HouseLineSegment(
      startXMeters: start.xMeters,
      startYMeters: start.yMeters,
      endXMeters: end.xMeters,
      endYMeters: end.yMeters,
    ).normalized();
  }

  @override
  Widget build(BuildContext context) {
    final canvasWidth = _maxRightMeters * pixelsPerMeter + canvasPadding * 2;
    final canvasHeight = _maxBottomMeters * pixelsPerMeter + canvasPadding * 2;
    return InteractiveViewer(
      minScale: 0.7,
      maxScale: 2.5,
      boundaryMargin: const EdgeInsets.all(48),
      child: GestureDetector(
        key: canvasKey,
        behavior: HitTestBehavior.opaque,
        onTapDown: onCanvasTapDown,
        child: SizedBox(
          width: canvasWidth,
          height: canvasHeight,
          child: Stack(
            children: [
              CustomPaint(
                size: Size(canvasWidth, canvasHeight),
                painter: _WallGridPainter(
                  pixelsPerMeter: pixelsPerMeter,
                  canvasPadding: canvasPadding,
                  gridStepMeters: gridStepMeters,
                ),
              ),
              for (final room in project.houseModel.rooms)
                for (final cell in room.effectiveCells)
                  Positioned(
                    left: canvasPadding + cell.xMeters * pixelsPerMeter,
                    top: canvasPadding + cell.yMeters * pixelsPerMeter,
                    width: cell.widthMeters * pixelsPerMeter,
                    height: cell.heightMeters * pixelsPerMeter,
                    child: GestureDetector(
                      key: ValueKey(
                        'wall-graph-room-${room.id}-${cell.xMeters}-${cell.yMeters}',
                      ),
                      onTap: onRoomTap == null ? null : () => onRoomTap!(room),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: room.id == selectedRoomId
                              ? const Color(0xFFE9D5A8).withValues(alpha: 0.75)
                              : const Color(0xFFDCC9A0).withValues(alpha: 0.35),
                          border: Border.all(
                            color: room.id == selectedRoomId
                                ? Theme.of(context).colorScheme.primary
                                : const Color(0x00000000),
                          ),
                        ),
                      ),
                    ),
                  ),
              for (final wall in project.houseModel.planWalls)
                _WallSegmentWidget(
                  wall: wall,
                  segment: _segmentForWall(wall),
                  selected: selectedWallIds.contains(wall.id),
                  pixelsPerMeter: pixelsPerMeter,
                  canvasPadding: canvasPadding,
                  thickness: wallThickness,
                  onTap: onWallTap == null ? null : () => onWallTap!(wall.id),
                  onLongPress: onWallLongPress == null
                      ? null
                      : () => onWallLongPress!(wall.id),
                  onDrag: onWallDrag?.call(wall),
                ),
              for (final node in project.houseModel.planNodes)
                _WallNodeWidget(
                  node: node,
                  selected: selectedNodeId == node.id,
                  pixelsPerMeter: pixelsPerMeter,
                  canvasPadding: canvasPadding,
                  onTap: onNodeTap == null ? null : () => onNodeTap!(node.id),
                  onDrag: onNodeDrag?.call(node.id),
                ),
              if (draftPoints.isNotEmpty)
                CustomPaint(
                  size: Size(canvasWidth, canvasHeight),
                  painter: _DraftContourPainter(
                    points: draftPoints,
                    pixelsPerMeter: pixelsPerMeter,
                    canvasPadding: canvasPadding,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverviewMetric extends StatelessWidget {
  const _OverviewMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 132,
      padding: const EdgeInsets.all(14),
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
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(label),
        ],
      ),
    );
  }
}

class _WallGridPainter extends CustomPainter {
  const _WallGridPainter({
    required this.pixelsPerMeter,
    required this.canvasPadding,
    required this.gridStepMeters,
  });

  final double pixelsPerMeter;
  final double canvasPadding;
  final double gridStepMeters;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD8D0C0)
      ..strokeWidth = 1;
    final stepPx = pixelsPerMeter * gridStepMeters;
    for (
      double x = canvasPadding;
      x <= size.width - canvasPadding;
      x += stepPx
    ) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (
      double y = canvasPadding;
      y <= size.height - canvasPadding;
      y += stepPx
    ) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WallGridPainter oldDelegate) {
    return oldDelegate.gridStepMeters != gridStepMeters;
  }
}

class _DraftContourPainter extends CustomPainter {
  const _DraftContourPainter({
    required this.points,
    required this.pixelsPerMeter,
    required this.canvasPadding,
  });

  final List<Offset> points;
  final double pixelsPerMeter;
  final double canvasPadding;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) {
      return;
    }
    final paint = Paint()
      ..color = const Color(0xFF245B8E)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    final path = Path();
    path.moveTo(
      canvasPadding + points.first.dx * pixelsPerMeter,
      canvasPadding + points.first.dy * pixelsPerMeter,
    );
    for (final point in points.skip(1)) {
      path.lineTo(
        canvasPadding + point.dx * pixelsPerMeter,
        canvasPadding + point.dy * pixelsPerMeter,
      );
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _DraftContourPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

class _WallSegmentWidget extends StatelessWidget {
  const _WallSegmentWidget({
    required this.wall,
    required this.segment,
    required this.selected,
    required this.pixelsPerMeter,
    required this.canvasPadding,
    required this.thickness,
    required this.onTap,
    required this.onLongPress,
    required this.onDrag,
  });

  final PlanWall wall;
  final HouseLineSegment segment;
  final bool selected;
  final double pixelsPerMeter;
  final double canvasPadding;
  final double thickness;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final GestureDragUpdateCallback? onDrag;

  @override
  Widget build(BuildContext context) {
    final rect = wallSegmentRect(
      segment: segment,
      pixelsPerMeter: pixelsPerMeter,
      canvasPadding: canvasPadding,
      thicknessPixels: thickness,
    );
    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: GestureDetector(
        key: ValueKey('wall-graph-wall-${wall.id}'),
        onTap: onTap,
        onLongPress: onLongPress,
        onPanUpdate: onDrag,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF8A5530) : const Color(0xFFB36A3C),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? const Color(0xFFFFE7C2)
                  : const Color(0xFF5A3116),
              width: selected ? 2 : 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _WallNodeWidget extends StatelessWidget {
  const _WallNodeWidget({
    required this.node,
    required this.selected,
    required this.pixelsPerMeter,
    required this.canvasPadding,
    required this.onTap,
    required this.onDrag,
  });

  final PlanNode node;
  final bool selected;
  final double pixelsPerMeter;
  final double canvasPadding;
  final VoidCallback? onTap;
  final GestureDragUpdateCallback? onDrag;

  @override
  Widget build(BuildContext context) {
    const size = 14.0;
    final centerX = canvasPadding + node.xMeters * pixelsPerMeter;
    final centerY = canvasPadding + node.yMeters * pixelsPerMeter;
    return Positioned(
      left: centerX - size / 2,
      top: centerY - size / 2,
      width: size,
      height: size,
      child: GestureDetector(
        key: ValueKey('wall-graph-node-${node.id}'),
        onTap: onTap,
        onPanUpdate: onDrag,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? const Color(0xFF245B8E) : const Color(0xFFF5F1E7),
            border: Border.all(
              color: selected
                  ? const Color(0xFFEFF5FF)
                  : const Color(0xFF36506A),
              width: selected ? 2 : 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
