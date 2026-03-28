import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../construction_library/presentation/construction_step_screen.dart';
import '../../house_scheme/presentation/house_scheme_screen.dart';

class BuildingStepScreen extends ConsumerWidget {
  const BuildingStepScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectAsync = ref.watch(selectedProjectProvider);
    final summaryAsync = ref.watch(buildingHeatLossResultProvider);

    return HouseSchemeScreen(
      screenTitle: 'Шаг 2. Здание',
      statusText:
          'Шаг 2 использует только конструкции, выбранные на шаге 1. Здесь собирается схема здания из помещений и ограждений, а ниже показывается краткая оценка теплопотерь по дому.',
      limitToSelectedConstructions: true,
      showConstructionsCard: false,
      showHeatingDevices: false,
      trailingHeader: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Контроль шага 2',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              projectAsync.when(
                data: (project) => summaryAsync.when(
                  data: (summary) {
                    if (project == null || summary == null) {
                      return const Text('Активный проект не найден.');
                    }
                    final selectedCount =
                        project.effectiveSelectedConstructionIds.length;
                    final unresolvedCount = summary.unresolvedElements.length;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _MetricTile(
                          label: 'Доступные конструкции',
                          value: '$selectedCount',
                        ),
                        _MetricTile(
                          label: 'Помещения',
                          value: '${summary.totalRoomCount}',
                        ),
                        _MetricTile(
                          label: 'Ограждения',
                          value: '${summary.totalElementCount}',
                        ),
                        _MetricTile(
                          label: 'Оценка потерь',
                          value:
                              '${summary.totalHeatLossWatts.toStringAsFixed(0)} Вт',
                        ),
                        _MetricTile(
                          label: 'Без расчета',
                          value: '$unresolvedCount',
                        ),
                      ],
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (error, _) => Text('Ошибка сводки: $error'),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (error, _) => Text('Ошибка проекта: $error'),
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ConstructionStepScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.looks_one_outlined),
                label: const Text('Вернуться к шагу 1'),
              ),
            ],
          ),
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
