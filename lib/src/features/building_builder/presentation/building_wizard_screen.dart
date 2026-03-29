import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/calculation.dart';
import '../../../core/models/catalog.dart';
import '../../../core/models/project.dart';
import '../../../core/providers.dart';
import '../../thermocalc/presentation/thermocalc_preview_screen.dart';

class BuildingWizardScreen extends ConsumerStatefulWidget {
  const BuildingWizardScreen({
    super.key,
    required this.initialProject,
  });

  final Project initialProject;

  @override
  ConsumerState<BuildingWizardScreen> createState() => _BuildingWizardScreenState();
}

class _BuildingWizardScreenState extends ConsumerState<BuildingWizardScreen> {
  late Project _draft = widget.initialProject;
  int _currentStep = 0;

  List<Construction> get _opaqueConstructions => _draft.constructions
      .where(
        (construction) =>
            construction.elementKind != ConstructionElementKind.window &&
            construction.elementKind != ConstructionElementKind.door,
      )
      .toList();

  List<Construction> get _openingConstructions => _draft.constructions
      .where(
        (construction) =>
            construction.elementKind == ConstructionElementKind.window ||
            construction.elementKind == ConstructionElementKind.door,
      )
      .toList();

  void _updateProject(Project Function(Project project) transform) {
    setState(() {
      _draft = transform(_draft);
    });
  }

  void _updateRoom(String roomId, Room Function(Room room) transform) {
    _updateProject(
      (project) => project.copyWith(
        rooms: [
          for (final room in project.rooms)
            room.id == roomId ? transform(room) : room,
        ],
      ),
    );
  }

  void _updateBoundary(
    String roomId,
    String boundaryId,
    RoomBoundary Function(RoomBoundary boundary) transform,
  ) {
    _updateRoom(
      roomId,
      (room) => room.copyWith(
        boundaries: [
          for (final boundary in room.boundaries)
            boundary.id == boundaryId ? transform(boundary) : boundary,
        ],
      ),
    );
  }

  void _updateOpening(
    String roomId,
    String boundaryId,
    String openingId,
    Opening Function(Opening opening) transform,
  ) {
    _updateBoundary(
      roomId,
      boundaryId,
      (boundary) => boundary.copyWith(
        openings: [
          for (final opening in boundary.openings)
            opening.id == openingId ? transform(opening) : opening,
        ],
      ),
    );
  }

  void _addRoom() {
    final roomIndex = _draft.rooms.length + 1;
    _updateProject(
      (project) => project.copyWith(
        rooms: [
          ...project.rooms,
          Room(
            id: 'room-$roomIndex',
            name: 'Комната $roomIndex',
            roomType: RoomType.livingRoom,
            floorAreaM2: 16,
            heightM: 2.8,
          ),
        ],
      ),
    );
  }

  void _removeRoom(String roomId) {
    _updateProject(
      (project) => project.copyWith(
        rooms: project.rooms.where((room) => room.id != roomId).toList(),
      ),
    );
  }

  void _addBoundary(String roomId) {
    final fallbackConstruction = _opaqueConstructions.firstOrNull;
    if (fallbackConstruction == null) {
      return;
    }
    final room = _draft.rooms.firstWhere((item) => item.id == roomId);
    final boundaryIndex = room.boundaries.length + 1;
    _updateRoom(
      roomId,
      (currentRoom) => currentRoom.copyWith(
        boundaries: [
          ...currentRoom.boundaries,
          RoomBoundary(
            id: '$roomId-boundary-$boundaryIndex',
            title: 'Поверхность $boundaryIndex',
            surfaceType: SurfaceType.wall,
            boundaryCondition: BoundaryCondition.outdoor,
            grossAreaM2: 10,
            constructionId: fallbackConstruction.id,
          ),
        ],
      ),
    );
  }

  void _removeBoundary(String roomId, String boundaryId) {
    _updateRoom(
      roomId,
      (room) => room.copyWith(
        boundaries:
            room.boundaries.where((boundary) => boundary.id != boundaryId).toList(),
      ),
    );
  }

