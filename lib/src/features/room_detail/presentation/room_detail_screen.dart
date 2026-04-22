import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/building_heat_loss.dart';
import '../../../core/models/catalog.dart';
import '../../../core/models/project.dart';
import '../../../core/providers.dart';
import '../../house_scheme/presentation/house_scheme_screen.dart';
import '../../thermocalc/presentation/thermocalc_screen.dart';

class RoomDetailScreen extends ConsumerWidget {
  const RoomDetailScreen({super.key, required this.room});

  final Room room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectAsync = ref.watch(selectedProjectProvider);
    final catalogAsync = ref.watch(catalogSnapshotProvider);
    final heatLossAsync = ref.watch(buildingHeatLossResultProvider);

    return projectAsync.when(
      data: (project) {
        final currentRoom = project == null ? null : _findRoom(project, room.id);
        return Scaffold(
          appBar: AppBar(
            title: Text(
              currentRoom?.title ?? room.title,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            actions: [
              IconButton(
                tooltip: 'Редактировать помещение',
                icon: const Icon(Icons.edit_outlined),
                onPressed: currentRoom == null
                    ? null
                    : () => _handleEditRoom(context, ref, currentRoom),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(42),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${(currentRoom ?? room).kind.label} • ${(currentRoom ?? room).areaSquareMeters.toStringAsFixed(1)} м² • h ${(currentRoom ?? room).heightMeters.toStringAsFixed(1)} м',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            ),
          ),
          body: catalogAsync.when(
            data: (catalog) => heatLossAsync.when(
              data: (heatLoss) {
                if (project == null) {
                  return const Center(child: Text('Активный проект не найден.'));
                }
                if (currentRoom == null) {
                  return const Center(
                    child: Text('Помещение не найдено в активном проекте.'),
                  );
                }
                final data = _RoomDetailData.fromSources(
                  room: currentRoom,
                  project: project,
                  catalog: catalog,
                  heatLoss: heatLoss,
                );
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  children: [
                    _HeatBalanceCard(data: data),
                    const SizedBox(height: 16),
                    _ElementsSection(room: currentRoom, data: data),
                    const SizedBox(height: 16),
                    _CalculationTableCard(data: data),
                    const SizedBox(height: 16),
                    _WallSchemeCard(data: data),
                    if (data.thermocalcElement != null) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => _openThermocalc(
                            context,
                            ref,
                            data.thermocalcElement!,
                          ),
                          child: const Text('Открыть в Thermocalc'),
                        ),
                      ),
                    ],
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('Ошибка расчета: $error')),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('Ошибка каталога: $error')),
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(
          title: Text(
            room.title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(
          title: Text(
            room.title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        body: Center(child: Text('Ошибка проекта: $error')),
      ),
    );
  }

  Future<void> _handleEditRoom(
    BuildContext context,
    WidgetRef ref,
    Room currentRoom,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final updated = await showRoomEditorSheet(context, room: currentRoom);
      if (!context.mounted || updated == null) {
        return;
      }
      await ref.read(projectEditorProvider).updateRoom(updated);
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('Не удалось обновить помещение: $error')),
      );
    }
  }

  void _openThermocalc(
    BuildContext context,
    WidgetRef ref,
    HouseEnvelopeElement element,
  ) {
    ref.read(projectEditorProvider).selectEnvelopeElement(element);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ThermocalcScreen(),
      ),
    );
  }

  Room? _findRoom(Project project, String roomId) {
    for (final item in project.houseModel.rooms) {
      if (item.id == roomId) {
        return item;
      }
    }
    return null;
  }
}

class _HeatBalanceCard extends StatelessWidget {
  const _HeatBalanceCard({required this.data});

