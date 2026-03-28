import 'package:flutter/material.dart';

import '../../../../core/models/building_heat_loss.dart';
import '../../../../core/models/catalog.dart';
import '../../../../core/models/project.dart';

class HeatingDevicesCard extends StatelessWidget {
  const HeatingDevicesCard({
    super.key,
    required this.project,
    required this.catalog,
    required this.summary,
    required this.selectedRoomId,
    required this.onSelectRoom,
    required this.onAddHeatingDevice,
    required this.onEditHeatingDevice,
    required this.onDeleteHeatingDevice,
  });

  final Project project;
  final CatalogSnapshot catalog;
  final BuildingHeatLossResult? summary;
  final String? selectedRoomId;
  final ValueChanged<String> onSelectRoom;
  final ValueChanged<Room> onAddHeatingDevice;
  final ValueChanged<HeatingDevice> onEditHeatingDevice;
  final ValueChanged<HeatingDevice> onDeleteHeatingDevice;

  @override
  Widget build(BuildContext context) {
    final roomSummaryMap = {
      for (final roomSummary
          in summary?.roomResults ?? const <BuildingRoomHeatLossResult>[])
        roomSummary.room.id: roomSummary,
    };

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
                    'Отопительные приборы',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                FilledButton.tonal(
                  onPressed: () {
                    final room = project.houseModel.rooms.firstWhere(
                      (item) =>
                          item.id ==
                          (selectedRoomId ?? project.houseModel.rooms.first.id),
                      orElse: () => project.houseModel.rooms.first,
                    );
                    onAddHeatingDevice(room);
                  },
                  child: const Text('Добавить прибор'),
                ),
              ],
            ),
            if (catalog.heatingDevices.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Локальный каталог: ${catalog.heatingDevices.length} типовых приборов. Можно выбрать шаблон и вручную скорректировать мощность.',
              ),
            ],
            if (summary != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _HeatingBalanceBadge(
                    label: 'Всего приборов',
                    value: '${summary!.totalHeatingDeviceCount}',
                  ),
                  _HeatingBalanceBadge(
                    label: 'Установлено',
                    value:
                        '${summary!.totalInstalledHeatingPowerWatts.toStringAsFixed(0)} Вт',
                  ),
                  _HeatingBalanceBadge(
                    label: 'Баланс дома',
                    value:
                        '${summary!.totalHeatingPowerDeltaWatts.toStringAsFixed(0)} Вт',
                    tone: summary!.totalHeatingPowerDeltaWatts >= 0
                        ? const Color(0xFFD7EFD9)
                        : const Color(0xFFF5D8D6),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            ...project.houseModel.rooms.map((room) {
              final roomHeatingDevices = project.houseModel.heatingDevices
                  .where((item) => item.roomId == room.id)
                  .toList(growable: false);
              final roomSummary = roomSummaryMap[room.id];
              final isSelected = selectedRoomId == room.id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
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
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _HeatingBalanceBadge(
                                          label: 'Потери',
                                          value:
                                              '${(roomSummary?.heatLossWatts ?? 0).toStringAsFixed(0)} Вт',
                                        ),
                                        _HeatingBalanceBadge(
                                          label: 'Установлено',
                                          value:
                                              '${(roomSummary?.installedHeatingPowerWatts ?? 0).toStringAsFixed(0)} Вт',
                                        ),
                                        _HeatingBalanceBadge(
                                          label: 'Баланс',
                                          value:
                                              '${(roomSummary?.heatingPowerDeltaWatts ?? 0).toStringAsFixed(0)} Вт',
                                          tone:
                                              (roomSummary?.heatingPowerDeltaWatts ??
                                                      0) >=
                                                  0
                                              ? const Color(0xFFD7EFD9)
                                              : const Color(0xFFF5D8D6),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            FilledButton.tonal(
                              onPressed: () => onAddHeatingDevice(room),
                              child: const Text('Добавить'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (roomHeatingDevices.isEmpty)
                          const Text('Приборы еще не добавлены.')
                        else
                          ...roomHeatingDevices.map(
                            (heatingDevice) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                tileColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                title: Text(
                                  heatingDevice.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: Text(
                                  '${heatingDevice.kind.label} • ${heatingDevice.ratedPowerWatts.toStringAsFixed(0)} Вт'
                                  '${heatingDevice.catalogItemId == null ? '' : ' • ${heatingDevice.catalogItemId}'}'
                                  '${(heatingDevice.notes ?? '').trim().isEmpty ? '' : '\n${heatingDevice.notes!.trim()}'}',
                                ),
                                isThreeLine:
                                    (heatingDevice.notes ?? '').trim().isNotEmpty,
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      onEditHeatingDevice(heatingDevice);
                                    } else if (value == 'delete') {
                                      onDeleteHeatingDevice(heatingDevice);
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

class _HeatingBalanceBadge extends StatelessWidget {
  const _HeatingBalanceBadge({
    required this.label,
    required this.value,
    this.tone = const Color(0xFFFFFFFF),
  });

  final String label;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: tone,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Text(label),
        ],
      ),
    );
  }
}