  void _addOpening(String roomId, String boundaryId, OpeningKind kind) {
    final fallbackConstruction = _openingConstructions.firstWhere(
      (construction) =>
          construction.elementKind ==
          (kind == OpeningKind.window
              ? ConstructionElementKind.window
              : ConstructionElementKind.door),
      orElse: () => _openingConstructions.first,
    );
    final room = _draft.rooms.firstWhere((item) => item.id == roomId);
    final boundary =
        room.boundaries.firstWhere((item) => item.id == boundaryId);
    final openingIndex = boundary.openings.length + 1;
    _updateBoundary(
      roomId,
      boundaryId,
      (currentBoundary) => currentBoundary.copyWith(
        openings: [
          ...currentBoundary.openings,
          Opening(
            id: '$boundaryId-opening-$openingIndex',
            title:
                '${kind == OpeningKind.window ? 'Окно' : 'Дверь'} $openingIndex',
            kind: kind,
            areaM2: kind == OpeningKind.window ? 2.4 : 1.8,
            constructionId: fallbackConstruction.id,
          ),
        ],
      ),
    );
  }

  void _removeOpening(String roomId, String boundaryId, String openingId) {
    _updateBoundary(
      roomId,
      boundaryId,
      (boundary) => boundary.copyWith(
        openings:
            boundary.openings.where((opening) => opening.id != openingId).toList(),
      ),
    );
  }

  Future<BuildingHeatLossResult> _calculate(CatalogSnapshot catalog) async {
    final input = await ref.read(buildingCalculationAssemblerProvider).assemble(
          catalog: catalog,
          project: _draft,
        );
    return ref.read(buildingHeatLossEngineProvider).calculate(input: input);
  }

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(catalogSnapshotProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Шаг 2: Расчетный объект',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: catalogAsync.when(
        data: (catalog) => Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
          ),
          child: Stepper(
            currentStep: _currentStep,
            onStepCancel: _currentStep == 0
                ? null
                : () => setState(() => _currentStep -= 1),
            onStepContinue: _currentStep == 3
                ? null
                : () => setState(() => _currentStep += 1),
            onStepTapped: (step) => setState(() => _currentStep = step),
            controlsBuilder: (context, details) {
              return Row(
                children: [
                  FilledButton(
                    onPressed: details.onStepContinue,
                    child: Text(_currentStep == 3 ? 'Готово' : 'Далее'),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: details.onStepCancel,
                    child: const Text('Назад'),
                  ),
                ],
              );
            },
            steps: [
              Step(
                isActive: _currentStep >= 0,
                title: const Text('Объект'),
                content: _ObjectSummaryStep(
                  project: _draft,
                  catalog: catalog,
                  onProjectNameChanged: (value) =>
                      _updateProject((project) => project.copyWith(name: value)),
                  onClimateChanged: (value) => value == null
                      ? null
                      : _updateProject(
                          (project) => project.copyWith(climatePointId: value),
                        ),
                  onOpenConstructionPreview: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ThermocalcPreviewScreen(),
                      ),
                    );
                  },
                ),
              ),
              Step(
                isActive: _currentStep >= 1,
                title: const Text('Комнаты'),
                content: _RoomsStep(
                  project: _draft,
                  onAddRoom: _addRoom,
                  onRemoveRoom: _removeRoom,
                  onRoomChanged: _updateRoom,
                ),
              ),
              Step(
                isActive: _currentStep >= 2,
                title: const Text('Поверхности'),
                content: _BoundariesStep(
                  project: _draft,
                  opaqueConstructions: _opaqueConstructions,
                  openingConstructions: _openingConstructions,
                  onRoomChanged: _updateRoom,
                  onBoundaryChanged: _updateBoundary,
                  onOpeningChanged: _updateOpening,
                  onAddBoundary: _addBoundary,
                  onRemoveBoundary: _removeBoundary,
                  onAddOpening: _addOpening,
                  onRemoveOpening: _removeOpening,
                ),
              ),
              Step(
                isActive: _currentStep >= 3,
                title: const Text('Результат'),
                content: FutureBuilder<BuildingHeatLossResult>(
                  future: _calculate(catalog),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: LinearProgressIndicator(),
                      );
                    }
                    if (snapshot.hasError) {
                      return Text('Ошибка сборки расчета: ${snapshot.error}');
                    }
                    final result = snapshot.requireData;
                    return _ResultsStep(result: result);
                  },
                ),
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Ошибка каталога: $error')),
      ),
    );
  }
}