  final _RoomDetailData data;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final roomResult = data.roomResult;
    final balanceValue = roomResult?.heatingPowerDeltaWatts ?? 0;
    final balanceColor = balanceValue >= 0
        ? colorScheme.primary
        : colorScheme.error;
    final grossEnvelopeArea =
        roomResult?.totalEnvelopeAreaSquareMeters ?? data.grossEnvelopeArea;
    final opaqueEnvelopeArea =
        roomResult?.totalOpaqueAreaSquareMeters ?? data.opaqueEnvelopeArea;
    final openingCount = roomResult?.openingCount ?? data.openings.length;
    final elementCount = roomResult?.elementCount ?? data.elements.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Тепловой баланс помещения',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _MetricTile(
                  label: 'Внутренняя температура',
                  value: '${data.insideTemperature.toStringAsFixed(0)} °C',
                ),
                _MetricTile(
                  label: 'Наружная температура',
                  value: '${data.outsideTemperature.toStringAsFixed(0)} °C',
                ),
                _MetricTile(
                  label: 'Суммарные потери',
                  value:
                      '${(roomResult?.heatLossWatts ?? 0).toStringAsFixed(0)} Вт',
                  valueColor: balanceColor,
                  emphasize: true,
                ),
                _MetricTile(
                  label: 'Через ограждения',
                  value:
                      '${(roomResult?.opaqueHeatLossWatts ?? 0).toStringAsFixed(0)} Вт',
                ),
                _MetricTile(
                  label: 'Через проёмы',
                  value:
                      '${(roomResult?.openingHeatLossWatts ?? 0).toStringAsFixed(0)} Вт',
                ),
                _MetricTile(
                  label: 'Площадь помещения',
                  value: '${data.room.areaSquareMeters.toStringAsFixed(1)} м²',
                ),
                _MetricTile(
                  label: 'Ограждения, валовая',
                  value: '${grossEnvelopeArea.toStringAsFixed(1)} м²',
                ),
                _MetricTile(
                  label: 'Ограждения, чистая',
                  value: '${opaqueEnvelopeArea.toStringAsFixed(1)} м²',
                ),
                _MetricTile(
                  label: 'Количество',
                  value: '$elementCount огр. / $openingCount пр.',
                ),
              ],
            ),
            if (roomResult != null) ...[
              const SizedBox(height: 12),
              Text(
                balanceValue >= 0
                    ? 'Отопление перекрывает расчётные теплопотери.'
                    : 'Отопления недостаточно для расчётных теплопотерь.',
                style: TextStyle(
                  color: balanceColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (roomResult.unresolvedElements.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Без расчёта: ${roomResult.unresolvedElements.map((item) => item.title).join(', ')}',
                  style: TextStyle(
                    color: colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _ElementsSection extends ConsumerWidget {
  const _ElementsSection({
    required this.room,
    required this.data,
  });

  final Room room;
  final _RoomDetailData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Наружные ограждения',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _SectionActionButton(
                  label: 'Добавить ограждение',
                  onPressed: () => _handleAddElement(context, ref),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (data.elements.isEmpty)
              _EmptyState(
                title: 'Ограждения не добавлены',
                message:
                    'Добавьте стены, кровлю, пол или перекрытие для расчёта теплопотерь по комнате.',
              )
            else
              ...data.elements.map((element) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ElementCard(
                    room: room,
                     element: element,
                     construction: element.construction,
                     openings: data.openingsByElementId[element.id] ?? const [],
                     elementResult: data.elementResultsById[element.id],
                   ),
                );
              }),
            if (data.missingConstructionElements.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Часть ограждений без доступной конструкции: ${data.missingConstructionElements.map((item) => item.title).join(', ')}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _handleAddElement(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final project = await ref.read(selectedProjectProvider.future);
      final catalog = await ref.read(catalogSnapshotProvider.future);
      if (!context.mounted || project == null) {
        return;
      }
      final created = await showElementEditorSheet(
        context,
        project: project,
        catalog: catalog,
        roomId: room.id,
      );
      if (!context.mounted || created == null) {
        return;
      }
      await ref.read(projectEditorProvider).addEnvelopeElement(created);
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('Не удалось добавить ограждение: $error')),
      );
    }
  }
}

class _ElementCard extends ConsumerStatefulWidget {
  const _ElementCard({
    required this.room,
    required this.element,
    required this.construction,
    required this.openings,
    required this.elementResult,
  });

  final Room room;
  final HouseEnvelopeElement element;
  final Construction? construction;
  final List<EnvelopeOpening> openings;
  final BuildingElementHeatLossResult? elementResult;

  @override
  ConsumerState<_ElementCard> createState() => _ElementCardState();
}

class _ElementCardState extends ConsumerState<_ElementCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final openingArea = widget.openings.fold<double>(
      0,
      (sum, item) => sum + item.areaSquareMeters,
    );
    final opaqueArea = (widget.element.areaSquareMeters - openingArea).clamp(
      0.0,
      widget.element.areaSquareMeters,
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
        color: colorScheme.surface,
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.element.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.element.elementKind.label} • ${widget.construction?.title ?? 'Конструкция не найдена'}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: widget.construction == null
                                ? colorScheme.error
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Площадь валовая ${widget.element.areaSquareMeters.toStringAsFixed(1)} м² • чистая ${opaqueArea.toStringAsFixed(1)} м²',
                        ),
                        if (widget.element.elementKind ==
                                ConstructionElementKind.wall &&
                            widget.element.wallPlacement != null)
                          Text(_wallPlacementLabel(widget.element.wallPlacement!)),
                        if (widget.elementResult != null)
                          Text(
                            'Потери ${widget.elementResult!.totalHeatLossWatts.toStringAsFixed(0)} Вт • '
                            'R ${widget.elementResult!.totalResistance.toStringAsFixed(2)} м²·°C/Вт',
                          ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') {
                        await _handleEditElement(context);
                      } else if (value == 'delete') {
                        await _handleDeleteElement(context);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: Text('Редактировать'),
                      ),
                      PopupMenuItem(value: 'delete', child: Text('Удалить')),
                    ],
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Проёмы',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      FilledButton.tonal(
                        onPressed: () => _handleAddOpening(context),
                        child: const Text('Добавить проём'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (widget.openings.isEmpty)
                    const Text('Проёмы не добавлены.')
                  else
                    ...widget.openings.map((opening) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _OpeningTile(
                          opening: opening,
                          onEdit: () => _handleEditOpening(context, opening),
                          onDelete: () => _handleDeleteOpening(context, opening),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _wallPlacementLabel(EnvelopeWallPlacement placement) {
    return '${placement.side.label} • сегмент ${placement.lengthMeters.toStringAsFixed(1)} м • '
        'смещение ${placement.offsetMeters.toStringAsFixed(1)} м';
  }

  Future<void> _handleEditElement(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final project = await ref.read(selectedProjectProvider.future);
      final catalog = await ref.read(catalogSnapshotProvider.future);
      if (!context.mounted || project == null) {
        return;
      }
      final updated = await showElementEditorSheet(
        context,
        project: project,
        catalog: catalog,
        roomId: widget.room.id,
        element: widget.element,
      );
      if (!context.mounted || updated == null) {
        return;
      }
      await ref.read(projectEditorProvider).updateEnvelopeElement(updated);
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('Не удалось обновить ограждение: $error')),
      );
    }
  }

  Future<void> _handleDeleteElement(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(projectEditorProvider)
          .deleteEnvelopeElement(widget.element.id);
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('Не удалось удалить ограждение: $error')),
      );
    }
  }

  Future<void> _handleAddOpening(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final catalog = await ref.read(catalogSnapshotProvider.future);
      if (!context.mounted) {
        return;
      }
      final created = await showOpeningEditorSheet(
        context,
        catalog: catalog,
        elementId: widget.element.id,
        initialKind: OpeningKind.window,
      );
      if (!context.mounted || created == null) {
        return;
      }
      await ref.read(projectEditorProvider).addOpening(created);
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('Не удалось добавить проём: $error')),
      );
    }
  }

  Future<void> _handleEditOpening(
    BuildContext context,
    EnvelopeOpening opening,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final catalog = await ref.read(catalogSnapshotProvider.future);
      if (!context.mounted) {
        return;
      }
      final updated = await showOpeningEditorSheet(
        context,
        catalog: catalog,
        elementId: widget.element.id,
        opening: opening,
      );
      if (!context.mounted || updated == null) {
        return;
      }
      await ref.read(projectEditorProvider).updateOpening(updated);
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('Не удалось обновить проём: $error')),
      );
    }
  }

  Future<void> _handleDeleteOpening(
    BuildContext context,
    EnvelopeOpening opening,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(projectEditorProvider).deleteOpening(opening.id);
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('Не удалось удалить проём: $error')),
      );
    }
  }
}

