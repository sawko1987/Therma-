import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/building_heat_loss.dart';
import '../../../core/providers.dart';

class BuildingHeatLossScreen extends ConsumerWidget {
  const BuildingHeatLossScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectAsync = ref.watch(selectedProjectProvider);
    final resultAsync = ref.watch(buildingHeatLossResultProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Теплопотери здания',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          resultAsync.when(
            data: (result) => projectAsync.when(
              data: (project) {
                if (project == null || result == null) {
                  return const Text('Активный проект не найден.');
                }
                return _ResultBody(
                  projectName: project.name,
                  result: result,
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text('Ошибка проекта: $error'),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text('Ошибка расчета: $error'),
          ),
        ],
      ),
    );
  }
}

class _ResultBody extends StatelessWidget {
  const _ResultBody({
    required this.projectName,
    required this.result,
  });

  final String projectName;
  final BuildingHeatLossResult result;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  projectName,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Суммарный расчёт v1 учитывает потери через непрозрачные участки ограждений и проемы по всей собранной планировке дома.',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _MetricTile(
                      label: 'Итого потерь',
                      value: '${result.totalHeatLossWatts.toStringAsFixed(0)} Вт',
                    ),
                    _MetricTile(
                      label: 'Через ограждения',
                      value:
                          '${result.totalOpaqueHeatLossWatts.toStringAsFixed(0)} Вт',
                    ),
                    _MetricTile(
                      label: 'Через проемы',
                      value:
                          '${result.totalOpeningHeatLossWatts.toStringAsFixed(0)} Вт',
                    ),
                    _MetricTile(
                      label: 'Баланс отопления',
                      value:
                          '${result.totalHeatingPowerDeltaWatts.toStringAsFixed(0)} Вт',
                    ),
                    _MetricTile(
                      label: 'Наружная температура',
                      value:
                          '${result.outsideAirTemperature.toStringAsFixed(0)} °C',
                    ),
                  ],
                ),
                if (result.unresolvedElements.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Пропущены элементы без конструкции: '
                    '${result.unresolvedElements.map((item) => item.title).join(', ')}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...result.roomResults.map((roomResult) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _RoomResultCard(roomResult: roomResult),
          );
        }),
      ],
    );
  }
}

class _RoomResultCard extends StatelessWidget {
  const _RoomResultCard({required this.roomResult});

  final BuildingRoomHeatLossResult roomResult;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              roomResult.room.title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _MetricTile(
                  label: 'Потери комнаты',
                  value: '${roomResult.heatLossWatts.toStringAsFixed(0)} Вт',
                ),
                _MetricTile(
                  label: 'Уставка внутри',
                  value:
                      '${roomResult.insideAirTemperature.toStringAsFixed(0)} °C',
                ),
                _MetricTile(
                  label: 'Ограждения',
                  value: '${roomResult.elementCount}',
                ),
                _MetricTile(
                  label: 'Проемы',
                  value:
                      '${roomResult.openingCount} / ${roomResult.totalOpeningAreaSquareMeters.toStringAsFixed(1)} м²',
                ),
                _MetricTile(
                  label: 'Баланс отопления',
                  value:
                      '${roomResult.heatingPowerDeltaWatts.toStringAsFixed(0)} Вт',
                ),
              ],
            ),
            if (roomResult.unresolvedElements.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Без расчета: ${roomResult.unresolvedElements.map((item) => item.title).join(', ')}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 12),
            ...roomResult.elementResults.map((elementResult) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ElementResultTile(elementResult: elementResult),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _ElementResultTile extends StatelessWidget {
  const _ElementResultTile({required this.elementResult});

  final BuildingElementHeatLossResult elementResult;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F5EE),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              elementResult.element.title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(elementResult.construction.title),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _MetricTile(
                  label: 'Итого',
                  value:
                      '${elementResult.totalHeatLossWatts.toStringAsFixed(0)} Вт',
                ),
                _MetricTile(
                  label: 'Непрозрачная часть',
                  value:
                      '${elementResult.opaqueHeatLossWatts.toStringAsFixed(0)} Вт',
                ),
                _MetricTile(
                  label: 'Проемы',
                  value:
                      '${elementResult.openingHeatLossWatts.toStringAsFixed(0)} Вт',
                ),
                _MetricTile(
                  label: 'ΔT',
                  value: '${elementResult.deltaTemperature.toStringAsFixed(0)} °C',
                ),
                _MetricTile(
                  label: 'R конструкции',
                  value:
                      '${elementResult.totalResistance.toStringAsFixed(2)} м²·°C/Вт',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(label),
        ],
      ),
    );
  }
}
