import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/building_heat_loss.dart';
import '../../../core/models/catalog.dart';
import '../../../core/models/project.dart';
import '../../../core/providers.dart';
import '../../building_heat_loss/presentation/building_heat_loss_screen.dart';
import '../../construction_library/presentation/construction_editor_sheet.dart';
import '../../house_scheme/presentation/floor_plan_geometry.dart';
import '../../house_scheme/presentation/house_scheme_screen.dart';

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
  ConsumerState<RoomEditorStepScreen> createState() => _RoomEditorStepScreenState();
}

class _RoomEditorStepScreenState extends ConsumerState<RoomEditorStepScreen> {
  String? _selectedRoomId;

  String? _effectiveSelectedRoomId(Project project) {
    final rooms = project.houseModel.rooms;
    if (rooms.isEmpty) return null;
    final selected = _selectedRoomId;
    if (selected != null && rooms.any((room) => room.id == selected)) {
      return selected;
    }
    return rooms.first.id;
  }

  Future<void> _openRoomSidebar(Project project, BuildingHeatLossResult? heatLoss) async {
    final selectedRoomId = _effectiveSelectedRoomId(project);
    await showGeneralDialog<void>(
      context: context,
      barrierLabel: 'Помещения',
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.22),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _RoomSidebarDialog(
          project: project,
          heatLoss: heatLoss,
          selectedRoomId: selectedRoomId,
          onSelectRoom: (roomId) {
            setState(() => _selectedRoomId = roomId);
            Navigator.of(context).pop();
          },
          onAddRoom: () async {
            Navigator.of(context).pop();
            await _handleAddRoom(project);
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final offset = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        );
        return SlideTransition(position: offset, child: child);
      },
    );
  }

  Future<void> _handleAddRoom(Project project) async {
    final messenger = ScaffoldMessenger.of(context);
    final room = await showRoomEditorSheet(
      context,
      initialLayout: buildNextRoomLayout(project.houseModel.rooms),
    );
    if (!mounted || room == null) return;
    try {
      await ref.read(projectEditorProvider).addRoom(room);
      setState(() => _selectedRoomId = room.id);
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('Не удалось добавить помещение: $error')));
    }
  }

  Future<void> _handleEditRoom(Room room) async {
    final messenger = ScaffoldMessenger.of(context);
    final updated = await showRoomEditorSheet(context, room: room);
    if (!mounted || updated == null) return;
    try {
      await ref.read(projectEditorProvider).updateRoom(updated);
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('Не удалось обновить помещение: $error')));
    }
  }

  Future<void> _handleDeleteRoom(Room room) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(projectEditorProvider).deleteRoom(room.id);
      if (_selectedRoomId == room.id) {
        setState(() => _selectedRoomId = null);
      }
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('Не удалось удалить помещение: $error')));
    }
  }

  Future<void> _updateRoomValue(Room room, Room updatedRoom) async {
    if (room == updatedRoom) return;
    try {
      await ref.read(projectEditorProvider).updateRoom(updatedRoom);
    } catch (_) {}
  }

  Future<void> _handleAddElement(Project project, CatalogSnapshot catalog, Room room) async {
    final messenger = ScaffoldMessenger.of(context);
    final element = await showElementEditorSheet(
      context,
      project: project,
      catalog: catalog,
      roomId: room.id,
    );
    if (!mounted || element == null) return;
    try {
      await ref.read(projectEditorProvider).addEnvelopeElement(element);
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('Не удалось добавить ограждение: $error')));
    }
  }

  Future<void> _handleEditElement(Project project, CatalogSnapshot catalog, HouseEnvelopeElement element) async {
    final messenger = ScaffoldMessenger.of(context);
    final updated = await showElementEditorSheet(
      context,
      project: project,
      catalog: catalog,
      roomId: element.roomId,
      element: element,
    );
    if (!mounted || updated == null) return;
    try {
      await ref.read(projectEditorProvider).updateEnvelopeElement(updated);
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('Не удалось обновить ограждение: $error')));
    }
  }

  Future<void> _handleDeleteElement(HouseEnvelopeElement element) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(projectEditorProvider).deleteEnvelopeElement(element.id);
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('Не удалось удалить ограждение: $error')));
    }
  }

  Future<void> _handleAddOpening(HouseEnvelopeElement element) async {
    final messenger = ScaffoldMessenger.of(context);
    final opening = await showOpeningEditorSheet(context, elementId: element.id);
    if (!mounted || opening == null) return;
    try {
      await ref.read(projectEditorProvider).addOpening(opening);
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('Не удалось добавить проём: $error')));
    }
  }

  Future<void> _handleEditOpening(EnvelopeOpening opening) async {
    final messenger = ScaffoldMessenger.of(context);
    final updated = await showOpeningEditorSheet(context, elementId: opening.elementId, opening: opening);
    if (!mounted || updated == null) return;
    try {
      await ref.read(projectEditorProvider).updateOpening(updated);
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('Не удалось обновить проём: $error')));
    }
  }

  Future<void> _handleDeleteOpening(EnvelopeOpening opening) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(projectEditorProvider).deleteOpening(opening.id);
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('Не удалось удалить проём: $error')));
    }
  }

  Future<void> _handleEditElementConstruction(CatalogSnapshot catalog, List<MaterialCatalogEntry> materialEntries, HouseEnvelopeElement element) async {
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
    if (!mounted || updatedConstruction == null) return;
    try {
      await ref.read(projectEditorProvider).updateEnvelopeElement(
            element.copyWith(
              construction: updatedConstruction,
              elementKind: updatedConstruction.elementKind,
            ),
          );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('Не удалось обновить конструкцию: $error')));
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
        title: Text(
          widget.screenTitle,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          projectAsync.when(
            data: (project) => project == null
                ? const SizedBox.shrink()
                : TextButton.icon(
                    key: const ValueKey('room-sidebar-toggle'),
                    onPressed: () =>
                        _openRoomSidebar(project, heatLossAsync.asData?.value),
                    icon: const Icon(Icons.menu),
                    label: const Text('Помещения'),
                  ),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          const SizedBox(width: 8),
        ],
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
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              _StatusCard(text: widget.statusText),
              const SizedBox(height: 16),
              _StepOverviewCard(
                project: project,
                heatLoss: heatLossAsync.asData?.value,
                previousStepLabel: widget.previousStepLabel,
                onOpenPreviousStep: widget.onOpenPreviousStep,
                onOpenBuildingHeatLoss: _openBuildingHeatLoss,
              ),
              const SizedBox(height: 16),
              if (selectedRoom == null)
                _EmptyRoomState(onAddRoom: () => _handleAddRoom(project))
              else
                catalogAsync.when(
                  data: (catalog) => materialEntriesAsync.when(
                    data: (materialEntries) => _RoomEditorCard(
                      key: ValueKey('room-editor-${selectedRoom.id}'),
                      room: selectedRoom,
                      project: project,
                      heatLoss: heatLossAsync.asData?.value,
                      onEditRoom: () => _handleEditRoom(selectedRoom),
                      onDeleteRoom: () => _handleDeleteRoom(selectedRoom),
                      onComfortChanged: (value) => _updateRoomValue(
                        selectedRoom,
                        selectedRoom.copyWith(comfortTemperatureC: value),
                      ),
                      onVentilationChanged: (value) => _updateRoomValue(
                        selectedRoom,
                        selectedRoom.copyWith(ventilationSupplyM3h: value),
                      ),
                      onAddElement: () =>
                          _handleAddElement(project, catalog, selectedRoom),
                      onEditElement: (element) =>
                          _handleEditElement(project, catalog, element),
                      onDeleteElement: _handleDeleteElement,
                      onAddOpening: _handleAddOpening,
                      onEditOpening: _handleEditOpening,
                      onDeleteOpening: _handleDeleteOpening,
                      onEditConstruction: (element) =>
                          _handleEditElementConstruction(
                        catalog,
                        materialEntries,
                        element,
                      ),
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (error, _) => Text('Ошибка материалов: $error'),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (error, _) => Text('Ошибка каталога: $error'),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Ошибка проекта: $error')),
      ),
    );
  }
}

