import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/building_heat_loss.dart';
import '../../../core/models/catalog.dart';
import '../../../core/models/project.dart';
import '../../../core/providers.dart';
import '../../building_heat_loss/presentation/building_heat_loss_screen.dart';
import '../../construction_library/presentation/construction_editor_sheet.dart';
import '../../house_scheme/presentation/house_scheme_screen.dart';
import '../../house_scheme/presentation/room_wizard_screen.dart';

final _expandedEnvelopeIdsProvider =
    NotifierProvider<_ExpandedEnvelopeIdsNotifier, Set<String>>(
      _ExpandedEnvelopeIdsNotifier.new,
    );

class _ExpandedEnvelopeIdsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};

  void toggle(String elementId) {
    final next = Set<String>.from(state);
    if (!next.remove(elementId)) {
      next.add(elementId);
    }
    state = next;
  }
}

class RoomEditorStepScreen extends ConsumerStatefulWidget {
  const RoomEditorStepScreen({
    super.key,
    required this.screenTitle,
    required this.statusText,
    this.onOpenPreviousStep,
    this.previousStepLabel,
  });

  final String screenTitle;
  final String statusText;
  final VoidCallback? onOpenPreviousStep;
  final String? previousStepLabel;

  @override
  ConsumerState<RoomEditorStepScreen> createState() =>
      _RoomEditorStepScreenState();
}

class _RoomEditorStepScreenState extends ConsumerState<RoomEditorStepScreen> {
  String? _selectedRoomId;

  String? _effectiveSelectedRoomId(Project project) {
    final rooms = project.houseModel.rooms;
    if (rooms.isEmpty) {
      return null;
    }
    final selectedRoomId = _selectedRoomId;
    if (selectedRoomId != null &&
        rooms.any((room) => room.id == selectedRoomId)) {
      return selectedRoomId;
    }
    return rooms.first.id;
  }