class _OpeningTile extends StatelessWidget {
  const _OpeningTile({
    required this.opening,
    required this.onEdit,
    required this.onDelete,
  });

  final EnvelopeOpening opening;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      tileColor: const Color(0xFFF7F4ED),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: Icon(
        opening.kind == OpeningKind.window
            ? Icons.crop_landscape_outlined
            : Icons.door_front_door_outlined,
        color: colorScheme.primary,
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
            onEdit();
          } else if (value == 'delete') {
            onDelete();
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'edit', child: Text('Редактировать')),
          PopupMenuItem(value: 'delete', child: Text('Удалить')),
        ],
      ),
    );
  }
}

class _CalculationTableCard extends StatelessWidget {
  const _CalculationTableCard({required this.data});

  final _RoomDetailData data;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Расчёт по ограждениям',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            if (data.elements.isEmpty)
              const Text('Список появится после добавления ограждений.')
            else ...[
              const _CalculationHeaderRow(),
              const SizedBox(height: 8),
              ...List.generate(data.elements.length, (index) {
                final element = data.elements[index];
                final result = data.elementResultsById[element.id];
                return _CalculationDataRow(
                  backgroundColor: index.isEven
                      ? const Color(0xFFF7F4ED)
                      : Theme.of(context).colorScheme.surfaceContainerLow,
                  title: element.title,
                  kind: element.elementKind.label,
                  resistance: result == null
                      ? '—'
                      : result.totalResistance.toStringAsFixed(2),
                  area: (result?.elementAreaSquareMeters ?? element.areaSquareMeters)
                      .toStringAsFixed(1),
                  heatLoss: result == null
                      ? '—'
                      : result.totalHeatLossWatts.toStringAsFixed(0),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

class _WallSchemeCard extends StatelessWidget {
  const _WallSchemeCard({required this.data});

  final _RoomDetailData data;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Расположение стеновых ограждений',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            ...RoomSide.values.map((side) {
              final sideLength = data.room.layout.sideLength(side);
              final segments = _buildWallSegments(
                side: side,
                sideLength: sideLength,
                elements: data.wallElementsBySide[side] ?? const [],
              );
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _WallSideRow(
                  side: side,
                  sideLength: sideLength,
                  segments: segments,
                  onTapElement: (element) =>
                      _showWallElementDetails(context, element),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  List<_WallVisualSegment> _buildWallSegments({
    required RoomSide side,
    required double sideLength,
    required List<HouseEnvelopeElement> elements,
  }) {
    if (sideLength <= 0) {
      return const [];
    }
    final sorted = [...elements]..sort((a, b) {
      final left = a.wallPlacement?.offsetMeters ?? 0;
      final right = b.wallPlacement?.offsetMeters ?? 0;
      return left.compareTo(right);
    });
    final segments = <_WallVisualSegment>[];
    var cursor = 0.0;
    for (final element in sorted) {
      final placement = element.wallPlacement;
      if (placement == null) {
        continue;
      }
      final start = placement.offsetMeters.clamp(0.0, sideLength);
      final end = placement.endMeters.clamp(0.0, sideLength);
      if (start > cursor) {
        segments.add(_WallVisualSegment.empty(lengthMeters: start - cursor));
      }
      if (end > start) {
        segments.add(
          _WallVisualSegment.element(
            lengthMeters: end - start,
            element: element,
            openingCount: data.openingsByElementId[element.id]?.length ?? 0,
          ),
        );
      }
      cursor = math.max(cursor, end);
    }
    if (cursor < sideLength) {
      segments.add(_WallVisualSegment.empty(lengthMeters: sideLength - cursor));
    }
    if (segments.isEmpty) {
      segments.add(_WallVisualSegment.empty(lengthMeters: sideLength));
    }
    return segments;
  }

  void _showWallElementDetails(
    BuildContext context,
    HouseEnvelopeElement element,
  ) {
    final result = data.elementResultsById[element.id];
    final openings = data.openingsByElementId[element.id] ?? const [];
    final construction = element.construction;
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                element.title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(element.elementKind.label),
              Text('Конструкция: ${construction.title}'),
              Text('Площадь ${element.areaSquareMeters.toStringAsFixed(1)} м²'),
              Text('Проёмы: ${openings.length}'),
              if (result != null)
                Text(
                  'Потери ${result.totalHeatLossWatts.toStringAsFixed(0)} Вт • R ${result.totalResistance.toStringAsFixed(2)} м²·°C/Вт',
                ),
              if (element.wallPlacement case final placement?)
                Text(
                  '${placement.side.label} • сегмент ${placement.lengthMeters.toStringAsFixed(1)} м • '
                  'смещение ${placement.offsetMeters.toStringAsFixed(1)} м',
                ),
            ],
          ),
        );
      },
    );
  }
}

class _WallSideRow extends StatelessWidget {
  const _WallSideRow({
    required this.side,
    required this.sideLength,
    required this.segments,
    required this.onTapElement,
  });