class _ObjectSummaryStep extends StatelessWidget {
  const _ObjectSummaryStep({
    required this.project,
    required this.catalog,
    required this.onProjectNameChanged,
    required this.onClimateChanged,
    required this.onOpenConstructionPreview,
  });

  final Project project;
  final CatalogSnapshot catalog;
  final ValueChanged<String> onProjectNameChanged;
  final ValueChanged<String?> onClimateChanged;
  final VoidCallback onOpenConstructionPreview;

  @override
  Widget build(BuildContext context) {
    final climate = catalog.climatePoints.firstWhere(
      (item) => item.id == project.climatePointId,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: TextEditingController(text: project.name),
          decoration: const InputDecoration(labelText: 'Название объекта'),
          onChanged: onProjectNameChanged,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: project.climatePointId,
          decoration: const InputDecoration(labelText: 'Климатическая точка'),
          items: [
            for (final point in catalog.climatePoints)
              DropdownMenuItem(
                value: point.id,
                child: Text(point.displayName),
              ),
          ],
          onChanged: onClimateChanged,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Сводка шага 0 и шага 1',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 10),
                Text('Объект: ${project.name}'),
                Text('Климат: ${climate.displayName}'),
                Text(
                  'Расчетная наружная температура: ${climate.designTemperature.toStringAsFixed(1)} °C',
                ),
                Text('Конструкций в библиотеке: ${project.constructions.length}'),
                Text('Комнат в объекте: ${project.rooms.length}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onOpenConstructionPreview,
          icon: const Icon(Icons.layers_outlined),
          label: const Text('Открыть preview конструкции'),
        ),
      ],
    );
  }
}

class _RoomsStep extends StatelessWidget {
  const _RoomsStep({
    required this.project,
    required this.onAddRoom,
    required this.onRemoveRoom,
    required this.onRoomChanged,
  });

