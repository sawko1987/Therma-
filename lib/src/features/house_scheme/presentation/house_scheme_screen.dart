import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/catalog.dart';
import '../../../core/models/project.dart';
import '../../../core/providers.dart';
import '../../../core/services/house_summary_service.dart';
import '../../thermocalc/presentation/thermocalc_screen.dart';

class HouseSchemeScreen extends ConsumerWidget {
  const HouseSchemeScreen({super.key});

  Future<void> _handleAddRoom(BuildContext context, WidgetRef ref) async {
    final room = await _showRoomEditor(context);
    if (!context.mounted) {
      return;
    }
    if (room == null) {
      return;
    }
    try {
      await ref.read(projectEditorProvider).addRoom(room);
    } catch (error) {
      _showError(context, error);
    }
  }

  Future<void> _handleEditRoom(
    BuildContext context,
    WidgetRef ref,
    Room room,
  ) async {
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
      _showError(context, error);
    }
  }

  Future<void> _handleDeleteRoom(
    BuildContext context,
    WidgetRef ref,
    Room room,
  ) async {
    if (!context.mounted) {
      return;
    }
    try {
      await ref.read(projectEditorProvider).deleteRoom(room.id);
    } catch (error) {
      _showError(context, error);
    }
  }

  Future<void> _handleAddElement(
    BuildContext context,
    WidgetRef ref,
    Project project,
    CatalogSnapshot catalog,
    Room room,
  ) async {
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
      _showError(context, error);
    }
  }

  Future<void> _handleEditElement(
    BuildContext context,
    WidgetRef ref,
    Project project,
    CatalogSnapshot catalog,
    HouseEnvelopeElement element,
  ) async {
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
      _showError(context, error);
    }
  }

  Future<void> _handleDeleteElement(
    BuildContext context,
    WidgetRef ref,
    HouseEnvelopeElement element,
  ) async {
    if (!context.mounted) {
      return;
    }
    try {
      await ref.read(projectEditorProvider).deleteEnvelopeElement(element.id);
    } catch (error) {
      _showError(context, error);
    }
  }

  Future<void> _handleAddConstruction(
    BuildContext context,
    WidgetRef ref,
    CatalogSnapshot catalog,
  ) async {
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
      _showError(context, error);
    }
  }

  Future<void> _handleEditConstruction(
    BuildContext context,
    WidgetRef ref,
    CatalogSnapshot catalog,
    Construction construction,
  ) async {
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
      _showError(context, error);
    }
  }

  Future<void> _handleDeleteConstruction(
    BuildContext context,
    WidgetRef ref,
    Construction construction,
  ) async {
    if (!context.mounted) {
      return;
    }
    try {
      await ref.read(projectEditorProvider).deleteConstruction(construction.id);
    } catch (error) {
      _showError(context, error);
    }
  }

  void _handleOpenThermocalc(
    BuildContext context,
    WidgetRef ref,
    HouseEnvelopeElement element,
  ) {
    ref.read(projectEditorProvider).selectEnvelopeElement(element);
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ThermocalcScreen()),
    );
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
                    _RoomsCard(
                      project: project,
                      onAddRoom: () => _handleAddRoom(context, ref),
                      onEditRoom: (room) => _handleEditRoom(context, ref, room),
                      onDeleteRoom: (room) =>
                          _handleDeleteRoom(context, ref, room),
                      onAddElement: (room) =>
                          _handleAddElement(context, ref, project, catalog, room),
                      onEditElement: (element) => _handleEditElement(
                        context,
                        ref,
                        project,
                        catalog,
                        element,
                      ),
                      onDeleteElement: (element) =>
                          _handleDeleteElement(context, ref, element),
                      onOpenThermocalc: (element) =>
                          _handleOpenThermocalc(context, ref, element),
                    ),
                    const SizedBox(height: 16),
                    _ConstructionsCard(
                      project: project,
                      catalog: catalog,
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
          'Конструктор дома собирает проект сверху вниз: помещения, ограждения и переиспользуемые конструкции. Расчёт конструкции запускается прямо из выбранного ограждения.',
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
                  label: 'Оценка потерь',
                  value: '${summary.totalHeatLossWatts.toStringAsFixed(0)} Вт',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomsCard extends StatelessWidget {
  const _RoomsCard({
    required this.project,
    required this.onAddRoom,
    required this.onEditRoom,
    required this.onDeleteRoom,
    required this.onAddElement,
    required this.onEditElement,
    required this.onDeleteElement,
    required this.onOpenThermocalc,
  });

  final Project project;
  final VoidCallback onAddRoom;
  final ValueChanged<Room> onEditRoom;
  final ValueChanged<Room> onDeleteRoom;
  final ValueChanged<Room> onAddElement;
  final ValueChanged<HouseEnvelopeElement> onEditElement;
  final ValueChanged<HouseEnvelopeElement> onDeleteElement;
  final ValueChanged<HouseEnvelopeElement> onOpenThermocalc;

  @override
  Widget build(BuildContext context) {
    final constructionMap = {
      for (final construction in project.constructions) construction.id: construction,
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

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9F7F2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
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
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${room.kind.label} • ${room.areaSquareMeters.toStringAsFixed(1)} м² • h ${room.heightMeters.toStringAsFixed(1)} м',
                                  ),
                                  Text(
                                    'Ограждений: ${roomElements.length}, суммарная площадь ${envelopeArea.toStringAsFixed(1)} м²',
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
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outlineVariant,
                                  ),
                                ),
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
                                    switch (value) {
                                      case 'calc':
                                        onOpenThermocalc(element);
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
                            );
                          }),
                      ],
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
                  .map((layer) => materialMap[layer.materialId]?.name ?? layer.materialId)
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

Future<Room?> _showRoomEditor(BuildContext context, {Room? room}) async {
  final titleController = TextEditingController(text: room?.title ?? '');
  final areaController = TextEditingController(
    text: (room?.areaSquareMeters ?? defaultRoomAreaSquareMeters).toString(),
  );
  final heightController = TextEditingController(
    text: (room?.heightMeters ?? defaultRoomHeightMeters).toString(),
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
                        areaSquareMeters: _parseDouble(
                          areaController.text,
                          fallback: defaultRoomAreaSquareMeters,
                        ),
                        heightMeters: _parseDouble(
                          heightController.text,
                          fallback: defaultRoomHeightMeters,
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
                  decoration: const InputDecoration(labelText: 'Тип ограждения'),
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
  final titleController = TextEditingController(text: construction?.title ?? '');
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
          final materialMap = {for (final item in catalog.materials) item.id: item};
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
                  decoration:
                      const InputDecoration(labelText: 'Тип конструкции'),
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

double _parseDouble(String value, {required double fallback}) {
  return double.tryParse(value.replaceAll(',', '.')) ?? fallback;
}

String _requiredText(String value, {required String fallback}) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? fallback : trimmed;
}

void _showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text('Не удалось выполнить действие: $error')));
}
