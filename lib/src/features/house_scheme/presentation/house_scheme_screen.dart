import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/building_heat_loss.dart';
import '../../../core/models/catalog.dart';
import '../../../core/models/project.dart';
import '../../../core/providers.dart';
import '../../construction_library/presentation/construction_editor_sheet.dart';
import '../../building_heat_loss/presentation/building_heat_loss_screen.dart';
import 'house_scheme_editor_helpers.dart' as editor_helpers;
import 'room_wizard_screen.dart';
import 'widgets/floor_plan_editor_card.dart';
import 'widgets/heating_devices_card.dart';
import '../../room_detail/presentation/room_detail_screen.dart';
import '../../thermocalc/presentation/thermocalc_screen.dart';

class HouseSchemeScreen extends ConsumerStatefulWidget {
  const HouseSchemeScreen({
    super.key,
    this.screenTitle = 'Планировка дома',
    this.statusText,
    this.limitToSelectedConstructions = false,
    this.showConstructionsCard = true,
    this.showHeatingDevices = true,
    this.trailingHeader,
    this.constructorCardTitle = 'План дома',
    this.constructorCardCollapsedByDefault = false,
    this.onOpenPreviousStep,
    this.previousStepLabel,
    this.showFloorPlanEditor = true,
    this.showRoomSelectionSidebar = false,
  });

  final String screenTitle;
  final String? statusText;
  final bool limitToSelectedConstructions;
  final bool showConstructionsCard;
  final bool showHeatingDevices;
  final Widget? trailingHeader;
  final String constructorCardTitle;
  final bool constructorCardCollapsedByDefault;
  final VoidCallback? onOpenPreviousStep;
  final String? previousStepLabel;
  final bool showFloorPlanEditor;
  final bool showRoomSelectionSidebar;

  @override
  ConsumerState<HouseSchemeScreen> createState() => _HouseSchemeScreenState();
}

class _HouseSchemeScreenState extends ConsumerState<HouseSchemeScreen> {
  String? _selectedRoomId;
  String? _selectedElementId;
  String? _lastAutoOnboardingProjectId;
  bool _onboardingDialogVisible = false;

  String? _effectiveSelectedRoomId(Project project) {
    final rooms = project.houseModel.rooms;
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

  Future<void> _openRoomSidebar(Project project) async {
    final selectedRoomId = _effectiveSelectedRoomId(project);
    final selectedRoom = selectedRoomId == null
        ? null
        : project.houseModel.rooms.firstWhere(
            (room) => room.id == selectedRoomId,
          );
    await showGeneralDialog<void>(
      context: context,
      barrierLabel: 'Помещения',
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.22),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _RoomSelectionSidebarDialog(
          project: project,
          selectedRoomId: selectedRoomId,
          selectedRoom: selectedRoom,
          onSelectRoom: (roomId) {
            _selectRoom(roomId);
            Navigator.of(context).pop();
          },
          onAddRoom: () {
            Navigator.of(context).pop();
            _handleAddRoom(context, ref, project);
          },
          onOpenEnvelopeEditor: () {
            Navigator.of(context).pop();
            widget.onOpenPreviousStep?.call();
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final offsetAnimation =
            Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );
        return SlideTransition(position: offsetAnimation, child: child);
      },
    );
  }