class _RoomEditorCard extends StatelessWidget {
  const _RoomEditorCard({
    super.key,
    required this.room,
    required this.project,
    required this.heatLoss,
    required this.onEditRoom,
    required this.onDeleteRoom,
    required this.onComfortChanged,
    required this.onVentilationChanged,
    required this.onAddElement,
    required this.onEditElement,
    required this.onDeleteElement,
    required this.onAddOpening,
    required this.onEditOpening,
    required this.onDeleteOpening,
    required this.onEditConstruction,
  });

  final Room room;
  final Project project;
  final BuildingHeatLossResult? heatLoss;
  final VoidCallback onEditRoom;
  final VoidCallback onDeleteRoom;
  final ValueChanged<double> onComfortChanged;
  final ValueChanged<double> onVentilationChanged;
  final VoidCallback onAddElement;
  final ValueChanged<HouseEnvelopeElement> onEditElement;
  final ValueChanged<HouseEnvelopeElement> onDeleteElement;
  final ValueChanged<HouseEnvelopeElement> onAddOpening;
  final ValueChanged<EnvelopeOpening> onEditOpening;
  final ValueChanged<EnvelopeOpening> onDeleteOpening;
  final ValueChanged<HouseEnvelopeElement> onEditConstruction;

  @override
  Widget build(BuildContext context) {
    final roomResult = _findRoomResult(heatLoss, room.id);
    final roomElements = project.houseModel.elements.where((element) => element.roomId == room.id).toList(growable: false);
    final openingsByElementId = <String, List<EnvelopeOpening>>{};
    for (final opening in project.houseModel.openings) {
      openingsByElementId.putIfAbsent(opening.elementId, () => []).add(opening);
    }
    final elementResultById = {
      for (final item in roomResult?.elementResults ?? const <BuildingElementHeatLossResult>[]) item.element.id: item,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
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
                      Text(room.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text('${room.kind.label} • ${room.areaSquareMeters.toStringAsFixed(1)} м² • h ${room.heightMeters.toStringAsFixed(1)} м'),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      onEditRoom();
                    } else if (value == 'delete') {
                      onDeleteRoom();
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Редактировать помещение')),
                    PopupMenuItem(value: 'delete', child: Text('Удалить помещение')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            _MetricTile(
              label: 'Суммарные потери помещения',
              value: roomResult == null ? '—' : '${roomResult.heatLossWatts.toStringAsFixed(0)} Вт',
            ),
            const SizedBox(height: 20),
            Text('Расчётные температуры, °C', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text('Для помещения используется только режим «Комфорт».'),
            const SizedBox(height: 12),
            TextFormField(
              key: ValueKey('comfort-${room.id}-${room.comfortTemperatureC}'),
              initialValue: room.comfortTemperatureC.toStringAsFixed(0),
              decoration: const InputDecoration(labelText: 'Воздух в помещении в режиме “Комфорт”'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (value) {
                final parsed = _tryParseDouble(value);
                if (parsed != null && parsed != room.comfortTemperatureC) {
                  onComfortChanged(parsed);
                }
              },
            ),
            const SizedBox(height: 24),
            Text('Вентиляция (Проветривание)', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text('Укажите приток воздуха, чтобы получить теплопотери на нагрев воздуха.'),
            const SizedBox(height: 12),
            TextFormField(
              key: ValueKey('ventilation-${room.id}-${room.ventilationSupplyM3h}'),
              initialValue: room.ventilationSupplyM3h.toStringAsFixed(0),
              decoration: const InputDecoration(labelText: 'Приток, м³/ч'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (value) {
                final parsed = _tryParseDouble(value);
                if (parsed != null && parsed != room.ventilationSupplyM3h) {
                  onVentilationChanged(parsed);
                }
              },
            ),
            const SizedBox(height: 8),
            Text(
              roomResult == null ? 'Потери на вентиляцию: —' : '${roomResult.ventilationHeatLossWatts.toStringAsFixed(0)} Вт требуется на нагрев',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text('Ограждающие конструкции', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                ),
                FilledButton.tonal(onPressed: onAddElement, child: const Text('Добавить')),
              ],
            ),
            const SizedBox(height: 12),
            if (roomElements.isEmpty)
              const Text('Ограждающие конструкции пока не добавлены.')
            else
              ...roomElements.map((element) {
                final openings = openingsByElementId[element.id] ?? const <EnvelopeOpening>[];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _EnvelopeCard(
                    element: element,
                    elementResult: elementResultById[element.id],
                    openings: openings,
                    onEditElement: () => onEditElement(element),
                    onDeleteElement: () => onDeleteElement(element),
                    onAddOpening: () => onAddOpening(element),
                    onEditOpening: onEditOpening,
                    onDeleteOpening: onDeleteOpening,
                    onEditConstruction: () => onEditConstruction(element),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _EnvelopeCard extends StatefulWidget {
  const _EnvelopeCard({
    required this.element,
    required this.elementResult,
    required this.openings,
    required this.onEditElement,
    required this.onDeleteElement,
    required this.onAddOpening,
    required this.onEditOpening,
    required this.onDeleteOpening,
    required this.onEditConstruction,
  });

  final HouseEnvelopeElement element;
  final BuildingElementHeatLossResult? elementResult;
  final List<EnvelopeOpening> openings;
  final VoidCallback onEditElement;
  final VoidCallback onDeleteElement;
  final VoidCallback onAddOpening;
  final ValueChanged<EnvelopeOpening> onEditOpening;
  final ValueChanged<EnvelopeOpening> onDeleteOpening;
  final VoidCallback onEditConstruction;

  @override
  State<_EnvelopeCard> createState() => _EnvelopeCardState();
}

class _EnvelopeCardState extends State<_EnvelopeCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final openingArea = widget.openings.fold<double>(0, (sum, item) => sum + item.areaSquareMeters);
    final opaqueArea = (widget.element.areaSquareMeters - openingArea).clamp(0.0, widget.element.areaSquareMeters);
    final heatLossLabel = widget.elementResult == null ? '—' : '${widget.elementResult!.totalHeatLossWatts.toStringAsFixed(0)} Вт';
    final title = widget.element.sourceConstructionTitle ?? widget.element.construction.title;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        color: const Color(0xFFF9F7F2),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${widget.element.title} ($heatLossLabel)', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text('${widget.element.elementKind.label} • $title'),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        widget.onEditElement();
                      } else if (value == 'construction') {
                        widget.onEditConstruction();
                      } else if (value == 'opening') {
                        widget.onAddOpening();
                      } else if (value == 'delete') {
                        widget.onDeleteElement();
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'construction', child: Text('Редактировать конструкцию')),
                      PopupMenuItem(value: 'edit', child: Text('Редактировать ограждение')),
                      PopupMenuItem(value: 'opening', child: Text('Добавить проём')),
                      PopupMenuItem(value: 'delete', child: Text('Удалить')),
                    ],
                  ),
                  IconButton(
                    key: ValueKey('step2-envelope-toggle-${widget.element.id}'),
                    tooltip: _expanded ? 'Свернуть' : 'Развернуть',
                    onPressed: () => setState(() => _expanded = !_expanded),
                    icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailLine(label: 'Конструкция', value: widget.element.construction.title),
                  _DetailLine(
                    label: 'Площадь',
                    value: 'валовая ${widget.element.areaSquareMeters.toStringAsFixed(1)} м² • чистая ${opaqueArea.toStringAsFixed(1)} м²',
                  ),
                  _DetailLine(
                    label: 'Проёмы',
                    value: '${widget.openings.length} шт. • ${openingArea.toStringAsFixed(1)} м²',
                  ),
                  _DetailLine(
                    label: 'Теплопотери',
                    value: widget.elementResult == null
                        ? 'Расчёт недоступен'
                        : '${widget.elementResult!.opaqueHeatLossWatts.toStringAsFixed(0)} Вт через ограждение • ${widget.elementResult!.openingHeatLossWatts.toStringAsFixed(0)} Вт через проёмы',
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonal(onPressed: widget.onEditConstruction, child: const Text('Редактировать конструкцию')),
                  const SizedBox(height: 12),
                  if (widget.openings.isEmpty)
                    const Text('Проёмы не добавлены.')
                  else
                    ...widget.openings.map(
                      (opening) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          tileColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          title: Text(opening.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text('${opening.kind.label} • ${opening.areaSquareMeters.toStringAsFixed(1)} м² • U ${opening.heatTransferCoefficient.toStringAsFixed(2)}'),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') {
                                widget.onEditOpening(opening);
                              } else if (value == 'delete') {
                                widget.onDeleteOpening(opening);
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(value: 'edit', child: Text('Редактировать')),
                              PopupMenuItem(value: 'delete', child: Text('Удалить')),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyMedium,
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w700)),
            TextSpan(text: value),
          ],
        ),
      ),
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
      width: 168,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(label),
        ],
      ),
    );
  }
}

class _RoomSidebarDialog extends StatelessWidget {
  const _RoomSidebarDialog({
    required this.project,
    required this.heatLoss,
    required this.selectedRoomId,
    required this.onSelectRoom,
    required this.onAddRoom,
  });

  final Project project;
  final BuildingHeatLossResult? heatLoss;
  final String? selectedRoomId;
  final ValueChanged<String> onSelectRoom;
  final VoidCallback onAddRoom;

  @override
  Widget build(BuildContext context) {
    final roomResults = {
      for (final item in heatLoss?.roomResults ?? const <BuildingRoomHeatLossResult>[]) item.room.id: item,
    };
    final constructionUsage = <String, int>{};
    for (final element in project.houseModel.elements) {
      final key = element.sourceConstructionTitle ?? element.sourceConstructionId ?? element.construction.title;
      constructionUsage[key] = (constructionUsage[key] ?? 0) + 1;
    }

    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Colors.white,
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(28)),
        child: SizedBox(
          width: 360,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Помещения', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(
                    heatLoss == null
                        ? '${project.houseModel.rooms.length} помещений'
                        : '${heatLoss!.totalRoomCount} помещений • ${heatLoss!.totalHeatLossWatts.toStringAsFixed(0)} Вт',
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonal(onPressed: onAddRoom, child: const Text('Добавить помещение')),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView(
                      children: [
                        ...project.houseModel.rooms.map((room) {
                          final roomResult = roomResults[room.id];
                          final elementCount = project.houseModel.elements.where((element) => element.roomId == room.id).length;
                          final isSelected = room.id == selectedRoomId;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: InkWell(
                              key: ValueKey('room-sidebar-room-${room.id}'),
                              onTap: () => onSelectRoom(room.id),
                              borderRadius: BorderRadius.circular(18),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  color: isSelected ? const Color(0xFFF1E8D6) : const Color(0xFFF9F7F2),
                                  border: Border.all(
                                    color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(room.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 4),
                                    Text('${room.kind.label} • ${room.areaSquareMeters.toStringAsFixed(1)} м²'),
                                    Text('Ограждения: $elementCount • Потери: ${roomResult?.heatLossWatts.toStringAsFixed(0) ?? '—'} Вт'),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                        if (constructionUsage.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text('Конструкции дома', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          ...constructionUsage.entries.map(
                            (entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text('${entry.key} • ${entry.value} огражд.'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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

class _StepOverviewCard extends StatelessWidget {
  const _StepOverviewCard({
    required this.project,
    required this.heatLoss,
    required this.previousStepLabel,
    required this.onOpenPreviousStep,
    required this.onOpenBuildingHeatLoss,
  });

  final Project project;
  final BuildingHeatLossResult? heatLoss;
  final String? previousStepLabel;
  final VoidCallback? onOpenPreviousStep;
  final VoidCallback onOpenBuildingHeatLoss;

  @override
  Widget build(BuildContext context) {
    final summary = heatLoss;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Помещения дома',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text('Проект: ${project.name}'),
            Text(
              summary == null
                  ? '${project.houseModel.rooms.length} пом.'
                  : '${summary.totalRoomCount} пом. • '
                      '${summary.totalElementCount} огражд. • '
                      '${summary.totalHeatLossWatts.toStringAsFixed(0)} Вт',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _MetricTile(
                  label: 'Суммарные потери',
                  value: summary == null
                      ? '—'
                      : '${summary.totalHeatLossWatts.toStringAsFixed(0)} Вт',
                ),
                _MetricTile(
                  label: 'Через вентиляцию',
                  value: summary == null
                      ? '—'
                      : '${summary.totalVentilationHeatLossWatts.toStringAsFixed(0)} Вт',
                ),
                _MetricTile(
                  label: 'Площадь помещений',
                  value:
                      '${project.houseModel.totalRoomAreaSquareMeters.toStringAsFixed(1)} м²',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (onOpenPreviousStep != null && previousStepLabel != null)
                  FilledButton.tonalIcon(
                    onPressed: onOpenPreviousStep,
                    icon: const Icon(Icons.looks_one_outlined),
                    label: Text(previousStepLabel!),
                  ),
                FilledButton.icon(
                  onPressed: onOpenBuildingHeatLoss,
                  icon: const Icon(Icons.home_work_outlined),
                  label: const Text('Теплопотери здания'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyRoomState extends StatelessWidget {
  const _EmptyRoomState({required this.onAddRoom});

  final VoidCallback onAddRoom;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Помещения не добавлены',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Добавьте помещение и затем задайте его режим, вентиляцию и ограждающие конструкции.',
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: onAddRoom,
              child: const Text('Добавить помещение'),
            ),
          ],
        ),
      ),
    );
  }
}

BuildingRoomHeatLossResult? _findRoomResult(BuildingHeatLossResult? heatLoss, String roomId) {
  if (heatLoss == null) return null;
  for (final result in heatLoss.roomResults) {
    if (result.room.id == roomId) return result;
  }
  return null;
}

double? _tryParseDouble(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) return null;
  return double.tryParse(normalized.replaceAll(',', '.'));
}