  Future<void> _handleAddRoom(Project project) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final roomCountBefore = project.houseModel.rooms.length;
      final catalog = await ref.read(catalogSnapshotProvider.future);
      if (!mounted) {
        return;
      }
      await showRoomWizard(context, project, catalog);
      if (!mounted) {
        return;
      }
      final updatedProject = await ref.read(selectedProjectProvider.future);
      if (!mounted || updatedProject == null) {
        return;
      }
      if (updatedProject.houseModel.rooms.length > roomCountBefore) {
        setState(
          () => _selectedRoomId = updatedProject.houseModel.rooms.last.id,
        );
      }
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Не удалось добавить помещение: $error')),
      );
    }
  }

  Future<void> _handleEditRoom(Room room) async {
    final messenger = ScaffoldMessenger.of(context);
    final updated = await showRoomEditorSheet(context, room: room);
    if (!mounted || updated == null) {
      return;
    }
    try {
      await ref.read(projectEditorProvider).updateRoom(updated);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Не удалось обновить помещение: $error')),
      );
    }
  }

  Future<void> _handleDeleteRoom(Project project, Room room) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(projectEditorProvider).deleteRoom(room.id);
      if (!mounted) {
        return;
      }
      if (_selectedRoomId == room.id) {
        final remainingRooms = project.houseModel.rooms
            .where((item) => item.id != room.id)
            .toList(growable: false);
        setState(() {
          _selectedRoomId = remainingRooms.isEmpty
              ? null
              : remainingRooms.first.id;
        });
      }
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Не удалось удалить помещение: $error')),
      );
    }
  }

  Future<void> _handleUpdateRoom(Room room, Room updatedRoom) async {
    if (room == updatedRoom) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(projectEditorProvider).updateRoom(updatedRoom);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Не удалось обновить помещение: $error')),
      );
    }
  }

  Future<void> _handleAddElement(
    Project project,
    CatalogSnapshot catalog,
    Room room,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final element = await showElementEditorSheet(
      context,
      project: project,
      catalog: catalog,
      roomId: room.id,
    );
    if (!mounted || element == null) {
      return;
    }
    try {
      await ref.read(projectEditorProvider).addEnvelopeElement(element);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Не удалось добавить ограждение: $error')),
      );
    }
  }

  Future<void> _handleEditElement(
    Project project,
    CatalogSnapshot catalog,
    HouseEnvelopeElement element,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final updated = await showElementEditorSheet(
      context,
      project: project,
      catalog: catalog,
      roomId: element.roomId,
      element: element,
    );
    if (!mounted || updated == null) {
      return;
    }
    try {
      await ref.read(projectEditorProvider).updateEnvelopeElement(updated);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Не удалось обновить ограждение: $error')),
      );
    }
  }

  Future<void> _handleDeleteElement(HouseEnvelopeElement element) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(projectEditorProvider).deleteEnvelopeElement(element.id);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Не удалось удалить ограждение: $error')),
      );
    }
  }

  Future<void> _handleUpdateElementArea(
    HouseEnvelopeElement element,
    double areaSquareMeters,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (element.elementKind == ConstructionElementKind.wall) {
        await ref
            .read(projectEditorProvider)
            .updateEnvelopeWallArea(element.id, areaSquareMeters);
      } else {
        await ref
            .read(projectEditorProvider)
            .updateEnvelopeElement(
              element.copyWith(areaSquareMeters: areaSquareMeters),
            );
      }
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Не удалось обновить площадь: $error')),
      );
    }
  }

  Future<void> _handleUpdateWallOrientation(
    HouseEnvelopeElement element,
    WallOrientation orientation,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(projectEditorProvider)
          .updateEnvelopeElement(
            element.copyWith(wallOrientation: orientation),
          );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Не удалось обновить ориентацию: $error')),
      );
    }
  }

  Future<void> _handleAddOpening(
    CatalogSnapshot catalog,
    HouseEnvelopeElement element, {
    OpeningKind? initialKind,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final opening = await showOpeningEditorSheet(
      context,
      catalog: catalog,
      element: element,
      initialKind: initialKind,
    );
    if (!mounted || opening == null) {
      return;
    }
    try {
      await ref.read(projectEditorProvider).addOpening(opening);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Не удалось добавить проём: $error')),
      );
    }
  }

  Future<void> _handleEditOpening(
    Project project,
    CatalogSnapshot catalog,
    EnvelopeOpening opening,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final element = project.houseModel.elements.firstWhere(
      (item) => item.id == opening.elementId,
    );
    final updated = await showOpeningEditorSheet(
      context,
      catalog: catalog,
      element: element,
      opening: opening,
    );
    if (!mounted || updated == null) {
      return;
    }
    try {
      await ref.read(projectEditorProvider).updateOpening(updated);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Не удалось обновить проём: $error')),
      );
    }
  }

  Future<void> _handleDeleteOpening(EnvelopeOpening opening) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(projectEditorProvider).deleteOpening(opening.id);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Не удалось удалить проём: $error')),
      );
    }
  }

  Future<void> _handleEditElementConstruction(
    CatalogSnapshot catalog,
    List<MaterialCatalogEntry> materialEntries,
    HouseEnvelopeElement element,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final updatedConstruction = await showConstructionEditor(
      context,
      catalog: catalog,
      materialEntries: materialEntries,
      construction: element.construction,
      allowedElementKinds: [element.elementKind],
      onSaveCustomMaterial: (material) async {
        await ref.read(projectEditorProvider).saveCustomMaterial(material);
        return material;
      },
    );
    if (!mounted || updatedConstruction == null) {
      return;
    }
    try {
      await ref
          .read(projectEditorProvider)
          .updateEnvelopeElement(
            element.copyWith(
              construction: updatedConstruction,
              elementKind: updatedConstruction.elementKind,
            ),
          );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Не удалось обновить конструкцию: $error')),
      );
    }
  }

  void _openBuildingHeatLoss() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const BuildingHeatLossScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final projectAsync = ref.watch(selectedProjectProvider);
    final catalogAsync = ref.watch(catalogSnapshotProvider);
    final materialEntriesAsync = ref.watch(materialCatalogEntriesProvider);
    final heatLossAsync = ref.watch(buildingHeatLossResultProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: widget.previousStepLabel ?? 'Назад',
          onPressed:
              widget.onOpenPreviousStep ??
              () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          widget.screenTitle,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Теплопотери',
            onPressed: _openBuildingHeatLoss,
            icon: const Icon(Icons.home_work_outlined),
          ),
          const SizedBox(width: 8),
        ],
        bottom: projectAsync.when(
          data: (project) {
            if (project == null) {
              return null;
            }
            final selectedRoomId = _effectiveSelectedRoomId(project);
            return PreferredSize(
              preferredSize: const Size.fromHeight(64),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(
                    children: [
                      ...project.houseModel.rooms.map(
                        (room) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(room.title),
                            selected: room.id == selectedRoomId,
                            onSelected: (_) =>
                                setState(() => _selectedRoomId = room.id),
                          ),
                        ),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.add, size: 18),
                        label: const Text('Добавить'),
                        onPressed: () => _handleAddRoom(project),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          loading: () => null,
          error: (_, _) => null,
        ),
      ),
      body: projectAsync.when(
        data: (project) {
          if (project == null) {
            return const Center(child: Text('Активный проект не найден.'));
          }
          final selectedRoomId = _effectiveSelectedRoomId(project);
          final selectedRoom = selectedRoomId == null
              ? null
              : project.houseModel.rooms.firstWhere(
                  (room) => room.id == selectedRoomId,
                );
          if (selectedRoom == null) {
            return _EmptyRoomState(onAddRoom: () => _handleAddRoom(project));
          }
          final roomResult = _findRoomResult(
            heatLossAsync.asData?.value,
            selectedRoom.id,
          );
          final roomElements = project.houseModel.elements
              .where((element) => element.roomId == selectedRoom.id)
              .toList(growable: false);
          final openingsByElementId = <String, List<EnvelopeOpening>>{};
          for (final opening in project.houseModel.openings) {
            openingsByElementId
                .putIfAbsent(opening.elementId, () => [])
                .add(opening);
          }
          final elementResults = {
            for (final item
                in roomResult?.elementResults ??
                    const <BuildingElementHeatLossResult>[])
              item.element.id: item,
          };

          return catalogAsync.when(
            data: (catalog) => materialEntriesAsync.when(
              data: (materialEntries) => ListView(
                key: ValueKey('room-step-room-${selectedRoom.id}'),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  _RoomHeader(
                    room: selectedRoom,
                    roomResult: roomResult,
                    onEdit: () => _handleEditRoom(selectedRoom),
                    onDelete: () => _handleDeleteRoom(project, selectedRoom),
                  ),
                  const SizedBox(height: 12),
                  _RoomConditionsCard(
                    room: selectedRoom,
                    onComfortSubmitted: (value) => _handleUpdateRoom(
                      selectedRoom,
                      selectedRoom.copyWith(comfortTemperatureC: value),
                    ),
                    onVentilationSubmitted: (value) => _handleUpdateRoom(
                      selectedRoom,
                      selectedRoom.copyWith(ventilationSupplyM3h: value),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _EnvelopeSection(
                    room: selectedRoom,
                    elements: roomElements,
                    openingsByElementId: openingsByElementId,
                    elementResults: elementResults,
                    onAddElement: () =>
                        _handleAddElement(project, catalog, selectedRoom),
                    buildCard: (element) => _EnvelopeCard(
                      element: element,
                      elementResult: elementResults[element.id],
                      openings: openingsByElementId[element.id] ?? const [],
                      onEditElement: () =>
                          _handleEditElement(project, catalog, element),
                      onDeleteElement: () => _handleDeleteElement(element),
                      onEditConstruction: () => _handleEditElementConstruction(
                        catalog,
                        materialEntries,
                        element,
                      ),
                      onAreaSubmitted: (value) =>
                          _handleUpdateElementArea(element, value),
                      onOrientationChanged: (value) =>
                          _handleUpdateWallOrientation(element, value),
                      onAddOpening: (kind) => _handleAddOpening(
                        catalog,
                        element,
                        initialKind: kind,
                      ),
                      onEditOpening: (opening) =>
                          _handleEditOpening(project, catalog, opening),
                      onDeleteOpening: _handleDeleteOpening,
                    ),
                  ),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('Ошибка материалов: $error')),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('Ошибка каталога: $error')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Ошибка проекта: $error')),
      ),
    );
  }
}

class _RoomHeader extends StatelessWidget {
  const _RoomHeader({
    required this.room,
    required this.roomResult,
    required this.onEdit,
    required this.onDelete,
  });

  final Room room;
  final BuildingRoomHeatLossResult? roomResult;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final infoLine =
        '${room.areaSquareMeters.toStringAsFixed(1)} м² · '
        '${room.heightMeters.toStringAsFixed(1)} м · '
        '${room.comfortTemperatureC.toStringAsFixed(0)}°C';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${room.title} · $infoLine',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      onEdit();
                    } else if (value == 'delete') {
                      onDelete();
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
            if (roomResult != null) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MetricChip(
                    label: 'Потери',
                    value: '${roomResult!.heatLossWatts.toStringAsFixed(0)} Вт',
                  ),
                  _MetricChip(
                    label: 'Вентиляция',
                    value:
                        '${roomResult!.ventilationHeatLossWatts.toStringAsFixed(0)} Вт',
                  ),
                  _MetricChip(
                    label: 'Баланс',
                    value: _formatBalance(roomResult!.heatingPowerDeltaWatts),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RoomConditionsCard extends StatelessWidget {
  const _RoomConditionsCard({
    required this.room,
    required this.onComfortSubmitted,
    required this.onVentilationSubmitted,
  });

  final Room room;
  final ValueChanged<double> onComfortSubmitted;
  final ValueChanged<double> onVentilationSubmitted;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Расчётные условия',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _InlineNumberField(
                    label: 'Комфорт, °C',
                    value: room.comfortTemperatureC,
                    fractionDigits: 1,
                    onSubmitted: onComfortSubmitted,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InlineNumberField(
                    label: 'Приток, м³/ч',
                    value: room.ventilationSupplyM3h,
                    fractionDigits: 1,
                    onSubmitted: onVentilationSubmitted,
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

class _EnvelopeSection extends StatelessWidget {
  const _EnvelopeSection({
    required this.room,
    required this.elements,
    required this.openingsByElementId,
    required this.elementResults,
    required this.onAddElement,
    required this.buildCard,
  });

  final Room room;
  final List<HouseEnvelopeElement> elements;
  final Map<String, List<EnvelopeOpening>> openingsByElementId;
  final Map<String, BuildingElementHeatLossResult> elementResults;
  final VoidCallback onAddElement;
  final Widget Function(HouseEnvelopeElement element) buildCard;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Ограждения',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: onAddElement,
                  icon: const Icon(Icons.add),
                  label: const Text('Добавить'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (elements.isEmpty)
              Text(
                'Для комнаты ${room.title} ещё не добавлены ограждающие конструкции.',
              )
            else
              ...elements.map(
                (element) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: buildCard(element),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EnvelopeCard extends ConsumerWidget {
  const _EnvelopeCard({
    required this.element,
    required this.elementResult,
    required this.openings,
    required this.onEditElement,
    required this.onDeleteElement,
    required this.onEditConstruction,
    required this.onAreaSubmitted,
    required this.onOrientationChanged,
    required this.onAddOpening,
    required this.onEditOpening,
    required this.onDeleteOpening,
  });

  final HouseEnvelopeElement element;
  final BuildingElementHeatLossResult? elementResult;
  final List<EnvelopeOpening> openings;
  final VoidCallback onEditElement;
  final VoidCallback onDeleteElement;
  final VoidCallback onEditConstruction;
  final ValueChanged<double> onAreaSubmitted;
  final ValueChanged<WallOrientation> onOrientationChanged;
  final ValueChanged<OpeningKind> onAddOpening;
  final ValueChanged<EnvelopeOpening> onEditOpening;
  final ValueChanged<EnvelopeOpening> onDeleteOpening;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(
      _expandedEnvelopeIdsProvider.select(
        (value) => value.contains(element.id),
      ),
    );
    final openingArea = openings.fold<double>(
      0,
      (sum, opening) => sum + opening.areaSquareMeters,
    );
    final opaqueArea = (element.areaSquareMeters - openingArea).clamp(
      0.0,
      element.areaSquareMeters,
    );
    final losses = elementResult?.totalHeatLossWatts;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => ref
                .read(_expandedEnvelopeIdsProvider.notifier)
                .toggle(element.id),
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${element.title} · ${element.elementKind.label} · '
                      '${element.areaSquareMeters.toStringAsFixed(1)} м² · '
                      '${losses == null ? '—' : '${losses.toStringAsFixed(0)} Вт'}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        onEditElement();
                      } else if (value == 'construction') {
                        onEditConstruction();
                      } else if (value == 'delete') {
                        onDeleteElement();
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: Text('Редактировать ограждение'),
                      ),
                      PopupMenuItem(
                        value: 'construction',
                        child: Text('Редактировать конструкцию'),
                      ),
                      PopupMenuItem(value: 'delete', child: Text('Удалить')),
                    ],
                  ),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Тип: ${element.elementKind.label}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Конструкция: '
                    '${element.sourceConstructionTitle ?? element.construction.title}',
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _InlineNumberField(
                          label: 'Площадь, м²',
                          value: element.areaSquareMeters,
                          fractionDigits: 2,
                          onSubmitted: onAreaSubmitted,
                        ),
                      ),
                      if (element.elementKind ==
                          ConstructionElementKind.wall) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<WallOrientation>(
                            initialValue:
                                element.wallOrientation ??
                                WallOrientation.north,
                            decoration: const InputDecoration(
                              labelText: 'Ориентация',
                            ),
                            items: WallOrientation.values
                                .map(
                                  (orientation) => DropdownMenuItem(
                                    value: orientation,
                                    child: Text(orientation.label),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: (value) {
                              if (value != null) {
                                onOrientationChanged(value);
                              }
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (element.elementKind == ConstructionElementKind.wall &&
                      element.wallPlacement != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Сегмент: ${element.wallPlacement!.side.label} · '
                      '${element.wallPlacement!.lengthMeters.toStringAsFixed(1)} м',
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Проёмы',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      FilledButton.tonal(
                        onPressed: () => onAddOpening(OpeningKind.window),
                        child: const Text('+ Окно'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonal(
                        onPressed: () => onAddOpening(OpeningKind.door),
                        child: const Text('+ Дверь'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (openings.isEmpty)
                    const Text('Проёмы не добавлены.')
                  else
                    ...openings.map(
                      (opening) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _OpeningTile(
                          opening: opening,
                          onTap: () => onEditOpening(opening),
                          onDelete: () => onDeleteOpening(opening),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    'Чистая площадь: ${opaqueArea.toStringAsFixed(2)} м²',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    elementResult == null
                        ? 'Теплопотери: расчёт недоступен'
                        : 'Теплопотери: ${elementResult!.totalHeatLossWatts.toStringAsFixed(0)} Вт '
                              '(через ограждение: ${elementResult!.opaqueHeatLossWatts.toStringAsFixed(0)} · '
                              'проёмы: ${elementResult!.openingHeatLossWatts.toStringAsFixed(0)})',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _OpeningTile extends StatelessWidget {
  const _OpeningTile({
    required this.opening,
    required this.onTap,
    required this.onDelete,
  });

  final EnvelopeOpening opening;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                opening.kind == OpeningKind.window
                    ? Icons.window_outlined
                    : Icons.door_front_door_outlined,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${opening.title} · '
                  '${opening.widthMeters.toStringAsFixed(2)}×'
                  '${opening.heightMeters.toStringAsFixed(2)} м · '
                  '${opening.areaSquareMeters.toStringAsFixed(2)} м² · '
                  'U ${opening.heatTransferCoefficient.toStringAsFixed(2)}',
                ),
              ),
              IconButton(
                tooltip: 'Удалить',
                onPressed: onDelete,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineNumberField extends StatefulWidget {
  const _InlineNumberField({
    required this.label,
    required this.value,
    required this.onSubmitted,
    this.fractionDigits = 2,
  });

  final String label;
  final double value;
  final ValueChanged<double> onSubmitted;
  final int fractionDigits;

  @override
  State<_InlineNumberField> createState() => _InlineNumberFieldState();
}

class _InlineNumberFieldState extends State<_InlineNumberField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value.toStringAsFixed(widget.fractionDigits),
  );

  @override
  void didUpdateWidget(covariant _InlineNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _controller.text = widget.value.toStringAsFixed(widget.fractionDigits);
    }
  }

  void _commit() {
    final parsed = double.tryParse(_controller.text.replaceAll(',', '.'));
    if (parsed != null && parsed > 0 && parsed != widget.value) {
      widget.onSubmitted(parsed);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: InputDecoration(labelText: widget.label),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _commit(),
      onTapOutside: (_) => _commit(),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Text('$label: $value'),
    );
  }
}

class _EmptyRoomState extends StatelessWidget {
  const _EmptyRoomState({required this.onAddRoom});

  final VoidCallback onAddRoom;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Помещения не добавлены',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Добавьте помещение, затем задайте расчётные условия и ограждающие конструкции.',
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onAddRoom,
                  icon: const Icon(Icons.add),
                  label: const Text('Добавить помещение'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

BuildingRoomHeatLossResult? _findRoomResult(
  BuildingHeatLossResult? heatLoss,
  String roomId,
) {
  if (heatLoss == null) {
    return null;
  }
  for (final roomResult in heatLoss.roomResults) {
    if (roomResult.room.id == roomId) {
      return roomResult;
    }
  }
  return null;
}

String _formatBalance(double value) {
  final sign = value > 0 ? '+' : '';
  return '$sign${value.toStringAsFixed(0)} Вт';
}
