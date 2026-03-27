import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/project.dart';
import '../../../core/providers.dart';

class HouseSchemeScreen extends ConsumerWidget {
  const HouseSchemeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectAsync = ref.watch(selectedProjectProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Схема дома',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          const _StatusCard(),
          const SizedBox(height: 16),
          projectAsync.when(
            data: (project) {
              if (project == null) {
                return const Text('Активный проект не найден.');
              }
              return _HouseSchemeBody(project: project);
            },
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text('Ошибка загрузки проекта: $error'),
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
          'Phase 2 base: проект теперь хранит семантическую схему дома. Это каркас без графического редактора и без геометрии canvas.',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _HouseSchemeBody extends StatelessWidget {
  const _HouseSchemeBody({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final constructionMap = {
      for (final construction in project.constructions)
        construction.id: construction,
    };
    final houseModel = project.houseModel;

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  houseModel.title,
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
                      label: 'Элементы',
                      value: '${houseModel.elements.length}',
                    ),
                    _MetricTile(
                      label: 'Конструкции',
                      value: '${project.constructions.length}',
                    ),
                    _MetricTile(
                      label: 'Суммарная площадь',
                      value:
                          '${houseModel.totalAreaSquareMeters.toStringAsFixed(1)} м²',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Проект: ${project.name}'),
                Text('Помещение: ${project.roomPreset.label}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Элементы дома',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                ...houseModel.elements.map((element) {
                  final construction = constructionMap[element.constructionId];
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: element == houseModel.elements.last ? 0 : 12,
                    ),
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
                        element.title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${element.elementKind.label} • ${element.areaSquareMeters.toStringAsFixed(1)} м²\n'
                        'Конструкция: ${construction?.title ?? element.constructionId}',
                      ),
                      isThreeLine: true,
                      trailing: const Icon(Icons.account_tree_outlined),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
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
      width: 124,
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
