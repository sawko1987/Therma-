import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/building_heat_loss.dart';
import '../../../core/models/catalog.dart';
import '../../../core/models/project.dart';
import '../../../core/providers.dart';
import '../../building_heat_loss/presentation/building_heat_loss_screen.dart';
import '../../construction_library/presentation/construction_editor_sheet.dart';
import '../../thermocalc/presentation/thermocalc_screen.dart';
import 'widgets/heating_devices_card.dart';

const List<ConstructionElementKind> _allowedExteriorKinds = [
  ConstructionElementKind.wall,
  ConstructionElementKind.roof,
  ConstructionElementKind.floor,
  ConstructionElementKind.ceiling,
];

enum _WorkspaceSection { overview, rooms, envelope, heating, constructions }

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
    if (!context.mounted || room == null) {
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
    if (!context.mounted || updated == null) {
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
    try {
      await ref.read(projectEditorProvider).deleteRoom(room.id);
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
    if (!context.mounted || element == null) {
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
    if (!context.mounted || updated == null) {
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
    if (!context.mounted || opening == null) {
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
    if (!context.mounted || updated == null) {
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
    if (!context.mounted || construction == null) {
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
    if (!context.mounted || updated == null) {
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
      body: summaryAsync.when(
        data: (summary) => projectAsync.when(
          data: (project) {
            if (project == null || summary == null) {
              return const Center(child: Text('Активный проект не найден.'));
            }
            final effectiveProject = _resolveProject(project);
            return catalogAsync.when(
              data: (catalog) => _PlanAndRoomsSection(
                statusText:
                    statusText ??
                    'Конструктор дома собирает проект сверху вниз: помещения, ограждения, окна/двери и переиспользуемые конструкции. Выбор разделов теперь выполняется через левую панель.',
                trailingHeader: trailingHeader,
                project: effectiveProject,
                catalog: catalog,
                summary: summary,
                showHeatingDevices: showHeatingDevices,
                showConstructionsCard: showConstructionsCard,
                onOpenBuildingHeatLoss: () =>
                    _handleOpenBuildingHeatLoss(context),
                onAddRoom: () => _handleAddRoom(context, ref, project),
                onEditRoom: (room) => _handleEditRoom(context, ref, room),
                onDeleteRoom: (room) => _handleDeleteRoom(context, ref, room),
                onAddElement: (room) =>
                    _handleAddElement(context, ref, project, catalog, room),
                onEditElement: (element) =>
                    _handleEditElement(context, ref, project, catalog, element),
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
                    _handleDeleteHeatingDevice(context, ref, heatingDevice),
                onAddConstruction: () =>
                    _handleAddConstruction(context, ref, catalog),
                onEditConstruction: (construction) => _handleEditConstruction(
                  context,
                  ref,
                  catalog,
                  construction,
                ),
                onDeleteConstruction: (construction) =>
                    _handleDeleteConstruction(context, ref, construction),
                onOpenThermocalc: (element) =>
                    _handleOpenThermocalc(context, ref, element),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('Ошибка каталога: $error')),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Ошибка проекта: $error')),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Ошибка сводки: $error')),
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
                  label: 'Площадь',
                  value:
                      '${summary.totalRoomAreaSquareMeters.toStringAsFixed(1)} м²',
                ),
                _MetricTile(
                  label: 'Потери',
                  value: '${summary.totalHeatLossWatts.toStringAsFixed(0)} Вт',
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onOpenBuildingHeatLoss,
              icon: const Icon(Icons.home_work_outlined),
              label: const Text('Открыть расчет потерь'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanAndRoomsSection extends StatefulWidget {
  const _PlanAndRoomsSection({
    required this.statusText,
    required this.trailingHeader,
    required this.project,
    required this.catalog,
    required this.summary,
    required this.showHeatingDevices,
    required this.showConstructionsCard,
    required this.onOpenBuildingHeatLoss,
    required this.onAddRoom,
    required this.onEditRoom,
    required this.onDeleteRoom,
    required this.onAddElement,
    required this.onEditElement,
    required this.onDeleteElement,
    required this.onAddOpening,
    required this.onEditOpening,
    required this.onDeleteOpening,
    required this.onAddHeatingDevice,
    required this.onEditHeatingDevice,
    required this.onDeleteHeatingDevice,
    required this.onAddConstruction,
    required this.onEditConstruction,
    required this.onDeleteConstruction,
    required this.onOpenThermocalc,
  });

  final String statusText;
  final Widget? trailingHeader;
  final Project project;
  final CatalogSnapshot catalog;
  final BuildingHeatLossResult summary;
  final bool showHeatingDevices;
  final bool showConstructionsCard;
  final VoidCallback onOpenBuildingHeatLoss;
  final VoidCallback onAddRoom;
  final ValueChanged<Room> onEditRoom;
  final ValueChanged<Room> onDeleteRoom;
  final ValueChanged<Room> onAddElement;
  final ValueChanged<HouseEnvelopeElement> onEditElement;
  final ValueChanged<HouseEnvelopeElement> onDeleteElement;
  final ValueChanged<HouseEnvelopeElement> onAddOpening;
  final ValueChanged<EnvelopeOpening> onEditOpening;
  final ValueChanged<EnvelopeOpening> onDeleteOpening;
  final ValueChanged<Room> onAddHeatingDevice;
  final ValueChanged<HeatingDevice> onEditHeatingDevice;
  final ValueChanged<HeatingDevice> onDeleteHeatingDevice;
  final VoidCallback onAddConstruction;
  final ValueChanged<Construction> onEditConstruction;
  final ValueChanged<Construction> onDeleteConstruction;
  final ValueChanged<HouseEnvelopeElement> onOpenThermocalc;

  @override
  State<_PlanAndRoomsSection> createState() => _PlanAndRoomsSectionState();
}

class _PlanAndRoomsSectionState extends State<_PlanAndRoomsSection> {
  final ScrollController _scrollController = ScrollController();
  final Map<_WorkspaceSection, GlobalKey> _sectionKeys = {
    for (final section in _WorkspaceSection.values) section: GlobalKey(),
  };

  final Map<_WorkspaceSection, bool> _expandedSections = {
    _WorkspaceSection.overview: true,
    _WorkspaceSection.rooms: true,
    _WorkspaceSection.envelope: true,
    _WorkspaceSection.heating: true,
    _WorkspaceSection.constructions: true,
  };

  _WorkspaceSection _selectedSection = _WorkspaceSection.overview;
  String? _selectedRoomId;

  bool _menuOverviewExpanded = true;
  bool _menuRoomsExpanded = true;
  bool _menuEnvelopeExpanded = true;
  bool _menuHeatingExpanded = true;
  bool _menuConstructionsExpanded = true;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String? get _effectiveSelectedRoomId {
    final rooms = widget.project.houseModel.rooms;
    if (rooms.isEmpty) {
      return null;
    }
    final selectedRoomId = _selectedRoomId;
    final exists = rooms.any((room) => room.id == selectedRoomId);
    return exists ? selectedRoomId : rooms.first.id;
  }

  void _activateSection(
    _WorkspaceSection section, {
    String? roomId,
    bool closeDrawer = false,
  }) {
    setState(() {
      _selectedSection = section;
      _expandedSections[section] = true;
      if (roomId != null) {
        _selectedRoomId = roomId;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sectionContext = _sectionKeys[section]?.currentContext;
      if (sectionContext != null) {
        Scrollable.ensureVisible(
          sectionContext,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
        );
      }
    });
    if (closeDrawer) {
      Navigator.of(context).pop();
    }
  }

  void _toggleSection(_WorkspaceSection section) {
    setState(() {
      _expandedSections[section] = !(_expandedSections[section] ?? true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 1080;
    final sidePanel = _SideNavigationPanel(
      project: widget.project,
      selectedSection: _selectedSection,
      selectedRoomId: _effectiveSelectedRoomId,
      showHeatingSection: widget.showHeatingDevices,
      showConstructionsSection: widget.showConstructionsCard,
      overviewExpanded: _menuOverviewExpanded,
      roomsExpanded: _menuRoomsExpanded,
      envelopeExpanded: _menuEnvelopeExpanded,
      heatingExpanded: _menuHeatingExpanded,
      constructionsExpanded: _menuConstructionsExpanded,
      onToggleOverview: () =>
          setState(() => _menuOverviewExpanded = !_menuOverviewExpanded),
      onToggleRooms: () =>
          setState(() => _menuRoomsExpanded = !_menuRoomsExpanded),
      onToggleEnvelope: () =>
          setState(() => _menuEnvelopeExpanded = !_menuEnvelopeExpanded),
      onToggleHeating: () =>
          setState(() => _menuHeatingExpanded = !_menuHeatingExpanded),
      onToggleConstructions: () => setState(
        () => _menuConstructionsExpanded = !_menuConstructionsExpanded,
      ),
      onSelectSection: (section) =>
          _activateSection(section, closeDrawer: !isWide),
      onSelectRoom: (roomId) => _activateSection(
        _WorkspaceSection.rooms,
        roomId: roomId,
        closeDrawer: !isWide,
      ),
    );

    final content = ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        if (!isWide)
          Builder(
            builder: (context) => Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                key: const ValueKey('open-sections-button'),
                onPressed: () => Scaffold.of(context).openDrawer(),
                icon: const Icon(Icons.menu),
                label: const Text('Разделы'),
              ),
            ),
          ),
        if (!isWide) const SizedBox(height: 12),
        _StatusCard(text: widget.statusText),
        if (widget.trailingHeader != null) ...[
          const SizedBox(height: 12),
          widget.trailingHeader!,
        ],
        const SizedBox(height: 12),
        _MainSectionHeader(
          key: _sectionKeys[_WorkspaceSection.overview],
          title: 'Общие данные',
          selected: _selectedSection == _WorkspaceSection.overview,
          expanded: _expandedSections[_WorkspaceSection.overview] ?? true,
          onSelect: () => _activateSection(_WorkspaceSection.overview),
          onToggle: () => _toggleSection(_WorkspaceSection.overview),
          toggleKey: const ValueKey('main-section-overview-toggle'),
        ),
        if (_expandedSections[_WorkspaceSection.overview] ?? true) ...[
          const SizedBox(height: 8),
          _SummaryCard(
            project: widget.project,
            summary: widget.summary,
            onOpenBuildingHeatLoss: widget.onOpenBuildingHeatLoss,
          ),
        ],
        const SizedBox(height: 12),
        _MainSectionHeader(
          key: _sectionKeys[_WorkspaceSection.rooms],
          title: 'Помещения',
          selected: _selectedSection == _WorkspaceSection.rooms,
          expanded: _expandedSections[_WorkspaceSection.rooms] ?? true,
          onSelect: () => _activateSection(_WorkspaceSection.rooms),
          onToggle: () => _toggleSection(_WorkspaceSection.rooms),
          toggleKey: const ValueKey('main-section-rooms-toggle'),
        ),
        if (_expandedSections[_WorkspaceSection.rooms] ?? true) ...[
          const SizedBox(height: 8),
          _RoomListCard(
            project: widget.project,
            selectedRoomId: _effectiveSelectedRoomId,
            onSelectRoom: (roomId) => setState(() => _selectedRoomId = roomId),
            onAddRoom: widget.onAddRoom,
            onEditRoom: widget.onEditRoom,
            onDeleteRoom: widget.onDeleteRoom,
          ),
        ],
        const SizedBox(height: 12),
        _MainSectionHeader(
          key: _sectionKeys[_WorkspaceSection.envelope],
          title: 'Ограждающие конструкции',
          selected: _selectedSection == _WorkspaceSection.envelope,
          expanded: _expandedSections[_WorkspaceSection.envelope] ?? true,
          onSelect: () => _activateSection(_WorkspaceSection.envelope),
          onToggle: () => _toggleSection(_WorkspaceSection.envelope),
          toggleKey: const ValueKey('main-section-envelope-toggle'),
        ),
        if (_expandedSections[_WorkspaceSection.envelope] ?? true) ...[
          const SizedBox(height: 8),
          _ExteriorEnvelopeCard(
            project: widget.project,
            selectedRoomId: _effectiveSelectedRoomId,
            onSelectRoom: (roomId) => setState(() => _selectedRoomId = roomId),
            onAddElement: widget.onAddElement,
            onEditElement: widget.onEditElement,
            onDeleteElement: widget.onDeleteElement,
            onAddOpening: widget.onAddOpening,
            onEditOpening: widget.onEditOpening,
            onDeleteOpening: widget.onDeleteOpening,
            onOpenThermocalc: widget.onOpenThermocalc,
          ),
        ],
        if (widget.showHeatingDevices) ...[
          const SizedBox(height: 12),
          _MainSectionHeader(
            key: _sectionKeys[_WorkspaceSection.heating],
            title: 'Отопительные приборы',
            selected: _selectedSection == _WorkspaceSection.heating,
            expanded: _expandedSections[_WorkspaceSection.heating] ?? true,
            onSelect: () => _activateSection(_WorkspaceSection.heating),
            onToggle: () => _toggleSection(_WorkspaceSection.heating),
            toggleKey: const ValueKey('main-section-heating-toggle'),
          ),
          if (_expandedSections[_WorkspaceSection.heating] ?? true) ...[
            const SizedBox(height: 8),
            HeatingDevicesCard(
              project: widget.project,
              catalog: widget.catalog,
              summary: widget.summary,
              selectedRoomId: _effectiveSelectedRoomId,
              onSelectRoom: (roomId) =>
                  setState(() => _selectedRoomId = roomId),
              onAddHeatingDevice: widget.onAddHeatingDevice,
              onEditHeatingDevice: widget.onEditHeatingDevice,
              onDeleteHeatingDevice: widget.onDeleteHeatingDevice,
            ),
          ],
        ],
        if (widget.showConstructionsCard) ...[
          const SizedBox(height: 12),
          _MainSectionHeader(
            key: _sectionKeys[_WorkspaceSection.constructions],
            title: 'Конструкции',
            selected: _selectedSection == _WorkspaceSection.constructions,
            expanded:
                _expandedSections[_WorkspaceSection.constructions] ?? true,
            onSelect: () => _activateSection(_WorkspaceSection.constructions),
            onToggle: () => _toggleSection(_WorkspaceSection.constructions),
            toggleKey: const ValueKey('main-section-constructions-toggle'),
          ),
          if (_expandedSections[_WorkspaceSection.constructions] ?? true) ...[
            const SizedBox(height: 8),
            _ConstructionsCard(
              project: widget.project,
              catalog: widget.catalog,
              onAddConstruction: widget.onAddConstruction,
              onEditConstruction: widget.onEditConstruction,
              onDeleteConstruction: widget.onDeleteConstruction,
            ),
          ],
        ],
      ],
    );

    return Scaffold(
      drawer: isWide ? null : Drawer(child: sidePanel),
      body: isWide
          ? Row(
              children: [
                SizedBox(width: 312, child: sidePanel),
                const VerticalDivider(width: 1),
                Expanded(child: content),
              ],
            )
          : content,
    );
  }
}

class _MainSectionHeader extends StatelessWidget {
  const _MainSectionHeader({
    super.key,
    required this.title,
    required this.selected,
    required this.expanded,
    required this.onSelect,
    required this.onToggle,
    required this.toggleKey,
  });

  final String title;
  final bool selected;
  final bool expanded;
  final VoidCallback onSelect;
  final VoidCallback onToggle;
  final Key toggleKey;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outlineVariant,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onSelect,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
          IconButton(
            key: toggleKey,
            onPressed: onToggle,
            icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
          ),
        ],
      ),
    );
  }
}

class _SideNavigationPanel extends StatelessWidget {
  const _SideNavigationPanel({
    required this.project,
    required this.selectedSection,
    required this.selectedRoomId,
    required this.showHeatingSection,
    required this.showConstructionsSection,
    required this.overviewExpanded,
    required this.roomsExpanded,
    required this.envelopeExpanded,
    required this.heatingExpanded,
    required this.constructionsExpanded,
    required this.onToggleOverview,
    required this.onToggleRooms,
    required this.onToggleEnvelope,
    required this.onToggleHeating,
    required this.onToggleConstructions,
    required this.onSelectSection,
    required this.onSelectRoom,
  });

  final Project project;
  final _WorkspaceSection selectedSection;
  final String? selectedRoomId;
  final bool showHeatingSection;
  final bool showConstructionsSection;
  final bool overviewExpanded;
  final bool roomsExpanded;
  final bool envelopeExpanded;
  final bool heatingExpanded;
  final bool constructionsExpanded;
  final VoidCallback onToggleOverview;
  final VoidCallback onToggleRooms;
  final VoidCallback onToggleEnvelope;
  final VoidCallback onToggleHeating;
  final VoidCallback onToggleConstructions;
  final ValueChanged<_WorkspaceSection> onSelectSection;
  final ValueChanged<String> onSelectRoom;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF26315E),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(10, 4, 10, 8),
              child: Text(
                'Навигация по зданию',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            _SideGroup(
              title: 'Общие данные',
              expanded: overviewExpanded,
              onToggle: onToggleOverview,
              toggleKey: const ValueKey('side-group-overview-toggle'),
              children: [
                _SideItem(
                  label: 'Сводка проекта',
                  selected: selectedSection == _WorkspaceSection.overview,
                  onTap: () => onSelectSection(_WorkspaceSection.overview),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _SideGroup(
              title: 'Помещения',
              expanded: roomsExpanded,
              onToggle: onToggleRooms,
              toggleKey: const ValueKey('side-group-rooms-toggle'),
              children: [
                _SideItem(
                  label: 'Список помещений',
                  selected: selectedSection == _WorkspaceSection.rooms,
                  onTap: () => onSelectSection(_WorkspaceSection.rooms),
                ),
                ...project.houseModel.rooms.map(
                  (room) => _SideItem(
                    key: ValueKey('side-room-${room.id}'),
                    label: room.title,
                    selected: selectedRoomId == room.id,
                    level: 1,
                    onTap: () => onSelectRoom(room.id),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _SideGroup(
              title: 'Ограждающие конструкции',
              expanded: envelopeExpanded,
              onToggle: onToggleEnvelope,
              toggleKey: const ValueKey('side-group-envelope-toggle'),
              children: [
                _SideItem(
                  label: 'Список ограждений',
                  selected: selectedSection == _WorkspaceSection.envelope,
                  onTap: () => onSelectSection(_WorkspaceSection.envelope),
                ),
              ],
            ),
            if (showHeatingSection) ...[
              const SizedBox(height: 8),
              _SideGroup(
                title: 'Отопительные приборы',
                expanded: heatingExpanded,
                onToggle: onToggleHeating,
                toggleKey: const ValueKey('side-group-heating-toggle'),
                children: [
                  _SideItem(
                    label: 'Список приборов',
                    selected: selectedSection == _WorkspaceSection.heating,
                    onTap: () => onSelectSection(_WorkspaceSection.heating),
                  ),
                ],
              ),
            ],
            if (showConstructionsSection) ...[
              const SizedBox(height: 8),
              _SideGroup(
                title: 'Конструкции',
                expanded: constructionsExpanded,
                onToggle: onToggleConstructions,
                toggleKey: const ValueKey('side-group-constructions-toggle'),
                children: [
                  _SideItem(
                    label: 'Список конструкций',
                    selected:
                        selectedSection == _WorkspaceSection.constructions,
                    onTap: () =>
                        onSelectSection(_WorkspaceSection.constructions),
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

class _SideGroup extends StatelessWidget {
  const _SideGroup({
    required this.title,
    required this.expanded,
    required this.onToggle,
    required this.toggleKey,
    required this.children,
  });

  final String title;
  final bool expanded;
  final VoidCallback onToggle;
  final Key toggleKey;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF334074),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    key: toggleKey,
                    visualDensity: VisualDensity.compact,
                    onPressed: onToggle,
                    color: Colors.white,
                    icon: Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Column(children: children),
            ),
        ],
      ),
    );
  }
}

class _SideItem extends StatelessWidget {
  const _SideItem({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.level = 0,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int level;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: level * 14.0, bottom: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFE3994A) : const Color(0xFF41508A),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _RoomListCard extends StatelessWidget {
  const _RoomListCard({
    required this.project,
    required this.selectedRoomId,
    required this.onSelectRoom,
    required this.onAddRoom,
    required this.onEditRoom,
    required this.onDeleteRoom,
  });

  final Project project;
  final String? selectedRoomId;
  final ValueChanged<String> onSelectRoom;
  final VoidCallback onAddRoom;
  final ValueChanged<Room> onEditRoom;
  final ValueChanged<Room> onDeleteRoom;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardHeader(
              title: 'Помещения',
              actionLabel: 'Добавить помещение',
              onAction: onAddRoom,
            ),
            const SizedBox(height: 12),
            ...project.houseModel.rooms.map((room) {
              final isSelected = selectedRoomId == room.id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  key: ValueKey('room-tile-${room.id}'),
                  onTap: () => onSelectRoom(room.id),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outlineVariant,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  title: Text(
                    room.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${room.kind.label} • ${room.areaSquareMeters.toStringAsFixed(1)} м² • h ${room.heightMeters.toStringAsFixed(1)} м',
                  ),
                  trailing: PopupMenuButton<String>(
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
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _LegacyElementRecord {
  const _LegacyElementRecord({required this.element, required this.reason});

  final HouseEnvelopeElement element;
  final String reason;
}

class _ExteriorEnvelopeCard extends StatelessWidget {
  const _ExteriorEnvelopeCard({
    required this.project,
    required this.selectedRoomId,
    required this.onSelectRoom,
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

    final supportedElements = <HouseEnvelopeElement>[];
    final legacyElements = <_LegacyElementRecord>[];
    for (final element in project.houseModel.elements) {
      final construction = constructionMap[element.constructionId];
      if (_isSupportedEnvelopeElement(element, construction)) {
        supportedElements.add(element);
      } else {
        legacyElements.add(
          _LegacyElementRecord(
            element: element,
            reason: _describeLegacyElement(element, construction),
          ),
        );
      }
    }

    final supportedElementIds = supportedElements
        .map((item) => item.id)
        .toSet();
    final legacyOpenings = project.houseModel.openings
        .where((opening) => !supportedElementIds.contains(opening.elementId))
        .toList(growable: false);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardHeader(
              title: 'Ограждающие конструкции',
              actionLabel: 'Добавить в выбранное помещение',
              onAction: () {
                if (project.houseModel.rooms.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Сначала добавьте хотя бы одно помещение.'),
                    ),
                  );
                  return;
                }
                final room = project.houseModel.rooms.firstWhere(
                  (item) =>
                      item.id ==
                      (selectedRoomId ?? project.houseModel.rooms.first.id),
                  orElse: () => project.houseModel.rooms.first,
                );
                onAddElement(room);
              },
            ),
            const SizedBox(height: 8),
            const Text(
              'Доступны только конструкции внешнего контура. Неподдерживаемые записи отображаются отдельно как наследие (read-only).',
            ),
            const SizedBox(height: 12),
            ...project.houseModel.rooms.map((room) {
              final roomElements = supportedElements
                  .where((element) => element.roomId == room.id)
                  .toList(growable: false);
              final roomElementIds = roomElements
                  .map((item) => item.id)
                  .toSet();
              final roomOpenings = project.houseModel.openings
                  .where(
                    (opening) => roomElementIds.contains(opening.elementId),
                  )
                  .toList(growable: false);
              final isSelected = selectedRoomId == room.id;

              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFF1E8D6)
                        : const Color(0xFFF9F7F2),
                    borderRadius: BorderRadius.circular(18),
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
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => onSelectRoom(room.id),
                                child: Text(
                                  room.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                            FilledButton.tonal(
                              onPressed: () => onAddElement(room),
                              child: const Text('Добавить'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (roomElements.isEmpty)
                          const Text(
                            'Поддерживаемые ограждения пока не добавлены.',
                          )
                        else
                          ...roomElements.map((element) {
                            final construction =
                                constructionMap[element.constructionId];
                            final openings = roomOpenings
                                .where(
                                  (opening) => opening.elementId == element.id,
                                )
                                .toList(growable: false);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFDFBF7),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outlineVariant,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    ListTile(
                                      title: Text(
                                        element.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      subtitle: Text(
                                        '${element.elementKind.label} • ${element.areaSquareMeters.toStringAsFixed(1)} м²\n'
                                        'Конструкция: ${construction?.title ?? element.constructionId}',
                                      ),
                                      isThreeLine: true,
                                      trailing: PopupMenuButton<String>(
                                        onSelected: (value) {
                                          if (value == 'calc') {
                                            onOpenThermocalc(element);
                                          } else if (value == 'opening') {
                                            onAddOpening(element);
                                          } else if (value == 'edit') {
                                            onEditElement(element);
                                          } else if (value == 'delete') {
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
                                          0,
                                          16,
                                          10,
                                        ),
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text('Проемы не добавлены.'),
                                        ),
                                      )
                                    else
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          10,
                                          0,
                                          10,
                                          10,
                                        ),
                                        child: Column(
                                          children: [
                                            ...openings.map(
                                              (opening) => ListTile(
                                                dense: true,
                                                leading: const Icon(
                                                  Icons
                                                      .subdirectory_arrow_right,
                                                ),
                                                title: Text(opening.title),
                                                subtitle: Text(
                                                  '${opening.kind.label} • ${opening.areaSquareMeters.toStringAsFixed(1)} м² • U ${opening.heatTransferCoefficient.toStringAsFixed(2)}',
                                                ),
                                                trailing: PopupMenuButton<String>(
                                                  onSelected: (value) {
                                                    if (value == 'edit') {
                                                      onEditOpening(opening);
                                                    } else if (value ==
                                                        'delete') {
                                                      onDeleteOpening(opening);
                                                    }
                                                  },
                                                  itemBuilder: (context) =>
                                                      const [
                                                        PopupMenuItem(
                                                          value: 'edit',
                                                          child: Text(
                                                            'Редактировать проём',
                                                          ),
                                                        ),
                                                        PopupMenuItem(
                                                          value: 'delete',
                                                          child: Text(
                                                            'Удалить проём',
                                                          ),
                                                        ),
                                                      ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
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
              );
            }),
            if (legacyElements.isNotEmpty || legacyOpenings.isNotEmpty)
              ExpansionTile(
                key: const ValueKey('legacy-read-only-block'),
                title: Text(
                  'Наследие (только чтение): ${legacyElements.length + legacyOpenings.length}',
                ),
                children: [
                  ...legacyElements.map(
                    (item) => ListTile(
                      title: Text(item.element.title),
                      subtitle: Text(item.reason),
                    ),
                  ),
                  ...legacyOpenings.map(
                    (opening) => ListTile(
                      title: Text(opening.title),
                      subtitle: Text('Элемент: ${opening.elementId}'),
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
    final materialMap = {for (final item in catalog.materials) item.id: item};
    final supportedConstructions = project.constructions
        .where((item) => _allowedExteriorKinds.contains(item.elementKind))
        .toList(growable: false);
    final legacyConstructions = project.constructions
        .where((item) => !_allowedExteriorKinds.contains(item.elementKind))
        .toList(growable: false);
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
            const Text(
              'В этом разделе доступны только конструкции внешнего контура.',
            ),
            const SizedBox(height: 12),
            ...supportedConstructions.map((construction) {
              final layerTitles = construction.layers
                  .map(
                    (layer) =>
                        materialMap[layer.materialId]?.name ?? layer.materialId,
                  )
                  .join(', ');
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ListTile(
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
                    '${construction.elementKind.label}\n$layerTitles',
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
            if (legacyConstructions.isNotEmpty)
              ExpansionTile(
                key: const ValueKey('legacy-constructions-read-only-block'),
                title: Text(
                  'Наследие (только чтение): ${legacyConstructions.length}',
                ),
                children: [
                  ...legacyConstructions.map((construction) {
                    final layerTitles = construction.layers
                        .map(
                          (layer) =>
                              materialMap[layer.materialId]?.name ??
                              layer.materialId,
                        )
                        .join(', ');
                    return ListTile(
                      title: Text(construction.title),
                      subtitle: Text(
                        '${construction.elementKind.label}\n$layerTitles',
                      ),
                      isThreeLine: true,
                    );
                  }),
                ],
              ),
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
  final effectiveLayout =
      room?.layout ?? initialLayout ?? RoomLayoutRect.defaultRect();
  final titleController = TextEditingController(text: room?.title ?? '');
  final areaController = TextEditingController(
    text: effectiveLayout.areaSquareMeters.toStringAsFixed(1),
  );
  final heightController = TextEditingController(
    text: (room?.heightMeters ?? defaultRoomHeightMeters).toStringAsFixed(2),
  );
  var selectedKind = room?.kind ?? RoomKind.livingRoom;

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
                TextField(
                  controller: areaController,
                  decoration: const InputDecoration(labelText: 'Площадь, м²'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
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
                const SizedBox(height: 8),
                Text(
                  'Геометрия плана сохраняется автоматически как квадрат по заданной площади.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    final area = _parseDouble(
                      areaController.text,
                      fallback: effectiveLayout.areaSquareMeters,
                    );
                    final layout = _squareLayoutFromArea(
                      area,
                      baseLayout: effectiveLayout,
                    );
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
                        layout: layout,
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
  areaController.dispose();
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
  final allowedConstructions = project.constructions
      .where(
        (construction) =>
            _allowedExteriorKinds.contains(construction.elementKind),
      )
      .toList(growable: false);
  if (allowedConstructions.isEmpty) {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => const Padding(
        padding: EdgeInsets.all(20),
        child: Text('Нет доступных конструкций внешнего контура.'),
      ),
    );
    return null;
  }

  final availableKinds =
      allowedConstructions
          .map((item) => item.elementKind)
          .toSet()
          .toList(growable: false)
        ..sort((left, right) => left.index.compareTo(right.index));

  final titleController = TextEditingController(text: element?.title ?? '');
  final areaController = TextEditingController(
    text: (element?.areaSquareMeters ?? defaultHouseElementAreaSquareMeters)
        .toStringAsFixed(2),
  );
  final offsetController = TextEditingController(
    text: (element?.wallPlacement?.offsetMeters ?? 0).toStringAsFixed(2),
  );
  final lengthController = TextEditingController(
    text: (element?.wallPlacement?.lengthMeters ?? defaultRoomLayoutWidthMeters)
        .toStringAsFixed(2),
  );

  var selectedRoomId = element?.roomId ?? roomId;
  var selectedKind = availableKinds.contains(element?.elementKind)
      ? element!.elementKind
      : availableKinds.first;
  var selectedConstructionId = allowedConstructions
      .firstWhere(
        (item) =>
            item.id == element?.constructionId &&
            item.elementKind == selectedKind,
        orElse: () => allowedConstructions.firstWhere(
          (item) => item.elementKind == selectedKind,
        ),
      )
      .id;
  var selectedSide = element?.wallPlacement?.side ?? RoomSide.top;

  final result = await showModalBottomSheet<HouseEnvelopeElement>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          final selectedRoom = project.houseModel.rooms.firstWhere(
            (room) => room.id == selectedRoomId,
          );
          final constructionsForKind = allowedConstructions
              .where((construction) => construction.elementKind == selectedKind)
              .toList(growable: false);
          if (!constructionsForKind.any(
            (item) => item.id == selectedConstructionId,
          )) {
            selectedConstructionId = constructionsForKind.first.id;
          }

          final effectiveLength = _parseDouble(
            lengthController.text,
            fallback: selectedRoom.layout.sideLength(selectedSide),
          );
          final effectiveOffset = _parseDouble(
            offsetController.text,
            fallback: 0,
          );
          final wallPlacement = selectedKind == ConstructionElementKind.wall
              ? _snapWallPlacement(
                  EnvelopeWallPlacement(
                    side: selectedSide,
                    offsetMeters: effectiveOffset,
                    lengthMeters: effectiveLength,
                  ),
                  sideLength: selectedRoom.layout.sideLength(selectedSide),
                )
              : null;
          final derivedWallArea = wallPlacement == null
              ? null
              : wallPlacement.lengthMeters * selectedRoom.heightMeters;

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
                const SizedBox(height: 12),
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
                  items: availableKinds
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
                        selectedConstructionId = allowedConstructions
                            .firstWhere(
                              (item) => item.elementKind == selectedKind,
                            )
                            .id;
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
                  DropdownButtonFormField<RoomSide>(
                    initialValue: selectedSide,
                    decoration: const InputDecoration(
                      labelText: 'Сторона комнаты',
                    ),
                    items: RoomSide.values
                        .map(
                          (side) => DropdownMenuItem(
                            value: side,
                            child: Text(side.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => selectedSide = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: offsetController,
                    decoration: const InputDecoration(labelText: 'Смещение, м'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: lengthController,
                    decoration: const InputDecoration(
                      labelText: 'Длина сегмента, м',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Расчётная площадь стены',
                    ),
                    child: Text(
                      '${(derivedWallArea ?? 0).toStringAsFixed(1)} м²',
                    ),
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
                  onPressed: () {
                    final selectedConstruction = allowedConstructions
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
                        areaSquareMeters:
                            selectedConstruction.elementKind ==
                                ConstructionElementKind.wall
                            ? (derivedWallArea ?? 0)
                            : _parseDouble(
                                areaController.text,
                                fallback: defaultHouseElementAreaSquareMeters,
                              ),
                        constructionId: selectedConstruction.id,
                        wallPlacement:
                            selectedConstruction.elementKind ==
                                ConstructionElementKind.wall
                            ? wallPlacement
                            : null,
                      ),
                    );
                  },
                  child: const Text('Сохранить'),
                ),
                if (catalog.materials.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
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
  offsetController.dispose();
  lengthController.dispose();
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
    allowedElementKinds: _allowedExteriorKinds,
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
            const SizedBox(height: 12),
            DropdownButtonFormField<OpeningKind>(
              initialValue: selectedKind,
              decoration: const InputDecoration(labelText: 'Тип проёма'),
              items: OpeningKind.values
                  .map(
                    (item) =>
                        DropdownMenuItem(value: item, child: Text(item.label)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  selectedKind = value;
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
            ),
            const SizedBox(height: 12),
            TextField(
              controller: coefficientController,
              decoration: const InputDecoration(labelText: 'U, Вт/м²·°C'),
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

  titleController.dispose();
  areaController.dispose();
  coefficientController.dispose();
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
                  const SizedBox(height: 12),
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
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'Примечание'),
                  minLines: 1,
                  maxLines: 3,
                ),
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

RoomLayoutRect _squareLayoutFromArea(
  double areaSquareMeters, {
  required RoomLayoutRect baseLayout,
}) {
  final minimumArea =
      minimumRoomLayoutDimensionMeters * minimumRoomLayoutDimensionMeters;
  final normalizedArea = math.max(areaSquareMeters, minimumArea);
  final side = math.max(
    minimumRoomLayoutDimensionMeters,
    _snapToStep(math.sqrt(normalizedArea)),
  );
  return RoomLayoutRect(
    xMeters: baseLayout.xMeters,
    yMeters: baseLayout.yMeters,
    widthMeters: side,
    heightMeters: side,
  );
}

EnvelopeWallPlacement _snapWallPlacement(
  EnvelopeWallPlacement placement, {
  required double sideLength,
}) {
  final snappedLength = math.min(
    sideLength,
    math.max(roomLayoutSnapStepMeters, _snapToStep(placement.lengthMeters)),
  );
  final maxOffset = math.max(0.0, sideLength - snappedLength);
  return EnvelopeWallPlacement(
    side: placement.side,
    offsetMeters: math.min(
      maxOffset,
      math.max(0.0, _snapToStep(placement.offsetMeters)),
    ),
    lengthMeters: snappedLength,
  );
}

double _snapToStep(double value) {
  return (value / roomLayoutSnapStepMeters).round() * roomLayoutSnapStepMeters;
}

bool _isSupportedEnvelopeElement(
  HouseEnvelopeElement element,
  Construction? construction,
) {
  if (construction == null) {
    return false;
  }
  if (!_allowedExteriorKinds.contains(construction.elementKind)) {
    return false;
  }
  if (element.elementKind != construction.elementKind) {
    return false;
  }
  if (element.elementKind == ConstructionElementKind.wall &&
      element.wallPlacement == null) {
    return false;
  }
  return true;
}

String _describeLegacyElement(
  HouseEnvelopeElement element,
  Construction? construction,
) {
  if (construction == null) {
    return 'Конструкция ${element.constructionId} не найдена в проекте.';
  }
  if (!_allowedExteriorKinds.contains(construction.elementKind)) {
    return 'Тип конструкции не поддерживается новым интерфейсом.';
  }
  if (element.elementKind != construction.elementKind) {
    return 'Тип элемента не совпадает с типом конструкции.';
  }
  if (element.elementKind == ConstructionElementKind.wall &&
      element.wallPlacement == null) {
    return 'Для стены отсутствует привязка к стороне помещения.';
  }
  return 'Запись не соответствует ограничениям раздела.';
}

String _buildId(String prefix) =>
    '$prefix-${DateTime.now().microsecondsSinceEpoch}';

double _parseDouble(String value, {required double fallback}) {
  return double.tryParse(value.replaceAll(',', '.')) ?? fallback;
}

String _requiredText(String value, {required String fallback}) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? fallback : trimmed;
}

String _describeError(Object error) {
  final raw = error.toString().replaceFirst(RegExp(r'^Bad state: '), '');
  if (raw.contains('Комнаты не должны пересекаться на плане')) {
    return 'Помещения пересекаются. Проверьте площадь и положение комнаты.';
  }
  if (raw.contains('Размер комнаты не может быть меньше')) {
    return 'Площадь помещения слишком мала. Увеличьте площадь или высоту.';
  }
  if (raw.contains('Комната не может выходить в отрицательные координаты')) {
    return 'Положение помещения некорректно. Проверьте исходные данные.';
  }
  if (raw.contains('Для наружной стены нужна привязка к стороне комнаты')) {
    return 'Для стены выберите сторону комнаты и длину сегмента.';
  }
  return raw;
}

void _showError(ScaffoldMessengerState messenger, Object error) {
  messenger.showSnackBar(
    SnackBar(
      content: Text('Не удалось выполнить действие: ${_describeError(error)}'),
    ),
  );
}
