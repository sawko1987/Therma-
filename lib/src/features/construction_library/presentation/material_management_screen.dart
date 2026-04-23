import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/catalog.dart';
import '../../../core/providers.dart';
import 'construction_editor_sheet.dart';
import 'material_catalog_support.dart';

class MaterialManagementScreen extends ConsumerStatefulWidget {
  const MaterialManagementScreen({super.key});

  @override
  ConsumerState<MaterialManagementScreen> createState() =>
      _MaterialManagementScreenState();
}

class _MaterialManagementScreenState
    extends ConsumerState<MaterialManagementScreen> {
  MaterialFilterState _filter = const MaterialFilterState();

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(materialCatalogEntriesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Материалы'),
        actions: [
          IconButton(
            tooltip: 'Добавить свой материал',
            onPressed: _handleCreateMaterial,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: entriesAsync.when(
        data: (entries) {
          final filtered = filterMaterialCatalogEntries(entries, _filter);
          final categories =
              entries.map((item) => item.material.category).toSet().toList()
                ..sort();
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Каталог материалов',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Базовые и пользовательские материалы собраны в одном каталоге. Здесь можно фильтровать, добавлять свои материалы и управлять избранным.',
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        decoration: const InputDecoration(
                          labelText: 'Поиск по названию, тегам и категории',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (value) => setState(
                          () => _filter = _filter.copyWith(query: value),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: Text(
                              _filter.application?.label ?? 'Область',
                            ),
                            selected: _filter.application != null,
                            onSelected: (_) async {
                              final selected = await _showApplicationPicker(
                                context,
                                current: _filter.application,
                              );
                              setState(
                                () => _filter = selected == null
                                    ? _filter.copyWith(clearApplication: true)
                                    : _filter.copyWith(application: selected),
                              );
                            },
                          ),
                          FilterChip(
                            label: const Text('Избранные'),
                            selected: _filter.favoritesOnly,
                            onSelected: (value) => setState(
                              () => _filter = _filter.copyWith(
                                favoritesOnly: value,
                              ),
                            ),
                          ),
                          ChoiceChip(
                            label: Text(_filter.source.label),
                            selected: true,
                            onSelected: (_) async {
                              final selected = await _showSourcePicker(
                                context,
                                current: _filter.source,
                              );
                              if (selected != null) {
                                setState(
                                  () => _filter = _filter.copyWith(
                                    source: selected,
                                  ),
                                );
                              }
                            },
                          ),
                          ChoiceChip(
                            label: Text(_filter.category ?? 'Категория'),
                            selected: _filter.category != null,
                            onSelected: (_) async {
                              final selected = await _showCategoryPicker(
                                context,
                                categories: categories,
                                current: _filter.category,
                              );
                              setState(
                                () => _filter = selected == null
                                    ? _filter.copyWith(clearCategory: true)
                                    : _filter.copyWith(category: selected),
                              );
                            },
                          ),
                          FilterChip(
                            label: const Text('Низкая λ'),
                            selected: _filter.lambdaMax == 0.05,
                            onSelected: (value) => setState(
                              () => _filter = value
                                  ? _filter.copyWith(lambdaMax: 0.05)
                                  : _filter.copyWith(clearLambdaMax: true),
                            ),
                          ),
                          ActionChip(
                            label: Text(
                              _filter.hasActiveFilters
                                  ? 'Сбросить фильтры'
                                  : 'Фильтры',
                            ),
                            onPressed: () async {
                              if (_filter.hasActiveFilters) {
                                setState(
                                  () => _filter = const MaterialFilterState(),
                                );
                                return;
                              }
                              final updated = await showMaterialAdvancedFilters(
                                context,
                                filter: _filter,
                              );
                              if (updated != null) {
                                setState(() => _filter = updated);
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text('Найдено: ${filtered.length}'),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () async {
                              final updated = await showMaterialAdvancedFilters(
                                context,
                                filter: _filter,
                              );
                              if (updated != null) {
                                setState(() => _filter = updated);
                              }
                            },
                            icon: const Icon(Icons.tune),
                            label: const Text('Расширенные'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (filtered.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('Материалы по текущему фильтру не найдены.'),
                  ),
                )
              else
                ...filtered.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _MaterialCard(
                      entry: entry,
                      onToggleFavorite: () =>
                          _handleToggleFavorite(entry.material.id),
                      onEdit: () => _handleEditMaterial(entry),
                      onDelete: entry.isCustom && !entry.isSeedOverride
                          ? () => _handleDeleteMaterial(entry.material.id)
                          : null,
                      onRestore: entry.isSeedOverride
                          ? () => _handleRestoreSeedMaterial(entry.material.id)
                          : null,
                    ),
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Ошибка загрузки материалов: $error')),
      ),
    );
  }

  Future<void> _handleCreateMaterial() async {
    final messenger = ScaffoldMessenger.of(context);
    final created = await showMaterialEditor(context);
    if (!mounted || created == null) {
      return;
    }
    try {
      await ref.read(projectEditorProvider).saveCustomMaterial(created);
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _handleEditMaterial(MaterialCatalogEntry entry) async {
    final messenger = ScaffoldMessenger.of(context);
    final updated = await showMaterialEditor(
      context,
      material: entry.material,
      title: entry.isSeedOverride
          ? 'Редактирование измененного базового материала'
          : entry.isCustom
          ? 'Редактирование своего материала'
          : 'Настройка базового материала',
      saveLabel:
          entry.isCustom && !entry.isSeedOverride
              ? 'Сохранить материал'
              : 'Сохранить изменение',
    );
    if (!mounted || updated == null) {
      return;
    }
    try {
      await ref.read(projectEditorProvider).saveCustomMaterial(updated);
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _handleDeleteMaterial(String materialId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(projectEditorProvider).deleteCustomMaterial(materialId);
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _handleRestoreSeedMaterial(String materialId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(projectEditorProvider).restoreSeedMaterial(materialId);
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _handleToggleFavorite(String materialId) async {
    await ref.read(projectEditorProvider).toggleFavoriteMaterial(materialId);
  }
}

class _MaterialCard extends StatelessWidget {
  const _MaterialCard({
    required this.entry,
    required this.onToggleFavorite,
    this.onEdit,
    this.onDelete,
    this.onRestore,
  });

  final MaterialCatalogEntry entry;
  final VoidCallback onToggleFavorite;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    final material = entry.material;
    final sourceLabel = switch ((entry.isSeedOverride, entry.isCustom)) {
      (true, _) => 'Изменен',
      (false, true) => 'Свой',
      _ => 'Базовый',
    };
    final borderColor = switch ((entry.isSeedOverride, entry.isCustom)) {
      (true, _) => const Color(0xFFE0A11B),
      (false, true) => const Color(0xFF0F766E),
      _ => const Color(0xFFD9D4C7),
    };
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: borderColor,
          width: entry.isSeedOverride ? 2 : 1,
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
                  child: Text(
                    material.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: entry.isFavorite
                      ? 'Убрать из избранного'
                      : 'Добавить в избранное',
                  onPressed: onToggleFavorite,
                  icon: Icon(entry.isFavorite ? Icons.star : Icons.star_border),
                ),
                if (onEdit != null || onDelete != null || onRestore != null)
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          onEdit?.call();
                        case 'restore':
                          onRestore?.call();
                        case 'delete':
                          onDelete?.call();
                      }
                    },
                    itemBuilder: (context) => [
                      if (onEdit != null)
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Редактировать'),
                        ),
                      if (onRestore != null)
                        const PopupMenuItem(
                          value: 'restore',
                          child: Text('Восстановить базовый'),
                        ),
                      if (onDelete != null)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Удалить'),
                        ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text(material.category)),
                Chip(label: Text(sourceLabel)),
                if (material.subcategory != null)
                  Chip(label: Text(material.subcategory!)),
                if (material.manufacturer != null)
                  Chip(label: Text(material.manufacturer!)),
              ],
            ),
            if (material.applications.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: material.applications
                    .map((item) => Chip(label: Text(item.label)))
                    .toList(growable: false),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'λ ${material.thermalConductivity.toStringAsFixed(3)} • δ ${material.vaporPermeability.toStringAsFixed(3)}'
              '${material.densityKgM3 == null ? '' : ' • ρ ${material.densityKgM3!.toStringAsFixed(0)} кг/м³'}',
            ),
            if (material.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Теги: ${material.tags.join(', ')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (material.notes != null && material.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(material.notes!),
            ],
          ],
        ),
      ),
    );
  }
}

Future<MaterialSourceFilter?> _showSourcePicker(
  BuildContext context, {
  required MaterialSourceFilter current,
}) {
  return showModalBottomSheet<MaterialSourceFilter>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: MaterialSourceFilter.values
            .map(
              (item) => ListTile(
                leading: item == current ? const Icon(Icons.check) : null,
                title: Text(item.label),
                onTap: () => Navigator.of(context).pop(item),
              ),
            )
            .toList(growable: false),
      ),
    ),
  );
}

Future<String?> _showCategoryPicker(
  BuildContext context, {
  required List<String> categories,
  required String? current,
}) {
  return showModalBottomSheet<String>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: current == null ? const Icon(Icons.check) : null,
            title: const Text('Все категории'),
            onTap: () => Navigator.of(context).pop(),
          ),
          ...categories.map(
            (item) => ListTile(
              leading: item == current ? const Icon(Icons.check) : null,
              title: Text(item),
              onTap: () => Navigator.of(context).pop(item),
            ),
          ),
        ],
      ),
    ),
  );
}

Future<MaterialApplication?> _showApplicationPicker(
  BuildContext context, {
  required MaterialApplication? current,
}) {
  return showModalBottomSheet<MaterialApplication>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: current == null ? const Icon(Icons.check) : null,
            title: const Text('Все области'),
            onTap: () => Navigator.of(context).pop(),
          ),
          ...MaterialApplication.values.map(
            (item) => ListTile(
              leading: item == current ? const Icon(Icons.check) : null,
              title: Text(item.label),
              onTap: () => Navigator.of(context).pop(item),
            ),
          ),
        ],
      ),
    ),
  );
}
