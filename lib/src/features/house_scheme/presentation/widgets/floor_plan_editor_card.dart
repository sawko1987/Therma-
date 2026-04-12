import 'package:flutter/material.dart';

import '../../../../core/models/project.dart';
import '../floor_plan_geometry.dart';

class FloorPlanEditorCard extends StatelessWidget {
  const FloorPlanEditorCard({
    super.key,
    required this.project,
    required this.selectedRoomId,
    required this.selectedElementId,
    required this.onAddRoom,
    required this.onSelectRoom,
    required this.onSelectElement,
    required this.onUpdateRoomLayout,
    required this.onUpdateElementWallPlacement,
  });

  final Project project;
  final String? selectedRoomId;
  final String? selectedElementId;
  final VoidCallback onAddRoom;
  final ValueChanged<String> onSelectRoom;
  final void Function(String elementId, String roomId) onSelectElement;
  final Future<String?> Function(String roomId, RoomLayoutRect layout)
  onUpdateRoomLayout;
  final Future<String?> Function(
    HouseEnvelopeElement element,
    EnvelopeWallPlacement wallPlacement,
  )
  onUpdateElementWallPlacement;

  @override
  Widget build(BuildContext context) {
    final rooms = project.houseModel.rooms;
    final selectedRoom = rooms
        .where((room) => room.id == selectedRoomId)
        .firstOrNull;
    final elementsForSelectedRoom = selectedRoom == null
        ? const <HouseEnvelopeElement>[]
        : project.houseModel.elements
              .where((element) => element.roomId == selectedRoom.id)
              .toList(growable: false);

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
                    'Планировочная схема',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: onAddRoom,
                  icon: const Icon(Icons.add),
                  label: const Text('Комната'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Временный редактор планировки: можно выбрать комнату, сдвинуть ее вниз или вправо и подправить размещение стеновых ограждений. Этого достаточно, чтобы экран снова был рабочим, пока полноценный floor plan редактор восстанавливается.',
            ),
            const SizedBox(height: 16),
            if (rooms.isEmpty)
              const Text('В проекте пока нет помещений.')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: rooms
                    .map(
                      (room) => ChoiceChip(
                        label: Text(
                          '${room.title} • ${room.layout.widthMeters.toStringAsFixed(1)}×${room.layout.heightMeters.toStringAsFixed(1)} м',
                        ),
                        selected: room.id == selectedRoom?.id,
                        onSelected: (_) => onSelectRoom(room.id),
                      ),
                    )
                    .toList(growable: false),
              ),
            if (selectedRoom != null) ...[
              const SizedBox(height: 16),
              _RoomLayoutCard(
                room: selectedRoom,
                onUpdateRoomLayout: onUpdateRoomLayout,
              ),
            ],
            if (elementsForSelectedRoom.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Ограждения комнаты',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              ...elementsForSelectedRoom.map(
                (element) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ElementPlacementTile(
                    element: element,
                    selected: element.id == selectedElementId,
                    onSelect: () => onSelectElement(element.id, element.roomId),
                    onUpdateElementWallPlacement: onUpdateElementWallPlacement,
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

class _RoomLayoutCard extends StatelessWidget {
  const _RoomLayoutCard({required this.room, required this.onUpdateRoomLayout});

  final Room room;
  final Future<String?> Function(String roomId, RoomLayoutRect layout)
  onUpdateRoomLayout;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F4ED),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            room.title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Позиция: ${room.layout.xMeters.toStringAsFixed(1)} / ${room.layout.yMeters.toStringAsFixed(1)} м'
            '\nРазмер: ${room.layout.widthMeters.toStringAsFixed(1)} × ${room.layout.heightMeters.toStringAsFixed(1)} м',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => onUpdateRoomLayout(
                  room.id,
                  room.layout.copyWith(
                    xMeters: room.layout.xMeters + roomLayoutSnapStepMeters,
                  ),
                ),
                icon: const Icon(Icons.arrow_right_alt),
                label: const Text('Сдвинуть вправо'),
              ),
              OutlinedButton.icon(
                onPressed: () => onUpdateRoomLayout(
                  room.id,
                  room.layout.copyWith(
                    yMeters: room.layout.yMeters + roomLayoutSnapStepMeters,
                  ),
                ),
                icon: const Icon(Icons.arrow_downward),
                label: const Text('Сдвинуть вниз'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ElementPlacementTile extends StatelessWidget {
  const _ElementPlacementTile({
    required this.element,
    required this.selected,
    required this.onSelect,
    required this.onUpdateElementWallPlacement,
  });

  final HouseEnvelopeElement element;
  final bool selected;
  final VoidCallback onSelect;
  final Future<String?> Function(
    HouseEnvelopeElement element,
    EnvelopeWallPlacement wallPlacement,
  )
  onUpdateElementWallPlacement;

  @override
  Widget build(BuildContext context) {
    final placement = element.wallPlacement;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        onTap: onSelect,
        title: Text(element.title),
        subtitle: Text(
          placement == null
              ? element.elementKind.label
              : '${placement.side.label} • offset ${placement.offsetMeters.toStringAsFixed(1)} м • длина ${placement.lengthMeters.toStringAsFixed(1)} м',
        ),
        trailing: placement == null
            ? null
            : PopupMenuButton<String>(
                onSelected: (value) {
                  final sideLength =
                      placement.lengthMeters + roomLayoutGapMeters;
                  switch (value) {
                    case 'left':
                      onUpdateElementWallPlacement(
                        element,
                        snapWallPlacement(
                          placement.copyWith(
                            offsetMeters:
                                placement.offsetMeters -
                                roomLayoutSnapStepMeters,
                          ),
                          sideLength: sideLength,
                        ),
                      );
                    case 'right':
                      onUpdateElementWallPlacement(
                        element,
                        snapWallPlacement(
                          placement.copyWith(
                            offsetMeters:
                                placement.offsetMeters +
                                roomLayoutSnapStepMeters,
                          ),
                          sideLength: sideLength,
                        ),
                      );
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'left',
                    child: Text('Сместить к началу стены'),
                  ),
                  PopupMenuItem(
                    value: 'right',
                    child: Text('Сместить к концу стены'),
                  ),
                ],
              ),
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