  final RoomSide side;
  final double sideLength;
  final List<_WallVisualSegment> segments;
  final ValueChanged<HouseEnvelopeElement> onTapElement;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${side.label} • ${sideLength.toStringAsFixed(1)} м',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 44,
          child: Row(
            children: segments.map((segment) {
              final flex = math.max(1, (segment.lengthMeters * 100).round());
              final isElement = segment.element != null;
              final child = Container(
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: isElement
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: isElement
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(
                            math.min(segment.openingCount, 3),
                            (_) => Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 1,
                              ),
                              child: Icon(
                                Icons.crop_square_outlined,
                                size: 14,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        )
                      : null,
                ),
              );
              return Expanded(
                flex: flex,
                child: isElement
                    ? InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => onTapElement(segment.element!),
                        child: child,
                      )
                    : child,
              );
            }).toList(growable: false),
          ),
        ),
      ],
    );
  }
}

class _CalculationHeaderRow extends StatelessWidget {
  const _CalculationHeaderRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text('Название')),
          Expanded(flex: 3, child: Text('Вид')),
          Expanded(flex: 2, child: Text('R')),
          Expanded(flex: 2, child: Text('Площадь')),
          Expanded(flex: 2, child: Text('Потери Вт')),
        ],
      ),
    );
  }
}

