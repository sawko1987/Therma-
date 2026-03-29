import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/building_heat_loss.dart';
import '../../../core/models/catalog.dart';
import '../../../core/models/project.dart';
import '../../../core/providers.dart';
import '../../construction_library/presentation/construction_editor_sheet.dart';
import '../../building_heat_loss/presentation/building_heat_loss_screen.dart';
import 'floor_plan_geometry.dart';
import 'widgets/floor_plan_editor_card.dart';
import 'widgets/heating_devices_card.dart';
import '../../thermocalc/presentation/thermocalc_screen.dart';

class HouseSchemeScreen extends ConsumerWidget {
  const HouseSchemeScreen({
    super.key,
    this.screenTitle = 'Сборка дома',
    this.statusText,
    this.limitToSelectedConstructions = false,
    this.showConstructionsCard = true,
    this.showHeatingDevices = true,
    this.trailingHeader,
  });

  final String screenTitle;
  final String? statusText;
  final bool limitToSelectedConstructions;
  final bool showConstructionsCard;
  final bool showHeatingDevices;
  final Widget? trailingHeader;

  Future<Room?> _handleAddRoom(
    BuildContext context,
    WidgetRef ref,
    Project project,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final layout = buildFirstAvailableRoomLayout(
      project.houseModel.rooms,
      widthMeters: defaultPlacedRoomWidthMeters,
      heightMeters: defaultPlacedRoomHeightMeters,
    );
    final roomIndex = project.houseModel.rooms.length + 1;
    final room = Room(
      id: _buildId('room'),
      title: 'Помещение $roomIndex',
      kind: RoomKind.livingRoom,
      heightMeters: defaultRoomHeightMeters,
      layout: layout,
    );
    try {
      await ref.read(projectEditorProvider).addRoom(room);
      return room;
    } catch (error) {
      _showError(messenger, error);
      return null;
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

  Future<String?> _handleUpdateRoom(
    BuildContext context,
    WidgetRef ref,
    Room room,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(projectEditorProvider).updateRoom(room);
      return null;
    } catch (error) {
      _showError(messenger, error);
      return _describeError(error);
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

  Future<String?> _handleUpdateRoomLayout(
    BuildContext context,
    WidgetRef ref,
    String roomId,
    RoomLayoutRect layout,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(projectEditorProvider).updateRoomLayout(roomId, layout);
      return null;
    } catch (error) {
      _showError(messenger, error);
      return _describeError(error);
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

  Future<String?> _handleMergeRooms(
    BuildContext context,
    WidgetRef ref,
    String primaryRoomId,
    String secondaryRoomId,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(projectEditorProvider)
          .mergeRoomsAcrossPartition(primaryRoomId, secondaryRoomId);
      return null;
    } catch (error) {
      _showError(messenger, error);
      return _describeError(error);
    }
  }

  Future<String?> _handleSplitWall(
    BuildContext context,
    WidgetRef ref,
    String elementId,
    double splitOffsetMeters,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(projectEditorProvider)
          .splitExteriorWallSegment(elementId, splitOffsetMeters);
      return null;
    } catch (error) {
      _showError(messenger, error);
      return _describeError(error);
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

  Future<void> _handleAddHeatingDevice(
    BuildContext context,
    WidgetRef ref,
    CatalogSnapshot catalog,
    Room room,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final heatingDevice = await _showHeatingDeviceEditor(
      context,
      catalog: catalog,
      roomId: room.id,
    );
    if (!context.mounted || heatingDevice == null) {
      return;
    }
    try {
      await ref.read(projectEditorProvider).addHeatingDevice(heatingDevice);
    } catch (error) {
      _showError(messenger, error);
    }
  }

  Future<void> _handleEditHeatingDevice(
    BuildContext context,
    WidgetRef ref,
    CatalogSnapshot catalog,
    HeatingDevice heatingDevice,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final updated = await _showHeatingDeviceEditor(
      context,
      catalog: catalog,
      roomId: heatingDevice.roomId,
      heatingDevice: heatingDevice,
    );
    if (!context.mounted || updated == null) {
      return;
    }
    try {
      await ref.read(projectEditorProvider).updateHeatingDevice(updated);
    } catch (error) {
      _showError(messenger, error);
    }
  }

  Future<void> _handleDeleteHeatingDevice(
    BuildContext context,
    WidgetRef ref,
    HeatingDevice heatingDevice,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!context.mounted) {
      return;
    }
    try {
      await ref
          .read(projectEditorProvider)
          .deleteHeatingDevice(heatingDevice.id);
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

  void _handleOpenBuildingHeatLoss(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const BuildingHeatLossScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectAsync = ref.watch(selectedProjectProvider);
    final catalogAsync = ref.watch(catalogSnapshotProvider);
    final summaryAsync = ref.watch(buildingHeatLossResultProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          screenTitle,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          _StatusCard(
            text:
                statusText ??
                'Конструктор дома собирает проект сверху вниз: помещения, ограждения, окна/двери и переиспользуемые конструкции. Расчёт конструкции запускается прямо из выбранного ограждения, а сводка дома учитывает чистую площадь и проёмы.',
          ),
          if (trailingHeader != null) ...[
            const SizedBox(height: 16),
            trailingHeader!,
          ],
          const SizedBox(height: 16),
          summaryAsync.when(
            data: (summary) => projectAsync.when(
              data: (project) {
                if (project == null || summary == null) {
                  return const Text('Активный проект не найден.');
                }
                final effectiveProject = _resolveProject(project);
                return _SummaryCard(
                  project: effectiveProject,
                  summary: summary,
                  onOpenBuildingHeatLoss: () =>
                      _handleOpenBuildingHeatLoss(context),
                );
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
                final effectiveProject = _resolveProject(project);
                return Column(
                  children: [
                    _PlanAndRoomsSection(
                      project: effectiveProject,
                      catalog: catalog,
                      summary: summaryAsync.asData?.value,
                      showHeatingDevices: showHeatingDevices,
                      onAddRoom: () => _handleAddRoom(context, ref, project),
                      onUpdateRoom: (room) =>
                          _handleUpdateRoom(context, ref, room),
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
                      onMergeRooms: (primaryRoomId, secondaryRoomId) =>
                          _handleMergeRooms(
                            context,
                            ref,
                            primaryRoomId,
                            secondaryRoomId,
                          ),
                      onSplitWall: (elementId, splitOffsetMeters) =>
                          _handleSplitWall(
                            context,
                            ref,
                            elementId,
                            splitOffsetMeters,
                          ),
                      onDeleteElement: (element) =>
                          _handleDeleteElement(context, ref, element),
                      onAddOpening: (element) =>
                          _handleAddOpening(context, ref, element),
                      onEditOpening: (opening) =>
                          _handleEditOpening(context, ref, opening),
                      onDeleteOpening: (opening) =>
                          _handleDeleteOpening(context, ref, opening),
                      onAddHeatingDevice: (room) =>
                          _handleAddHeatingDevice(context, ref, catalog, room),
                      onEditHeatingDevice: (heatingDevice) =>
                          _handleEditHeatingDevice(
                            context,
                            ref,
                            catalog,
                            heatingDevice,
                          ),
                      onDeleteHeatingDevice: (heatingDevice) =>
                          _handleDeleteHeatingDevice(
                            context,
                            ref,
                            heatingDevice,
                          ),
                      onOpenThermocalc: (element) =>
                          _handleOpenThermocalc(context, ref, element),
                    ),
                    if (showConstructionsCard) ...[
                      const SizedBox(height: 16),
                      _ConstructionsCard(
                        project: effectiveProject,
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
                            _handleDeleteConstruction(
                              context,
                              ref,
                              construction,
                            ),
                      ),
                    ],
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

  Project _resolveProject(Project project) {
    if (!limitToSelectedConstructions) {
      return project;
    }
    final selectedIds = project.effectiveSelectedConstructionIds.toSet();
    return project.copyWith(
      constructions: [
        for (final item in project.constructions)
          if (selectedIds.contains(item.id)) item,
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF2EEE4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.project,
    required this.summary,
    required this.onOpenBuildingHeatLoss,
  });

  final Project project;
  final BuildingHeatLossResult summary;
  final VoidCallback onOpenBuildingHeatLoss;

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
            Text(
              'Расчетная наружная температура: '
              '${summary.outsideAirTemperature.toStringAsFixed(0)} °C',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _MetricTile(
                  label: 'Помещения',
                  value: '${summary.totalRoomCount}',
                ),
                _MetricTile(
                  label: 'Ограждения',
                  value: '${summary.totalElementCount}',
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
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  key: const ValueKey('open-building-heat-loss-button'),
                  onPressed: onOpenBuildingHeatLoss,
                  icon: const Icon(Icons.home_work_outlined),
                  label: const Text('Открыть расчет потерь'),
                ),
                if (summary.unresolvedElements.isNotEmpty)
                  Chip(
                    label: Text(
                      'Пропущено элементов: ${summary.unresolvedElements.length}',
                    ),
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
    required this.catalog,
    required this.summary,
    required this.showHeatingDevices,
    required this.onAddRoom,
    required this.onUpdateRoom,
    required this.onUpdateRoomLayout,
    required this.onEditRoom,
    required this.onDeleteRoom,
    required this.onAddElement,
    required this.onEditElement,
    required this.onMergeRooms,
    required this.onSplitWall,
    required this.onDeleteElement,
    required this.onAddOpening,
    required this.onEditOpening,
    required this.onDeleteOpening,
    required this.onAddHeatingDevice,
    required this.onEditHeatingDevice,
    required this.onDeleteHeatingDevice,
    required this.onOpenThermocalc,
  });

  final Project project;
  final CatalogSnapshot catalog;
  final BuildingHeatLossResult? summary;
  final bool showHeatingDevices;
  final Future<Room?> Function() onAddRoom;
  final Future<String?> Function(Room room) onUpdateRoom;
  final Future<String?> Function(String roomId, RoomLayoutRect layout)
  onUpdateRoomLayout;
  final ValueChanged<Room> onEditRoom;
  final ValueChanged<Room> onDeleteRoom;
  final ValueChanged<Room> onAddElement;
  final ValueChanged<HouseEnvelopeElement> onEditElement;
  final Future<String?> Function(String primaryRoomId, String secondaryRoomId)
  onMergeRooms;
  final Future<String?> Function(String elementId, double splitOffsetMeters)
  onSplitWall;
  final ValueChanged<HouseEnvelopeElement> onDeleteElement;
  final ValueChanged<HouseEnvelopeElement> onAddOpening;
  final ValueChanged<EnvelopeOpening> onEditOpening;
  final ValueChanged<EnvelopeOpening> onDeleteOpening;
  final ValueChanged<Room> onAddHeatingDevice;
  final ValueChanged<HeatingDevice> onEditHeatingDevice;
  final ValueChanged<HeatingDevice> onDeleteHeatingDevice;
  final ValueChanged<HouseEnvelopeElement> onOpenThermocalc;

  @override
  State<_PlanAndRoomsSection> createState() => _PlanAndRoomsSectionState();
}

class _PlanAndRoomsSectionState extends State<_PlanAndRoomsSection> {
  String? _selectedRoomId;
  String? _selectedElementId;

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

  void _selectElement(String elementId, String roomId) {
    setState(() {
      _selectedElementId = elementId;
      _selectedRoomId = roomId;
    });
  }

  Future<void> _handleAddRoom() async {
    final room = await widget.onAddRoom();
    if (!mounted || room == null) {
      return;
    }
    setState(() => _selectedRoomId = room.id);
  }

  @override
  Widget build(BuildContext context) {
    final selectedRoomId = _effectiveSelectedRoomId;
    final selectedRoom = selectedRoomId == null
        ? null
        : widget.project.houseModel.rooms.firstWhere(
            (room) => room.id == selectedRoomId,
          );
    return Column(
      children: [
        FloorPlanEditorCard(
          project: widget.project,
          selectedRoomId: selectedRoomId,
          selectedElementId: _selectedElementId,
          onAddRoom: _handleAddRoom,
          onSelectRoom: _selectRoom,
          onSelectElement: _selectElement,
          onUpdateRoomLayout: widget.onUpdateRoomLayout,
          onMergeRooms: widget.onMergeRooms,
          onSplitWall: widget.onSplitWall,
        ),
        if (selectedRoom != null) ...[
          const SizedBox(height: 16),
          _SelectedRoomEditorCard(
            room: selectedRoom,
            onSave: widget.onUpdateRoom,
          ),
        ],
        const SizedBox(height: 16),
        _RoomsCard(
          project: widget.project,
          selectedRoomId: selectedRoomId,
          onSelectRoom: _selectRoom,
          onAddRoom: _handleAddRoom,
          onEditRoom: widget.onEditRoom,
          onDeleteRoom: widget.onDeleteRoom,
          onAddElement: widget.onAddElement,
          onEditElement: widget.onEditElement,
          onSelectElement: _selectElement,
          onDeleteElement: widget.onDeleteElement,
          onAddOpening: widget.onAddOpening,
          onEditOpening: widget.onEditOpening,
          onDeleteOpening: widget.onDeleteOpening,
          onOpenThermocalc: widget.onOpenThermocalc,
        ),
        if (widget.showHeatingDevices) ...[
          const SizedBox(height: 16),
          HeatingDevicesCard(
            project: widget.project,
            catalog: widget.catalog,
            summary: widget.summary,
            selectedRoomId: selectedRoomId,
            onSelectRoom: _selectRoom,
            onAddHeatingDevice: widget.onAddHeatingDevice,
            onEditHeatingDevice: widget.onEditHeatingDevice,
            onDeleteHeatingDevice: widget.onDeleteHeatingDevice,
          ),
        ],
      ],
    );
  }
}

class _RoomsCard extends StatelessWidget {
  const _RoomsCard({
    required this.project,
    required this.selectedRoomId,
    required this.onSelectRoom,
    required this.onAddRoom,
    required this.onEditRoom,
    required this.onSelectElement,
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
  final void Function(String elementId, String roomId) onSelectElement;
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
              final wallElements = roomElements
                  .where(
                    (element) =>
                        element.elementKind == ConstructionElementKind.wall,
                  )
                  .toList(growable: false);
              final manualElements = roomElements
                  .where(
                    (element) =>
                        element.elementKind != ConstructionElementKind.wall,
                  )
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
                                      room.effectiveCells.length == 1
                                          ? 'План: ${room.layout.widthMeters.toStringAsFixed(1)} x ${room.layout.heightMeters.toStringAsFixed(1)} м • позиция ${room.layout.xMeters.toStringAsFixed(1)} / ${room.layout.yMeters.toStringAsFixed(1)} м'
                                          : 'Фигурное помещение из ${room.effectiveCells.length} ячеек • габарит ${room.layout.widthMeters.toStringAsFixed(1)} x ${room.layout.heightMeters.toStringAsFixed(1)} м',
                                    ),
                                    Text(
                                      'Наружных стен: ${wallElements.length}, прочих ограждений: ${manualElements.length}, проёмов: ${roomOpenings.length}, валовая площадь ${envelopeArea.toStringAsFixed(1)} м², чистая ${opaqueArea.toStringAsFixed(1)} м²',
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
                            child: const Text('Добавить пол / потолок / крышу'),
                          ),
                          const SizedBox(height: 12),
                          if (roomElements.isEmpty)
                            const Text('Пока нет ограждающих элементов.')
                          else ...[
                            Text(
                              'Наружные стены',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 8),
                            if (wallElements.isEmpty)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 12),
                                child: Text(
                                  'Контур стены построится автоматически по ячейкам помещения.',
                                ),
                              )
                            else
                              ...wallElements.map((element) {
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
                                final segment = element.lineSegment;
                                final geometryLabel = segment == null
                                    ? 'Геометрия ещё не перестроена'
                                    : 'Сегмент ${segment.lengthMeters.toStringAsFixed(1)} м • '
                                          '${segment.startXMeters.toStringAsFixed(1)}, ${segment.startYMeters.toStringAsFixed(1)} -> '
                                          '${segment.endXMeters.toStringAsFixed(1)}, ${segment.endYMeters.toStringAsFixed(1)}';
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
                                            onTap: () => onSelectElement(
                                              element.id,
                                              room.id,
                                            ),
                                            title: Text(
                                              element.title,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            subtitle: Text(
                                              'Стена • валовая площадь ${element.areaSquareMeters.toStringAsFixed(1)} м² • чистая ${opaqueArea.toStringAsFixed(1)} м²\n'
                                              'Проёмы: ${openings.length} / ${openingArea.toStringAsFixed(1)} м² • Конструкция: ${construction?.title ?? element.constructionId}\n'
                                              '$geometryLabel',
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
                                                  child: Text(
                                                    'Изменить конструкцию',
                                                  ),
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
                                              child: Text(
                                                'Проёмы не добавлены.',
                                              ),
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
                                                        BorderRadius.circular(
                                                          14,
                                                        ),
                                                  ),
                                                  title: Text(
                                                    opening.title,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
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
                                                        itemBuilder:
                                                            (context) => const [
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
                            const SizedBox(height: 4),
                            Text(
                              'Прочие ограждения',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 8),
                            if (manualElements.isEmpty)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 12),
                                child: Text(
                                  'Пол, перекрытие и крыша пока не добавлены.',
                                ),
                              )
                            else
                              ...manualElements.map((element) {
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
                                final geometryLabel =
                                    element.elementKind ==
                                            ConstructionElementKind.wall &&
                                        element.wallPlacement != null
                                    ? '${element.wallPlacement!.side.label}, сегмент ${element.wallPlacement!.lengthMeters.toStringAsFixed(1)} м, смещение ${element.wallPlacement!.offsetMeters.toStringAsFixed(1)} м'
                                    : 'Без геометрической привязки';
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
                                            onTap: () => onSelectElement(
                                              element.id,
                                              room.id,
                                            ),
                                            title: Text(
                                              element.title,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            subtitle: Text(
                                              '${element.elementKind.label} • валовая площадь ${element.areaSquareMeters.toStringAsFixed(1)} м² • чистая ${opaqueArea.toStringAsFixed(1)} м²\n'
                                              'Проёмы: ${openings.length} / ${openingArea.toStringAsFixed(1)} м² • Конструкция: ${construction?.title ?? element.constructionId}\n'
                                              '$geometryLabel',
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
                                              child: Text(
                                                'Проёмы не добавлены.',
                                              ),
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
                                                        BorderRadius.circular(
                                                          14,
                                                        ),
                                                  ),
                                                  title: Text(
                                                    opening.title,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
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
                                                        itemBuilder:
                                                            (context) => const [
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

class _SelectedRoomEditorCard extends StatefulWidget {
  const _SelectedRoomEditorCard({required this.room, required this.onSave});

  final Room room;
  final Future<String?> Function(Room room) onSave;

  @override
  State<_SelectedRoomEditorCard> createState() =>
      _SelectedRoomEditorCardState();
}

class _SelectedRoomEditorCardState extends State<_SelectedRoomEditorCard> {
  late final TextEditingController _titleController;
  late final TextEditingController _widthController;
  late final TextEditingController _heightController;
  late final TextEditingController _roomHeightController;
  late RoomKind _selectedKind;
  String? _lastError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _widthController = TextEditingController();
    _heightController = TextEditingController();
    _roomHeightController = TextEditingController();
    _syncFromRoom(widget.room);
  }

  @override
  void didUpdateWidget(covariant _SelectedRoomEditorCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.room.id != widget.room.id ||
        oldWidget.room.title != widget.room.title ||
        oldWidget.room.kind != widget.room.kind ||
        !layoutsEqual(oldWidget.room.layout, widget.room.layout) ||
        oldWidget.room.heightMeters != widget.room.heightMeters) {
      _syncFromRoom(widget.room);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _roomHeightController.dispose();
    super.dispose();
  }

  void _syncFromRoom(Room room) {
    _titleController.text = room.title;
    _widthController.text = room.effectiveCells.length == 1
        ? room.layout.widthMeters.toStringAsFixed(1)
        : '';
    _heightController.text = room.effectiveCells.length == 1
        ? room.layout.heightMeters.toStringAsFixed(1)
        : '';
    _roomHeightController.text = room.heightMeters.toStringAsFixed(1);
    _selectedKind = room.kind;
    _lastError = null;
  }

  Future<void> _handleSave() async {
    setState(() {
      _saving = true;
      _lastError = null;
    });
    final updated = widget.room.copyWith(
      title: _requiredText(_titleController.text, fallback: widget.room.title),
      kind: _selectedKind,
      heightMeters: _parseDouble(
        _roomHeightController.text,
        fallback: widget.room.heightMeters,
      ),
      layout: widget.room.effectiveCells.length == 1
          ? snapRoomLayout(
              widget.room.layout.copyWith(
                widthMeters: _parseDouble(
                  _widthController.text,
                  fallback: widget.room.layout.widthMeters,
                ),
                heightMeters: _parseDouble(
                  _heightController.text,
                  fallback: widget.room.layout.heightMeters,
                ),
              ),
            )
          : widget.room.layout,
    );
    final error = await widget.onSave(updated);
    if (!mounted) {
      return;
    }
    setState(() {
      _saving = false;
      _lastError = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Параметры выбранного помещения',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'После добавления помещение сразу появляется на плане. Выберите его и задайте длину, ширину и высоту здесь, а позицию уточняйте перетаскиванием на схеме.',
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('selected-room-title-field'),
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Название'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<RoomKind>(
              key: const ValueKey('selected-room-kind-field'),
              initialValue: _selectedKind,
              decoration: const InputDecoration(labelText: 'Тип помещения'),
              items: RoomKind.values
                  .map(
                    (item) =>
                        DropdownMenuItem(value: item, child: Text(item.label)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedKind = value);
                }
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('selected-room-width-field'),
                    controller: _widthController,
                    decoration: const InputDecoration(labelText: 'Длина, м'),
                    enabled: widget.room.effectiveCells.length == 1,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    key: const ValueKey('selected-room-height-field'),
                    controller: _heightController,
                    decoration: const InputDecoration(labelText: 'Ширина, м'),
                    enabled: widget.room.effectiveCells.length == 1,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    key: const ValueKey('selected-room-z-field'),
                    controller: _roomHeightController,
                    decoration: const InputDecoration(labelText: 'Высота, м'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              widget.room.effectiveCells.length == 1
                  ? 'Позиция на плане: ${widget.room.layout.xMeters.toStringAsFixed(1)} / ${widget.room.layout.yMeters.toStringAsFixed(1)} м'
                  : 'Фигурное помещение: ${widget.room.effectiveCells.length} ячеек, габарит ${widget.room.layout.widthMeters.toStringAsFixed(1)} x ${widget.room.layout.heightMeters.toStringAsFixed(1)} м',
            ),
            Text(
              'Площадь: ${widget.room.areaSquareMeters.toStringAsFixed(1)} м²',
            ),
            if (widget.room.effectiveCells.length > 1) ...[
              const SizedBox(height: 8),
              const Text(
                'Для составного помещения размеры отдельных сторон пока меняются через добавление соседней ячейки и удаление перегородки.',
              ),
            ],
            if (_lastError != null) ...[
              const SizedBox(height: 12),
              Text(
                _lastError!,
                key: const ValueKey('selected-room-save-error'),
                style: const TextStyle(
                  color: Color(0xFF9C2F2F),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const ValueKey('selected-room-save-button'),
              onPressed: _saving ? null : _handleSave,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Сохранить параметры'),
            ),
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
  final widthController = TextEditingController(
    text:
        (room?.layout.widthMeters ??
                initialLayout?.widthMeters ??
                defaultRoomLayoutWidthMeters)
            .toString(),
  );
  final planHeightController = TextEditingController(
    text:
        (room?.layout.heightMeters ??
                initialLayout?.heightMeters ??
                defaultRoomLayoutHeightMeters)
            .toString(),
  );
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
                    '${snapRoomLayout(effectiveLayout.copyWith(
                      widthMeters: _parseDouble(widthController.text, fallback: effectiveLayout.widthMeters),
                      heightMeters: _parseDouble(planHeightController.text, fallback: effectiveLayout.heightMeters),
                    )).areaSquareMeters.toStringAsFixed(1)} м²',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: widthController,
                        decoration: const InputDecoration(
                          labelText: 'Длина, м',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: planHeightController,
                        decoration: const InputDecoration(
                          labelText: 'Ширина, м',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                  ],
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
                        layout: snapRoomLayout(
                          effectiveLayout.copyWith(
                            widthMeters: _parseDouble(
                              widthController.text,
                              fallback: effectiveLayout.widthMeters,
                            ),
                            heightMeters: _parseDouble(
                              planHeightController.text,
                              fallback: effectiveLayout.heightMeters,
                            ),
                          ),
                        ),
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
  widthController.dispose();
  planHeightController.dispose();
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
  final editableKinds = ConstructionElementKind.values
      .where((kind) => kind != ConstructionElementKind.wall)
      .toList(growable: false);
  final titleController = TextEditingController(text: element?.title ?? '');
  final areaController = TextEditingController(
    text: (element?.areaSquareMeters ?? defaultHouseElementAreaSquareMeters)
        .toString(),
  );
  var selectedRoomId = element?.roomId ?? roomId;
  var selectedConstructionId =
      element?.constructionId ??
      (project.constructions.isEmpty ? null : project.constructions.first.id);
  var selectedKind =
      element?.elementKind ??
      (project.constructions.isEmpty
          ? ConstructionElementKind.floor
          : project.constructions.first.elementKind);
  if (selectedKind == ConstructionElementKind.wall &&
      editableKinds.isNotEmpty) {
    selectedKind = editableKinds.first;
  }

  final result = await showModalBottomSheet<HouseEnvelopeElement>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          final constructionsForKind = project.constructions
              .where((construction) => construction.elementKind == selectedKind)
              .toList(growable: false);
          if (constructionsForKind.isNotEmpty &&
              !constructionsForKind.any(
                (construction) => construction.id == selectedConstructionId,
              )) {
            selectedConstructionId = constructionsForKind.first.id;
          }

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
                  items: editableKinds
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
                        final firstMatching = project.constructions
                            .where(
                              (construction) =>
                                  construction.elementKind == selectedKind,
                            )
                            .toList(growable: false);
                        selectedConstructionId = firstMatching.isEmpty
                            ? null
                            : firstMatching.first.id;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                if (editableKinds.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Сначала добавьте конструкцию пола, перекрытия или крыши. Наружные стены теперь строятся автоматически по контуру помещения.',
                    ),
                  ),
                DropdownButtonFormField<String>(
                  initialValue: selectedConstructionId,
                  decoration: const InputDecoration(labelText: 'Конструкция'),
                  items: constructionsForKind
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
                  onPressed:
                      selectedConstructionId == null || editableKinds.isEmpty
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
  return showConstructionEditor(
    context,
    catalog: catalog,
    materialEntries: catalog.materials
        .map(
          (material) => MaterialCatalogEntry(
            material: material,
            source: material.isCustom
                ? MaterialCatalogSource.custom
                : MaterialCatalogSource.seed,
            isFavorite: false,
          ),
        )
        .toList(growable: false),
    construction: construction,
  );
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

// ignore: unused_element
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

Future<HeatingDevice?> _showHeatingDeviceEditor(
  BuildContext context, {
  required CatalogSnapshot catalog,
  required String roomId,
  HeatingDevice? heatingDevice,
}) async {
  final titleController = TextEditingController(
    text: heatingDevice?.title ?? '',
  );
  final powerController = TextEditingController(
    text: (heatingDevice?.ratedPowerWatts ?? 1500).toStringAsFixed(0),
  );
  final notesController = TextEditingController(
    text: heatingDevice?.notes ?? '',
  );
  HeatingDeviceKind selectedKind =
      heatingDevice?.kind ?? HeatingDeviceKind.radiator;
  String? selectedCatalogItemId = heatingDevice?.catalogItemId;

  final result = await showModalBottomSheet<HeatingDevice>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          final catalogEntries = catalog.heatingDevices;
          HeatingDeviceCatalogEntry? selectedCatalogItem;
          if (selectedCatalogItemId != null) {
            for (final item in catalogEntries) {
              if (item.id == selectedCatalogItemId) {
                selectedCatalogItem = item;
                break;
              }
            }
          }

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
                  heatingDevice == null
                      ? 'Новый отопительный прибор'
                      : 'Редактирование отопительного прибора',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                if (catalogEntries.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String?>(
                    initialValue: selectedCatalogItemId,
                    decoration: const InputDecoration(
                      labelText: 'Шаблон из каталога',
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Без шаблона'),
                      ),
                      ...catalogEntries.map(
                        (item) => DropdownMenuItem<String?>(
                          value: item.id,
                          child: Text(
                            '${item.title} • ${item.ratedPowerWatts.toStringAsFixed(0)} Вт',
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedCatalogItemId = value;
                        if (value == null) {
                          return;
                        }
                        final selected = catalogEntries.firstWhere(
                          (item) => item.id == value,
                        );
                        titleController.text = selected.title;
                        powerController.text = selected.ratedPowerWatts
                            .toStringAsFixed(0);
                        selectedKind = parseHeatingDeviceKind(selected.kind);
                      });
                    },
                  ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<HeatingDeviceKind>(
                  initialValue: selectedKind,
                  decoration: const InputDecoration(labelText: 'Тип прибора'),
                  items: HeatingDeviceKind.values
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
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Название'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: powerController,
                  decoration: const InputDecoration(
                    labelText: 'Тепловая мощность, Вт',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'Примечание'),
                  minLines: 1,
                  maxLines: 3,
                ),
                if (selectedCatalogItem != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Каталог: ${selectedCatalogItem.title} • ${selectedCatalogItem.ratedPowerWatts.toStringAsFixed(0)} Вт',
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop(
                      HeatingDevice(
                        id: heatingDevice?.id ?? _buildId('heating-device'),
                        roomId: roomId,
                        title: _requiredText(
                          titleController.text,
                          fallback: selectedKind.label,
                        ),
                        kind: selectedKind,
                        ratedPowerWatts: _parseDouble(
                          powerController.text,
                          fallback: 1500,
                        ),
                        catalogItemId: selectedCatalogItemId,
                        notes: notesController.text.trim().isEmpty
                            ? null
                            : notesController.text.trim(),
                      ),
                    );
                  },
                  child: const Text('Сохранить прибор'),
                ),
              ],
            ),
          );
        },
      );
    },
  );

  titleController.dispose();
  powerController.dispose();
  notesController.dispose();
  return result;
}

String _buildId(String prefix) {
  return '$prefix-${DateTime.now().microsecondsSinceEpoch}';
}

double _parseDouble(String value, {required double fallback}) {
  return double.tryParse(value.replaceAll(',', '.')) ?? fallback;
}

String _requiredText(String value, {required String fallback}) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? fallback : trimmed;
}

String _describeError(Object error) {
  return error.toString().replaceFirst(RegExp(r'^Bad state: '), '');
}

void _showError(ScaffoldMessengerState messenger, Object error) {
  messenger.showSnackBar(
    SnackBar(
      content: Text('Не удалось выполнить действие: ${_describeError(error)}'),
    ),
  );
}
