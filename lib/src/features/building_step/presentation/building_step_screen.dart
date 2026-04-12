import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../building_heat_loss/presentation/building_heat_loss_screen.dart';
import '../../construction_library/presentation/construction_step_screen.dart';
import '../../house_scheme/presentation/house_scheme_screen.dart';

class BuildingStepScreen extends ConsumerWidget {
  const BuildingStepScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectAsync = ref.watch(selectedProjectProvider);
    final summaryAsync = ref.watch(buildingHeatLossResultProvider);

    return HouseSchemeScreen(
      screenTitle: 'Шаг 2. План дома',
      statusText:
          'После выбора ограждающих конструкций на шаге 1 здесь формируется план дома: помещения, ограждения и проёмы. Когда планировка собрана, можно сразу открыть расчёт суммарных теплопотерь по зданию.',
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
                'Контроль планировки',
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
                        project.activeSelectedConstructionIds.length;
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
                          label: 'Суммарные потери',
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
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const BuildingHeatLossScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.analytics_outlined),
                label: const Text('Открыть теплопотери здания'),
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