  Future<void> _showRoomsOnboardingDialog(
    Project project, {
    required bool automatic,
  }) async {
    if (_onboardingDialogVisible) {
      return;
    }
    _onboardingDialogVisible = true;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          key: const ValueKey('building-step-rooms-onboarding-dialog'),
          title: const Text('Как открыть помещения'),
          content: const Text(
            'Кнопка «Помещения» в верхней строке открывает меню выбора помещений. '
            'Из этого меню можно быстро переключаться между комнатами, добавлять новое помещение '
            'и переходить в редактор ограждений на шаге 1.\n\n'
            'Полноэкранная сторис по этому экрану будет добавлена после финальной сборки страницы.',
          ),
          actions: [
            if (project.showBuildingStepRoomsOnboarding)
              TextButton(
                key: const ValueKey('rooms-onboarding-dismiss-forever'),
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  await ref
                      .read(projectEditorProvider)
                      .setBuildingStepRoomsOnboardingEnabled(false);
                },
                child: const Text('Больше не показывать'),
              ),
            FilledButton(
              key: const ValueKey('rooms-onboarding-close'),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(automatic ? 'Понятно' : 'Закрыть'),
            ),
          ],
        );
      },
    );
    _onboardingDialogVisible = false;
  }

  void _maybeShowAutomaticOnboarding(Project project) {
    if (!widget.showRoomSelectionSidebar ||
        !project.showBuildingStepRoomsOnboarding ||
        _lastAutoOnboardingProjectId == project.id ||
        _onboardingDialogVisible) {
      return;
    }
    _lastAutoOnboardingProjectId = project.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _showRoomsOnboardingDialog(project, automatic: true);
    });
  }

  Future<void> _handleAddRoom(
    BuildContext context,
    WidgetRef ref,
    Project project,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final catalog = await ref.read(catalogSnapshotProvider.future);
      if (!context.mounted) {
        return;
      }
      await showRoomWizard(context, project, catalog);
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

  Future<String?> _handleUpdateElementWallPlacement(
    BuildContext context,
    WidgetRef ref,
    HouseEnvelopeElement element,
    EnvelopeWallPlacement wallPlacement,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(projectEditorProvider)
          .updateEnvelopeWallPlacement(element.id, wallPlacement);
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
    final catalog = await ref.read(catalogSnapshotProvider.future);
    if (!context.mounted) {
      return;
    }
    final opening = await _showOpeningEditor(
      context,
      catalog: catalog,
      element: element,
    );
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
    final catalog = await ref.read(catalogSnapshotProvider.future);
    if (!context.mounted) {
      return;
    }
    final project = await ref.read(selectedProjectProvider.future);
    if (!context.mounted || project == null) {
      return;
    }
    final element = project.houseModel.elements.firstWhere(
      (item) => item.id == opening.elementId,
    );
    final updated = await _showOpeningEditor(
      context,
      catalog: catalog,
      element: element,
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
  Widget build(BuildContext context) {
    final projectAsync = ref.watch(selectedProjectProvider);
    final catalogAsync = ref.watch(catalogSnapshotProvider);
    final summaryAsync = ref.watch(buildingHeatLossResultProvider);
    final selectedProject = projectAsync.asData?.value;

    if (selectedProject != null) {
      _maybeShowAutomaticOnboarding(selectedProject);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.screenTitle,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (widget.showRoomSelectionSidebar && selectedProject != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: TextButton.icon(
                key: const ValueKey('room-sidebar-toggle'),
                onPressed: () => _openRoomSidebar(selectedProject),
                icon: const Icon(Icons.menu),
                label: const Text('Помещения'),
              ),
            ),
            IconButton(
              key: const ValueKey('building-step-help-button'),
              tooltip: 'Как пользоваться шагом 2',
              onPressed: () =>
                  _showRoomsOnboardingDialog(selectedProject, automatic: false),
              icon: const Icon(Icons.info_outline),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          _StatusCard(
            text:
                widget.statusText ??
                'После выбора ограждающих конструкций задайте план дома: помещения, ограждения, окна и двери. Из выбранного ограждения можно открыть расчёт конструкции, а после заполнения схемы перейти к суммарным теплопотерям по зданию.',
          ),
          if (widget.trailingHeader != null) ...[
            const SizedBox(height: 16),
            widget.trailingHeader!,
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
                  title: widget.constructorCardTitle,
                  collapsedByDefault: widget.constructorCardCollapsedByDefault,
                  onOpenPreviousStep: widget.onOpenPreviousStep,
                  previousStepLabel: widget.previousStepLabel,
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
                      selectedRoomId: _effectiveSelectedRoomId(
                        effectiveProject,
                      ),
                      selectedElementId: _selectedElementId,
                      showHeatingDevices: widget.showHeatingDevices,
                      showFloorPlanEditor: widget.showFloorPlanEditor,
                      onAddRoom: () => _handleAddRoom(context, ref, project),
                      onOpenRoomSelectionSidebar:
                          widget.showRoomSelectionSidebar
                          ? () => _openRoomSidebar(project)
                          : null,
                      onOpenEnvelopeEditor: widget.onOpenPreviousStep,
                      onSelectRoom: _selectRoom,
                      onSelectElement: _selectElement,
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
                      onUpdateElementWallPlacement: (element, placement) =>
                          _handleUpdateElementWallPlacement(
                            context,
                            ref,
                            element,
                            placement,
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
                    if (widget.showConstructionsCard) ...[
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
    if (!widget.limitToSelectedConstructions) {
      return project;
    }
    final selectedIds = project.activeSelectedConstructionIds.toSet();
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

class _SummaryCard extends StatefulWidget {
  const _SummaryCard({
    required this.project,
    required this.summary,
    required this.title,
    required this.collapsedByDefault,
    required this.onOpenPreviousStep,
    required this.previousStepLabel,
    required this.onOpenBuildingHeatLoss,
  });

  final Project project;
  final BuildingHeatLossResult summary;
  final String title;
  final bool collapsedByDefault;
  final VoidCallback? onOpenPreviousStep;
  final String? previousStepLabel;
  final VoidCallback onOpenBuildingHeatLoss;

  @override
  State<_SummaryCard> createState() => _SummaryCardState();
}

class _SummaryCardState extends State<_SummaryCard> {
  late bool _collapsed;

  @override
  void initState() {
    super.initState();
    _collapsed = widget.collapsedByDefault;
  }

  @override
  Widget build(BuildContext context) {
    final unresolvedCount = widget.summary.unresolvedElements.length;
    final compactStatus =
        '${widget.summary.totalRoomCount} пом., ${widget.summary.totalElementCount} огражд., '
        '${widget.summary.totalHeatLossWatts.toStringAsFixed(0)} Вт';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => setState(() => _collapsed = !_collapsed),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text('Проект: ${widget.project.name}'),
                        Text(compactStatus),
                      ],
                    ),
                  ),
                  Icon(
                    _collapsed ? Icons.expand_more : Icons.expand_less,
                    semanticLabel: _collapsed ? 'Развернуть' : 'Свернуть',
                  ),
                ],
              ),
            ),
            if (!_collapsed) ...[
              const SizedBox(height: 8),
              Text(
                'Режим помещения для норм: ${widget.project.roomPreset.label}',
              ),
              Text(
                'Расчетная наружная температура: '
                '${widget.summary.outsideAirTemperature.toStringAsFixed(0)} °C',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _MetricTile(
                    label: 'Помещения',
                    value: '${widget.summary.totalRoomCount}',
                  ),
                  _MetricTile(
                    label: 'Ограждения',
                    value: '${widget.summary.totalElementCount}',
                  ),
                  _MetricTile(
                    label: 'Конструкции',
                    value: '${widget.project.constructions.length}',
                  ),
                  _MetricTile(
                    label: 'Площадь помещений',
                    value:
                        '${widget.summary.totalRoomAreaSquareMeters.toStringAsFixed(1)} м²',
                  ),
                  _MetricTile(
                    label: 'Площадь ограждений',
                    value:
                        '${widget.summary.totalEnvelopeAreaSquareMeters.toStringAsFixed(1)} м²',
                  ),
                  _MetricTile(
                    label: 'Проёмы',
                    value:
                        '${widget.summary.totalOpeningCount} / ${widget.summary.totalOpeningAreaSquareMeters.toStringAsFixed(1)} м²',
                  ),
                  _MetricTile(
                    label: 'Чистая площадь',
                    value:
                        '${widget.summary.totalOpaqueAreaSquareMeters.toStringAsFixed(1)} м²',
                  ),
                  _MetricTile(
                    label: 'Суммарные потери',
                    value:
                        '${widget.summary.totalHeatLossWatts.toStringAsFixed(0)} Вт',
                  ),
                  _MetricTile(
                    label: 'Через проёмы',
                    value:
                        '${widget.summary.totalOpeningHeatLossWatts.toStringAsFixed(0)} Вт',
                  ),
                  _MetricTile(label: 'Без расчета', value: '$unresolvedCount'),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  if (widget.onOpenPreviousStep != null &&
                      widget.previousStepLabel != null)
                    FilledButton.tonalIcon(
                      onPressed: widget.onOpenPreviousStep,
                      icon: const Icon(Icons.looks_one_outlined),
                      label: Text(widget.previousStepLabel!),
                    ),
                  FilledButton.icon(
                    onPressed: widget.onOpenBuildingHeatLoss,
                    icon: const Icon(Icons.home_work_outlined),
                    label: const Text('Рассчитать теплопотери здания'),
                  ),
                  if (widget.summary.unresolvedElements.isNotEmpty)
                    Chip(label: Text('Пропущено элементов: $unresolvedCount')),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlanAndRoomsSection extends StatelessWidget {
  const _PlanAndRoomsSection({
    required this.project,
    required this.catalog,
    required this.summary,
    required this.selectedRoomId,
    required this.selectedElementId,
    required this.showHeatingDevices,
    required this.showFloorPlanEditor,
    required this.onAddRoom,
    required this.onSelectRoom,
    required this.onSelectElement,
    required this.onUpdateRoomLayout,
    required this.onEditRoom,
    required this.onDeleteRoom,
    required this.onAddElement,
    required this.onEditElement,
    required this.onUpdateElementWallPlacement,
    required this.onDeleteElement,
    required this.onAddOpening,
    required this.onEditOpening,
    required this.onDeleteOpening,
    required this.onAddHeatingDevice,
    required this.onEditHeatingDevice,
    required this.onDeleteHeatingDevice,
    required this.onOpenThermocalc,
    this.onOpenRoomSelectionSidebar,
    this.onOpenEnvelopeEditor,
  });

  final Project project;
  final CatalogSnapshot catalog;
  final BuildingHeatLossResult? summary;
  final String? selectedRoomId;
  final String? selectedElementId;
  final bool showHeatingDevices;
  final bool showFloorPlanEditor;
  final VoidCallback onAddRoom;
  final ValueChanged<String> onSelectRoom;
  final void Function(String elementId, String roomId) onSelectElement;
  final Future<String?> Function(String roomId, RoomLayoutRect layout)
  onUpdateRoomLayout;
  final ValueChanged<Room> onEditRoom;
  final ValueChanged<Room> onDeleteRoom;
  final ValueChanged<Room> onAddElement;
  final ValueChanged<HouseEnvelopeElement> onEditElement;
  final Future<String?> Function(
    HouseEnvelopeElement element,
    EnvelopeWallPlacement wallPlacement,
  )
  onUpdateElementWallPlacement;
  final ValueChanged<HouseEnvelopeElement> onDeleteElement;
  final ValueChanged<HouseEnvelopeElement> onAddOpening;
  final ValueChanged<EnvelopeOpening> onEditOpening;
  final ValueChanged<EnvelopeOpening> onDeleteOpening;
  final ValueChanged<Room> onAddHeatingDevice;
  final ValueChanged<HeatingDevice> onEditHeatingDevice;
  final ValueChanged<HeatingDevice> onDeleteHeatingDevice;
  final ValueChanged<HouseEnvelopeElement> onOpenThermocalc;
  final VoidCallback? onOpenRoomSelectionSidebar;
  final VoidCallback? onOpenEnvelopeEditor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showFloorPlanEditor) ...[
          FloorPlanEditorCard(
            project: project,
            selectedRoomId: selectedRoomId,
            selectedElementId: selectedElementId,
            onAddRoom: onAddRoom,
            onSelectRoom: onSelectRoom,
            onSelectElement: onSelectElement,
            onUpdateRoomLayout: onUpdateRoomLayout,
            onUpdateElementWallPlacement: onUpdateElementWallPlacement,
          ),
          const SizedBox(height: 16),
        ],
        _RoomsCard(
          project: project,
          selectedRoomId: selectedRoomId,
          onSelectRoom: onSelectRoom,
          onAddRoom: onAddRoom,
          onOpenRoomSelectionSidebar: onOpenRoomSelectionSidebar,
          onOpenEnvelopeEditor: onOpenEnvelopeEditor,
          onEditRoom: onEditRoom,
          onDeleteRoom: onDeleteRoom,
          onAddElement: onAddElement,
          onEditElement: onEditElement,
          onSelectElement: onSelectElement,
          onDeleteElement: onDeleteElement,
          onAddOpening: onAddOpening,
          onEditOpening: onEditOpening,
          onDeleteOpening: onDeleteOpening,
          onOpenThermocalc: onOpenThermocalc,
        ),
        if (showHeatingDevices) ...[
          const SizedBox(height: 16),
          HeatingDevicesCard(
            project: project,
            catalog: catalog,
            summary: summary,
            selectedRoomId: selectedRoomId,
            onSelectRoom: onSelectRoom,
            onAddHeatingDevice: onAddHeatingDevice,
            onEditHeatingDevice: onEditHeatingDevice,
            onDeleteHeatingDevice: onDeleteHeatingDevice,
          ),
        ],
      ],
    );
  }
}

class _RoomSelectionSidebarDialog extends StatelessWidget {
  const _RoomSelectionSidebarDialog({
    required this.project,
    required this.selectedRoomId,
    required this.selectedRoom,
    required this.onSelectRoom,
    required this.onAddRoom,
    required this.onOpenEnvelopeEditor,
  });

  final Project project;
  final String? selectedRoomId;
  final Room? selectedRoom;
  final ValueChanged<String> onSelectRoom;
  final VoidCallback onAddRoom;
  final VoidCallback onOpenEnvelopeEditor;

  @override
  Widget build(BuildContext context) {
    final width = math.min(MediaQuery.sizeOf(context).width * 0.82, 320.0);
    return SafeArea(
      child: Align(
        alignment: Alignment.centerRight,
        child: Material(
          elevation: 12,
          color: const Color(0xFF2F3A68),
          borderRadius: const BorderRadius.horizontal(
            left: Radius.circular(28),
          ),
          child: SizedBox(
            width: width,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Помещения',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    selectedRoom == null
                        ? 'Выберите помещение для работы с ограждениями.'
                        : 'Активно: ${selectedRoom!.title}',
                    style: const TextStyle(color: Color(0xFFD6DBF5)),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: onAddRoom,
                        icon: const Icon(Icons.add),
                        label: const Text('Добавить помещение'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: onOpenEnvelopeEditor,
                        icon: const Icon(Icons.looks_one_outlined),
                        label: const Text('Редактор ограждений'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: project.houseModel.rooms.isEmpty
                        ? const Center(
                            child: Text(
                              'Помещения пока не добавлены.',
                              style: TextStyle(color: Colors.white70),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.separated(
                            itemCount: project.houseModel.rooms.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final room = project.houseModel.rooms[index];
                              final roomElements = project.houseModel.elements
                                  .where((item) => item.roomId == room.id)
                                  .length;
                              final selected = room.id == selectedRoomId;
                              return InkWell(
                                key: ValueKey('room-sidebar-room-${room.id}'),
                                borderRadius: BorderRadius.circular(18),
                                onTap: () => onSelectRoom(room.id),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? const Color(0xFF4B578D)
                                        : const Color(0xFF394574),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: selected
                                          ? const Color(0xFFFF7A6B)
                                          : const Color(0xFF5A679B),
                                      width: selected ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              room.title,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${room.kind.label} • ${room.areaSquareMeters.toStringAsFixed(1)} м²',
                                              style: const TextStyle(
                                                color: Color(0xFFD6DBF5),
                                              ),
                                            ),
                                            Text(
                                              'Ограждений: $roomElements',
                                              style: const TextStyle(
                                                color: Color(0xFFD6DBF5),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (selected)
                                        const Icon(
                                          Icons.check_circle,
                                          color: Color(0xFFFF7A6B),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
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

class _RoomsCard extends StatelessWidget {
  const _RoomsCard({
    required this.project,
    required this.selectedRoomId,
    required this.onSelectRoom,
    required this.onAddRoom,
    this.onOpenRoomSelectionSidebar,
    this.onOpenEnvelopeEditor,
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
  final VoidCallback? onOpenRoomSelectionSidebar;
  final VoidCallback? onOpenEnvelopeEditor;
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
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Детали помещения',
                                    icon: const Icon(Icons.open_in_new),
                                    onPressed: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            RoomDetailScreen(room: room),
                                      ),
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
                              final construction = element.construction;
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
                                child: _RoomEnvelopeElementCard(
                                  key: ValueKey('room-envelope-${element.id}'),
                                  roomId: room.id,
                                  element: element,
                                  constructionTitle:
                                      element.sourceConstructionTitle ??
                                      construction.title,
                                  opaqueArea: opaqueArea,
                                  openings: openings,
                                  openingArea: openingArea,
                                  onSelectElement: onSelectElement,
                                  onEditElement: onEditElement,
                                  onDeleteElement: onDeleteElement,
                                  onAddOpening: onAddOpening,
                                  onEditOpening: onEditOpening,
                                  onDeleteOpening: onDeleteOpening,
                                  onOpenThermocalc: onOpenThermocalc,
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

class _RoomEnvelopeElementCard extends StatefulWidget {
  const _RoomEnvelopeElementCard({
    super.key,
    required this.roomId,
    required this.element,
    required this.constructionTitle,
    required this.opaqueArea,
    required this.openings,
    required this.openingArea,
    required this.onSelectElement,
    required this.onEditElement,
    required this.onDeleteElement,
    required this.onAddOpening,
    required this.onEditOpening,
    required this.onDeleteOpening,
    required this.onOpenThermocalc,
  });

  final String roomId;
  final HouseEnvelopeElement element;
  final String constructionTitle;
  final double opaqueArea;
  final List<EnvelopeOpening> openings;
  final double openingArea;
  final void Function(String elementId, String roomId) onSelectElement;
  final ValueChanged<HouseEnvelopeElement> onEditElement;
  final ValueChanged<HouseEnvelopeElement> onDeleteElement;
  final ValueChanged<HouseEnvelopeElement> onAddOpening;
  final ValueChanged<EnvelopeOpening> onEditOpening;
  final ValueChanged<EnvelopeOpening> onDeleteOpening;
  final ValueChanged<HouseEnvelopeElement> onOpenThermocalc;

  @override
  State<_RoomEnvelopeElementCard> createState() =>
      _RoomEnvelopeElementCardState();
}

class _RoomEnvelopeElementCardState extends State<_RoomEnvelopeElementCard> {
  bool _expanded = false;

  String get _geometryLabel {
    final placement = widget.element.wallPlacement;
    if (widget.element.elementKind == ConstructionElementKind.wall &&
        placement != null) {
      return '${placement.side.label}, сегмент ${placement.lengthMeters.toStringAsFixed(1)} м, '
          'смещение ${placement.offsetMeters.toStringAsFixed(1)} м';
    }
    return 'Без геометрической привязки';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              key: ValueKey('room-envelope-tile-${widget.element.id}'),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 0,
              ),
              onTap: () =>
                  widget.onSelectElement(widget.element.id, widget.roomId),
              title: Text(
                widget.element.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${widget.element.elementKind.label} • валовая площадь ${widget.element.areaSquareMeters.toStringAsFixed(1)} м² • '
                'чистая ${widget.opaqueArea.toStringAsFixed(1)} м²\n'
                'Проёмы: ${widget.openings.length} / ${widget.openingArea.toStringAsFixed(1)} м² • '
                'Конструкция: ${widget.constructionTitle}',
              ),
              isThreeLine: true,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'calc':
                          widget.onOpenThermocalc(widget.element);
                        case 'opening':
                          widget.onAddOpening(widget.element);
                        case 'edit':
                          widget.onEditElement(widget.element);
                        case 'delete':
                          widget.onDeleteElement(widget.element);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'calc', child: Text('Рассчитать')),
                      PopupMenuItem(
                        value: 'opening',
                        child: Text('Добавить проём'),
                      ),
                      PopupMenuItem(
                        value: 'edit',
                        child: Text('Редактировать'),
                      ),
                      PopupMenuItem(value: 'delete', child: Text('Удалить')),
                    ],
                  ),
                  IconButton(
                    key: ValueKey('room-envelope-toggle-${widget.element.id}'),
                    tooltip: _expanded ? 'Свернуть' : 'Развернуть',
                    onPressed: () => setState(() => _expanded = !_expanded),
                    icon: Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                    ),
                  ),
                ],
              ),
            ),
            if (_expanded) ...[
              Padding(
                key: ValueKey('room-envelope-details-${widget.element.id}'),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(_geometryLabel),
              ),
              if (widget.openings.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: Text('Проёмы не добавлены.'),
                )
              else
                ...widget.openings.map(
                  (opening) => Padding(
                    padding: const EdgeInsets.only(
                      left: 12,
                      right: 12,
                      bottom: 8,
                    ),
                    child: ListTile(
                      tileColor: const Color(0xFFF9F7F2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      title: Text(
                        opening.title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${opening.kind.label} • ${opening.areaSquareMeters.toStringAsFixed(1)} м² • '
                        'U ${opening.heatTransferCoefficient.toStringAsFixed(2)} Вт/м²·°C',
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') {
                            widget.onEditOpening(opening);
                          } else if (value == 'delete') {
                            widget.onDeleteOpening(opening);
                          }
                        },
                        itemBuilder: (context) => const [
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
                  ),
                ),
            ],
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
      final sourceId = element.sourceConstructionId ?? element.construction.id;
      usageMap[sourceId] = (usageMap[sourceId] ?? 0) + 1;
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
  final comfortTemperatureController = TextEditingController(
    text: (room?.comfortTemperatureC ?? defaultRoomComfortTemperatureC)
        .toString(),
  );
  final ventilationController = TextEditingController(
    text: (room?.ventilationSupplyM3h ?? defaultRoomVentilationSupplyM3h)
        .toString(),
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
                    labelText: 'Площадь помещения',
                  ),
                  child: Text(
                    '${effectiveLayout.areaSquareMeters.toStringAsFixed(1)} м²',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: heightController,
                  decoration: const InputDecoration(labelText: 'Высота, м'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: comfortTemperatureController,
                  decoration: const InputDecoration(labelText: 'Комфорт, °C'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ventilationController,
                  decoration: const InputDecoration(
                    labelText: 'Приток воздуха, м³/ч',
                  ),
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
                        comfortTemperatureC: _parseDouble(
                          comfortTemperatureController.text,
                          fallback: defaultRoomComfortTemperatureC,
                        ),
                        ventilationSupplyM3h: _parseDouble(
                          ventilationController.text,
                          fallback: defaultRoomVentilationSupplyM3h,
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
  comfortTemperatureController.dispose();
  ventilationController.dispose();
  return result;
}

Future<Room?> showRoomEditorSheet(
  BuildContext context, {
  Room? room,
  RoomLayoutRect? initialLayout,
}) {
  return _showRoomEditor(context, room: room, initialLayout: initialLayout);
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
      element?.sourceConstructionId ??
      element?.construction.id ??
      (project.constructions.isEmpty ? null : project.constructions.first.id);
  var selectedKind =
      element?.construction.elementKind ??
      element?.elementKind ??
      (project.constructions.isEmpty
          ? ConstructionElementKind.wall
          : project.constructions.first.elementKind);
  var selectedOrientation = element?.wallOrientation ?? WallOrientation.north;

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
                if (selectedKind == ConstructionElementKind.wall) ...[
                  TextField(
                    controller: areaController,
                    decoration: const InputDecoration(
                      labelText: 'Площадь стены, м²',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<WallOrientation>(
                    initialValue: selectedOrientation,
                    decoration: const InputDecoration(
                      labelText: 'Ориентация стены',
                    ),
                    items: WallOrientation.values
                        .map(
                          (orientation) => DropdownMenuItem(
                            value: orientation,
                            child: Text(orientation.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => selectedOrientation = value);
                      }
                    },
                  ),
                ] else
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
                              construction: selectedConstruction.copyWith(),
                              sourceConstructionId: selectedConstruction.id,
                              sourceConstructionTitle:
                                  selectedConstruction.title,
                              wallOrientation:
                                  selectedConstruction.elementKind ==
                                      ConstructionElementKind.wall
                                  ? selectedOrientation
                                  : null,
                              wallPlacement: element?.wallPlacement,
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

Future<HouseEnvelopeElement?> showElementEditorSheet(
  BuildContext context, {
  required Project project,
  required CatalogSnapshot catalog,
  required String roomId,
  HouseEnvelopeElement? element,
}) {
  return _showElementEditor(
    context,
    project: project,
    catalog: catalog,
    roomId: roomId,
    element: element,
  );
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
  required CatalogSnapshot catalog,
  required HouseEnvelopeElement element,
  OpeningKind? initialKind,
  EnvelopeOpening? opening,
}) {
  return editor_helpers.showOpeningEditorSheet(
    context,
    catalog: catalog,
    element: element,
    initialKind: initialKind,
    opening: opening,
  );
}

Future<EnvelopeOpening?> showOpeningEditorSheet(
  BuildContext context, {
  required CatalogSnapshot catalog,
  required HouseEnvelopeElement element,
  OpeningKind? initialKind,
  EnvelopeOpening? opening,
}) {
  return _showOpeningEditor(
    context,
    catalog: catalog,
    element: element,
    initialKind: initialKind,
    opening: opening,
  );
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
  return editor_helpers.buildEditorId(prefix);
}

double _parseDouble(String value, {required double fallback}) {
  return editor_helpers.parseEditorDouble(value, fallback: fallback);
}

String _requiredText(String value, {required String fallback}) {
  return editor_helpers.requireEditorText(value, fallback: fallback);
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