class _CalculationDataRow extends StatelessWidget {
  const _CalculationDataRow({
    required this.backgroundColor,
    required this.title,
    required this.kind,
    required this.resistance,
    required this.area,
    required this.heatLoss,
  });

  final Color backgroundColor;
  final String title;
  final String kind;
  final String resistance;
  final String area;
  final String heatLoss;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text(title)),
          Expanded(flex: 3, child: Text(kind)),
          Expanded(flex: 2, child: Text(resistance)),
          Expanded(flex: 2, child: Text(area)),
          Expanded(flex: 2, child: Text(heatLoss)),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    this.valueColor,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 148,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: emphasize ? FontWeight.w900 : FontWeight.w800,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(label),
        ],
      ),
    );
  }
}

class _SectionActionButton extends StatelessWidget {
  const _SectionActionButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F4ED),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(message),
        ],
      ),
    );
  }
}

class _WallVisualSegment {
  const _WallVisualSegment._({
    required this.lengthMeters,
    required this.element,
    required this.openingCount,
  });

  const _WallVisualSegment.empty({required double lengthMeters})
    : this._(lengthMeters: lengthMeters, element: null, openingCount: 0);

  const _WallVisualSegment.element({
    required double lengthMeters,
    required HouseEnvelopeElement element,
    required int openingCount,
  }) : this._(
         lengthMeters: lengthMeters,
         element: element,
         openingCount: openingCount,
       );

  final double lengthMeters;
  final HouseEnvelopeElement? element;
  final int openingCount;
}

class _RoomDetailData {
  const _RoomDetailData({
    required this.room,
    required this.project,
    required this.catalog,
    required this.roomResult,
    required this.elements,
    required this.openings,
    required this.elementResultsById,
    required this.openingsByElementId,
    required this.constructionById,
    required this.wallElementsBySide,
    required this.insideTemperature,
    required this.outsideTemperature,
    required this.grossEnvelopeArea,
    required this.opaqueEnvelopeArea,
    required this.thermocalcElement,
    required this.missingConstructionElements,
  });

