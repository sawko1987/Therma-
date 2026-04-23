import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/navigation/app_navigation.dart';
import '../../../core/models/project.dart';
import '../../../core/providers.dart';

class CalculationsHubScreen extends ConsumerWidget {
  const CalculationsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final objectAsync = ref.watch(selectedObjectProvider);
    final projectAsync = ref.watch(selectedProjectProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Расчёты')),
      body: objectAsync.when(
        data: (object) => projectAsync.when(
          data: (project) {
            if (object == null || project == null) {
              return _CalculationsEmptyState(
                onOpenProject: () => switchToTab(ref, AppTab.project),
              );
            }
            return _CalculationsBody(project: project);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Ошибка проекта: $error')),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Ошибка объекта: $error')),
      ),
    );
  }
}

class _CalculationsEmptyState extends StatelessWidget {
  const _CalculationsEmptyState({
    required this.onOpenProject,
  });

  final VoidCallback onOpenProject;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calculate_outlined,
                size: 56,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              const Text(
                'Сначала выберите активный объект во вкладке «Проект», после этого откроются модули расчёта.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onOpenProject,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Перейти в Проект'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalculationsBody extends StatelessWidget {
  const _CalculationsBody({
    required this.project,
  });

  final Project project;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const PageStorageKey<String>('calculations-hub-list'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  project.name,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Хаб расчётов собирает независимые инженерные модули. Здесь остаётся вход в Thermocalc, суммарные теплопотери, полы по грунту и отопительную экономику.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _CalculationTile(
          title: 'Thermocalc',
          description:
              'Теплотехника и влагорежим по выбранной конструкции или элементу.',
          icon: Icons.thermostat_outlined,
          onTap: () => openThermocalcScreen(context),
        ),
        const SizedBox(height: 12),
        _CalculationTile(
          title: 'Теплопотери здания',
          description:
              'Суммарные потери по всем помещениям, ограждениям и проёмам.',
          icon: Icons.home_repair_service_outlined,
          onTap: () => openBuildingHeatLossScreen(context),
        ),
        const SizedBox(height: 12),
        _CalculationTile(
          title: 'Полы по грунту',
          description:
              'Отдельные расчёты полов по грунту и связка с конструкциями пола.',
          icon: Icons.foundation_outlined,
          onTap: () => openGroundFloorScreen(context),
        ),
        const SizedBox(height: 12),
        _CalculationTile(
          title: 'Отопление и экономика',
          description:
              'Тарифы, сезонная стоимость и итоговая проверка сценария дома.',
          icon: Icons.savings_outlined,
          onTap: () => openHeatingEconomicsScreen(context),
        ),
      ],
    );
  }
}

class _CalculationTile extends StatelessWidget {
  const _CalculationTile({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        leading: Icon(icon, size: 28),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(description),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