  final Project project;
  final VoidCallback onAddRoom;
  final ValueChanged<String> onRemoveRoom;
  final void Function(String roomId, Room Function(Room room) transform)
      onRoomChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilledButton.icon(
          onPressed: onAddRoom,
          icon: const Icon(Icons.add_home_work_outlined),
          label: const Text('Добавить комнату'),
        ),
        const SizedBox(height: 16),
        for (final room in project.rooms) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          room.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => onRemoveRoom(room.id),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                  TextField(
                    controller: TextEditingController(text: room.name),
                    decoration: const InputDecoration(labelText: 'Название'),
                    onChanged: (value) => onRoomChanged(
                      room.id,
                      (currentRoom) => currentRoom.copyWith(name: value),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<RoomType>(
                    initialValue: room.roomType,
                    decoration: const InputDecoration(labelText: 'Тип комнаты'),
                    items: [
                      for (final type in RoomType.values)
                        DropdownMenuItem(
                          value: type,
                          child: Text(type.label),
                        ),
                    ],
                    onChanged: (value) => value == null
                        ? null
                        : onRoomChanged(
                            room.id,
                            (currentRoom) =>
                                currentRoom.copyWith(roomType: value),
                          ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: TextEditingController(
                            text: room.floorAreaM2.toStringAsFixed(1),
                          ),
                          decoration:
                              const InputDecoration(labelText: 'Площадь, м²'),
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (value) => onRoomChanged(
                            room.id,
                            (currentRoom) => currentRoom.copyWith(
                              floorAreaM2:
                                  double.tryParse(value.replaceAll(',', '.')) ??
                                      currentRoom.floorAreaM2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: TextEditingController(
                            text: room.heightM.toStringAsFixed(2),
                          ),
                          decoration:
                              const InputDecoration(labelText: 'Высота, м'),
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (value) => onRoomChanged(
                            room.id,
                            (currentRoom) => currentRoom.copyWith(
                              heightM:
                                  double.tryParse(value.replaceAll(',', '.')) ??
                                      currentRoom.heightM,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: TextEditingController(
                            text: room.targetTemperatureOverrideC
                                    ?.toStringAsFixed(1) ??
                                '',
                          ),
                          decoration: InputDecoration(
                            labelText:
                                'Температура, °C (по умолчанию ${room.roomType.defaultTargetTemperatureC.toStringAsFixed(1)})',
                          ),
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (value) => onRoomChanged(
                            room.id,
                            (currentRoom) => value.trim().isEmpty
                                ? currentRoom.copyWith(
                                    clearTargetTemperatureOverrideC: true,
                                  )
                                : currentRoom.copyWith(
                                    targetTemperatureOverrideC: double.tryParse(
                                          value.replaceAll(',', '.'),
                                        ) ??
                                        currentRoom.targetTemperatureOverrideC,
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: TextEditingController(
                            text:
                                room.airChangesOverride?.toStringAsFixed(2) ?? '',
                          ),
                          decoration: InputDecoration(
                            labelText:
                                'Воздухообмен ACH (по умолчанию ${room.roomType.defaultAirChangesPerHour.toStringAsFixed(2)})',
                          ),
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (value) => onRoomChanged(
                            room.id,
                            (currentRoom) => value.trim().isEmpty
                                ? currentRoom.copyWith(
                                    clearAirChangesOverride: true,
                                  )
                                : currentRoom.copyWith(
                                    airChangesOverride: double.tryParse(
                                          value.replaceAll(',', '.'),
                                        ) ??
                                        currentRoom.airChangesOverride,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Объем: ${room.volumeM3.toStringAsFixed(1)} м³, потери будут считаться по температуре ${room.targetTemperatureC.toStringAsFixed(1)} °C и воздухообмену ${room.airChangesPerHour.toStringAsFixed(2)} ACH.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _BoundariesStep extends StatelessWidget {
  const _BoundariesStep({
    required this.project,
    required this.opaqueConstructions,
    required this.openingConstructions,
    required this.onRoomChanged,
    required this.onBoundaryChanged,
    required this.onOpeningChanged,
    required this.onAddBoundary,
    required this.onRemoveBoundary,
    required this.onAddOpening,
    required this.onRemoveOpening,
  });

  final Project project;
  final List<Construction> opaqueConstructions;
  final List<Construction> openingConstructions;
  final void Function(String roomId, Room Function(Room room) transform)
      onRoomChanged;
  final void Function(
    String roomId,
    String boundaryId,
    RoomBoundary Function(RoomBoundary boundary) transform,
  ) onBoundaryChanged;
  final void Function(
    String roomId,
    String boundaryId,
    String openingId,
    Opening Function(Opening opening) transform,
  ) onOpeningChanged;
  final ValueChanged<String> onAddBoundary;
  final void Function(String roomId, String boundaryId) onRemoveBoundary;
  final void Function(String roomId, String boundaryId, OpeningKind kind)
      onAddOpening;
  final void Function(String roomId, String boundaryId, String openingId)
      onRemoveOpening;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final room in project.rooms) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          room.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => onAddBoundary(room.id),
                        icon: const Icon(Icons.add),
                        label: const Text('Поверхность'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final boundary in room.boundaries) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  boundary.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () =>
                                    onRemoveBoundary(room.id, boundary.id),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                          TextField(
                            controller: TextEditingController(text: boundary.title),
                            decoration:
                                const InputDecoration(labelText: 'Название'),
                            onChanged: (value) => onBoundaryChanged(
                              room.id,
                              boundary.id,
                              (currentBoundary) =>
                                  currentBoundary.copyWith(title: value),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<SurfaceType>(
                                  initialValue: boundary.surfaceType,
                                  decoration: const InputDecoration(
                                    labelText: 'Тип поверхности',
                                  ),
                                  items: [
                                    for (final type in SurfaceType.values)
                                      DropdownMenuItem(
                                        value: type,
                                        child: Text(type.label),
                                      ),
                                  ],
                                  onChanged: (value) => value == null
                                      ? null
                                      : onBoundaryChanged(
                                          room.id,
                                          boundary.id,
                                          (currentBoundary) =>
                                              currentBoundary.copyWith(
                                            surfaceType: value,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<BoundaryCondition>(
                                  initialValue: boundary.boundaryCondition,
                                  decoration: const InputDecoration(
                                    labelText: 'Тип границы',
                                  ),
                                  items: [
                                    for (final condition in BoundaryCondition.values)
                                      DropdownMenuItem(
                                        value: condition,
                                        child: Text(condition.label),
                                      ),
                                  ],
                                  onChanged: (value) => value == null
                                      ? null
                                      : onBoundaryChanged(
                                          room.id,
                                          boundary.id,
                                          (currentBoundary) =>
                                              currentBoundary.copyWith(
                                            boundaryCondition: value,
                                            clearAdjacentRoomId: value !=
                                                BoundaryCondition.heatedAdjacent,
                                            clearAdjacentTemperatureC: value ==
                                                BoundaryCondition.outdoor,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: TextEditingController(
                                    text: boundary.grossAreaM2.toStringAsFixed(2),
                                  ),
                                  decoration: const InputDecoration(
                                    labelText: 'Площадь, м²',
                                  ),
                                  keyboardType: const TextInputType
                                      .numberWithOptions(decimal: true),
                                  onChanged: (value) => onBoundaryChanged(
                                    room.id,
                                    boundary.id,
                                    (currentBoundary) => currentBoundary.copyWith(
                                      grossAreaM2: double.tryParse(
                                            value.replaceAll(',', '.'),
                                          ) ??
                                          currentBoundary.grossAreaM2,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: boundary.constructionId,
                                  decoration: const InputDecoration(
                                    labelText: 'Конструкция',
                                  ),
                                  items: [
                                    for (final construction in opaqueConstructions)
                                      DropdownMenuItem(
                                        value: construction.id,
                                        child: Text(construction.title),
                                      ),
                                  ],
                                  onChanged: (value) => value == null
                                      ? null
                                      : onBoundaryChanged(
                                          room.id,
                                          boundary.id,
                                          (currentBoundary) =>
                                              currentBoundary.copyWith(
                                            constructionId: value,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                          if (boundary.boundaryCondition ==
                                  BoundaryCondition.unheatedSpace ||
                              boundary.boundaryCondition ==
                                  BoundaryCondition.ground) ...[
                            const SizedBox(height: 12),
                            TextField(
                              controller: TextEditingController(
                                text: boundary.adjacentTemperatureC
                                        ?.toStringAsFixed(1) ??
                                    '',
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Температура смежной зоны, °C',
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (value) => onBoundaryChanged(
                                room.id,
                                boundary.id,
                                (currentBoundary) => currentBoundary.copyWith(
                                  adjacentTemperatureC: double.tryParse(
                                        value.replaceAll(',', '.'),
                                      ) ??
                                      currentBoundary.adjacentTemperatureC,
                                ),
                              ),
                            ),
                          ],
                          if (boundary.boundaryCondition ==
                              BoundaryCondition.heatedAdjacent) ...[
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue: boundary.adjacentRoomId,
                              decoration: const InputDecoration(
                                labelText: 'Смежная отапливаемая комната',
                              ),
                              items: [
                                for (final roomOption in project.rooms
                                    .where((item) => item.id != room.id))
                                  DropdownMenuItem(
                                    value: roomOption.id,
                                    child: Text(roomOption.name),
                                  ),
                              ],
                              onChanged: (value) => onBoundaryChanged(
                                room.id,
                                boundary.id,
                                (currentBoundary) => currentBoundary.copyWith(
                                  adjacentRoomId: value,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Text(
                            'Чистая площадь непрозрачной части: ${boundary.opaqueAreaM2.toStringAsFixed(2)} м²',
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.tonalIcon(
                                onPressed: () =>
                                    onAddOpening(room.id, boundary.id, OpeningKind.window),
                                icon: const Icon(Icons.window_outlined),
                                label: const Text('Окно'),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: () =>
                                    onAddOpening(room.id, boundary.id, OpeningKind.door),
                                icon: const Icon(Icons.door_front_door_outlined),
                                label: const Text('Дверь'),
                              ),
                            ],
                          ),
                          if (boundary.openings.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            for (final opening in boundary.openings) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF7F7F3),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            opening.title,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: () => onRemoveOpening(
                                            room.id,
                                            boundary.id,
                                            opening.id,
                                          ),
                                          icon: const Icon(Icons.delete_outline),
                                        ),
                                      ],
                                    ),
                                    TextField(
                                      controller:
                                          TextEditingController(text: opening.title),
                                      decoration: const InputDecoration(
                                        labelText: 'Название проема',
                                      ),
                                      onChanged: (value) => onOpeningChanged(
                                        room.id,
                                        boundary.id,
                                        opening.id,
                                        (currentOpening) =>
                                            currentOpening.copyWith(title: value),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child:
                                              DropdownButtonFormField<OpeningKind>(
                                            initialValue: opening.kind,
                                            decoration: const InputDecoration(
                                              labelText: 'Тип проема',
                                            ),
                                            items: [
                                              for (final kind in OpeningKind.values)
                                                DropdownMenuItem(
                                                  value: kind,
                                                  child: Text(kind.label),
                                                ),
                                            ],
                                            onChanged: (value) => value == null
                                                ? null
                                                : onOpeningChanged(
                                                    room.id,
                                                    boundary.id,
                                                    opening.id,
                                                    (currentOpening) =>
                                                        currentOpening.copyWith(
                                                      kind: value,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: TextField(
                                            controller: TextEditingController(
                                              text: opening.areaM2.toStringAsFixed(2),
                                            ),
                                            decoration: const InputDecoration(
                                              labelText: 'Площадь, м²',
                                            ),
                                            keyboardType: const TextInputType
                                                .numberWithOptions(decimal: true),
                                            onChanged: (value) => onOpeningChanged(
                                              room.id,
                                              boundary.id,
                                              opening.id,
                                              (currentOpening) =>
                                                  currentOpening.copyWith(
                                                areaM2: double.tryParse(
                                                      value.replaceAll(',', '.'),
                                                    ) ??
                                                    currentOpening.areaM2,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    DropdownButtonFormField<String>(
                                      initialValue: opening.constructionId,
                                      decoration: const InputDecoration(
                                        labelText: 'Конструкция проема',
                                      ),
                                      items: [
                                        for (final construction
                                            in openingConstructions.where(
                                          (item) =>
                                              item.elementKind ==
                                              (opening.kind == OpeningKind.window
                                                  ? ConstructionElementKind.window
                                                  : ConstructionElementKind.door),
                                        ))
                                          DropdownMenuItem(
                                            value: construction.id,
                                            child: Text(construction.title),
                                          ),
                                      ],
                                      onChanged: (value) => value == null
                                          ? null
                                          : onOpeningChanged(
                                              room.id,
                                              boundary.id,
                                              opening.id,
                                              (currentOpening) =>
                                                  currentOpening.copyWith(
                                                constructionId: value,
                                              ),
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _ResultsStep extends StatelessWidget {
  const _ResultsStep({required this.result});

  final BuildingHeatLossResult result;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Итог по объекту',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 10),
                Text('Объект: ${result.projectName}'),
                Text('Климат: ${result.climatePoint.displayName}'),
                Text(
                  'Передача через ограждения: ${result.transmissionLossW.toStringAsFixed(1)} Вт',
                ),
                Text(
                  'Вентиляция и инфильтрация: ${result.ventilationLossW.toStringAsFixed(1)} Вт',
                ),
                Text(
                  'Полный баланс: ${result.totalLossW.toStringAsFixed(1)} Вт',
                ),
                Text(
                  'Коэффициент теплопотерь: ${result.heatLossCoefficientWPerK.toStringAsFixed(2)} Вт/К',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        for (final room in result.roomResults) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room.roomName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${room.roomType.label}, ${room.volumeM3.toStringAsFixed(1)} м³, ${room.targetTemperatureC.toStringAsFixed(1)} °C, ${room.airChangesPerHour.toStringAsFixed(2)} ACH',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ограждения: ${room.transmissionLossW.toStringAsFixed(1)} Вт',
                  ),
                  Text(
                    'Вентиляция: ${room.ventilationLossW.toStringAsFixed(1)} Вт',
                  ),
                  Text('Итого: ${room.totalLossW.toStringAsFixed(1)} Вт'),
                  const SizedBox(height: 12),
                  for (final boundary in room.boundaryResults) ...[
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F6F0),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            boundary.title,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${boundary.surfaceType.label} · ${boundary.boundaryCondition.label}',
                          ),
                          Text(
                            'Площадь ${boundary.grossAreaM2.toStringAsFixed(2)} м², непрозрачная часть ${boundary.opaqueAreaM2.toStringAsFixed(2)} м²',
                          ),
                          Text(
                            'ΔT ${boundary.deltaTemperatureC.toStringAsFixed(1)} °C, потери ${boundary.lossW.toStringAsFixed(1)} Вт',
                          ),
                          if (boundary.openings.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            for (final opening in boundary.openings)
                              Text(
                                '${opening.kind.label}: ${opening.title} · ${opening.areaM2.toStringAsFixed(2)} м² · ${opening.lossW.toStringAsFixed(1)} Вт',
                              ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