  factory _RoomDetailData.fromSources({
    required Room room,
    required Project project,
    required CatalogSnapshot catalog,
    required BuildingHeatLossResult? heatLoss,
  }) {
    final roomResult = _findRoomResult(heatLoss, room.id);
    final elements = project.houseModel.elements
        .where((element) => element.roomId == room.id)
        .toList(growable: false);
    final elementIds = {for (final item in elements) item.id};
    final openings = project.houseModel.openings
        .where((opening) => elementIds.contains(opening.elementId))
        .toList(growable: false);
    final openingsByElementId = <String, List<EnvelopeOpening>>{};
    for (final opening in openings) {
      openingsByElementId.putIfAbsent(opening.elementId, () => []).add(opening);
    }
    final constructionById = {
      for (final construction in project.constructions) construction.id: construction,
      for (final element in elements)
        (element.sourceConstructionId ?? element.construction.id): element.construction,
    };
    final elementResultsById = {
      for (final result in roomResult?.elementResults ?? const <BuildingElementHeatLossResult>[])
        result.element.id: result,
    };
    final wallElementsBySide = <RoomSide, List<HouseEnvelopeElement>>{};
    for (final element in elements) {
      final placement = element.wallPlacement;
      if (placement != null) {
        wallElementsBySide.putIfAbsent(placement.side, () => []).add(element);
      }
    }
    final grossEnvelopeArea = elements.fold<double>(
      0,
      (sum, item) => sum + item.areaSquareMeters,
    );
    final openingArea = openings.fold<double>(
      0,
      (sum, item) => sum + item.areaSquareMeters,
    );
    final insideTemperature =
        roomResult?.insideAirTemperature ??
        _findRoomKindCondition(catalog, room.kind)?.insideTemperature ??
        20;
    final outsideTemperature =
        roomResult?.outsideAirTemperature ??
        _findClimate(project, catalog)?.designTemperature ??
        0;

    HouseEnvelopeElement? thermocalcElement;
    final missingConstructionElements = <HouseEnvelopeElement>[];
    for (final element in elements) {
      thermocalcElement ??= element;
      if (element.construction.layers.isEmpty) {
        missingConstructionElements.add(element);
      }
    }

    return _RoomDetailData(
      room: room,
      project: project,
      catalog: catalog,
      roomResult: roomResult,
      elements: elements,
      openings: openings,
      elementResultsById: elementResultsById,
      openingsByElementId: openingsByElementId,
      constructionById: constructionById,
      wallElementsBySide: wallElementsBySide,
      insideTemperature: insideTemperature,
      outsideTemperature: outsideTemperature,
      grossEnvelopeArea: grossEnvelopeArea,
      opaqueEnvelopeArea: math.max(0, grossEnvelopeArea - openingArea),
      thermocalcElement: thermocalcElement,
      missingConstructionElements: missingConstructionElements,
    );
  }

  final Room room;
  final Project project;
  final CatalogSnapshot catalog;
  final BuildingRoomHeatLossResult? roomResult;
  final List<HouseEnvelopeElement> elements;
  final List<EnvelopeOpening> openings;
  final Map<String, BuildingElementHeatLossResult> elementResultsById;
  final Map<String, List<EnvelopeOpening>> openingsByElementId;
  final Map<String, Construction> constructionById;
  final Map<RoomSide, List<HouseEnvelopeElement>> wallElementsBySide;
  final double insideTemperature;
  final double outsideTemperature;
  final double grossEnvelopeArea;
  final double opaqueEnvelopeArea;
  final HouseEnvelopeElement? thermocalcElement;
  final List<HouseEnvelopeElement> missingConstructionElements;

  static BuildingRoomHeatLossResult? _findRoomResult(
    BuildingHeatLossResult? heatLoss,
    String roomId,
  ) {
    if (heatLoss == null) {
      return null;
    }
    for (final result in heatLoss.roomResults) {
      if (result.room.id == roomId) {
        return result;
      }
    }
    return null;
  }

  static RoomKindCondition? _findRoomKindCondition(
    CatalogSnapshot catalog,
    RoomKind roomKind,
  ) {
    final key = roomKind.storageKey;
    for (final condition in catalog.roomKindConditions) {
      if (condition.roomKindId == key) {
        return condition;
      }
    }
    return null;
  }

  static ClimatePoint? _findClimate(Project project, CatalogSnapshot catalog) {
    for (final climate in catalog.climatePoints) {
      if (climate.id == project.climatePointId) {
        return climate;
      }
    }
    return null;
  }
}
