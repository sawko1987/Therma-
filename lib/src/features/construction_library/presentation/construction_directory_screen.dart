import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/calculation.dart';
import '../../../core/models/catalog.dart';
import '../../../core/models/project.dart';
import '../../../core/providers.dart';
import '../../thermocalc/presentation/thermocalc_screen.dart';
import 'construction_editor_sheet.dart';

enum ConstructionSaveTarget { projectOnly, libraryAndProject }

class ConstructionDirectoryScreen extends ConsumerStatefulWidget {
  const ConstructionDirectoryScreen({super.key});

  @override
  ConsumerState<ConstructionDirectoryScreen> createState() =>
      _ConstructionDirectoryScreenState();
}

class _ConstructionDirectoryScreenState
    extends ConsumerState<ConstructionDirectoryScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(catalogSnapshotProvider);
    final materialEntriesAsync = ref.watch(materialCatalogEntriesProvider);
    final libraryAsync = ref.watch(constructionLibraryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Справочник конструкций'),
        actions: [
          IconButton(
            tooltip: 'Создать конструкцию',
            onPressed: _handleCreate,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: catalogAsync.when(
        data: (catalog) => materialEntriesAsync.when(
          data: (materialEntries) => libraryAsync.when(
            data: (library) {
              final seededIds = catalog.constructionTemplates
                  .map((item) => item.id)
                  .toSet();
              final materialMap = {
                for (final entry in materialEntries)
                  entry.material.id: entry.material,
              };
              final filtered = _filterConstructions(library, query: _query);
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
                            'Справочник конструкций',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Здесь собрана вся библиотека конструкций проекта. В списке показываются только названия, а детали и расчет открываются по кнопке информации.',
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            decoration: const InputDecoration(
                              labelText: 'Поиск по названию',
                              prefixIcon: Icon(Icons.search),
                            ),
                            onChanged: (value) =>
                                setState(() => _query = value),
                          ),
                          const SizedBox(height: 12),
                          Text('Найдено: ${filtered.length}'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (filtered.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _query.trim().isEmpty
                                  ? 'В библиотеке пока нет пользовательских конструкций.'
                                  : 'Конструкции по текущему фильтру не найдены.',
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: _handleCreate,
                              icon: const Icon(Icons.add),
                              label: const Text('Создать конструкцию'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...filtered.map(
                      (construction) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ConstructionDirectoryRow(
                          construction: construction,
                          sourceLabel: seededIds.contains(construction.id)
                              ? 'Шаблон'
                              : 'Моя',
                          showDelete: !seededIds.contains(construction.id),
                          onInfo: () => showConstructionInfoSheet(
                            context,
                            construction: construction,
                            materialMap: materialMap,
                          ),
                          onEdit: () => _handleEdit(
                            catalog,
                            materialEntries,
                            construction,
                          ),
                          onDelete: seededIds.contains(construction.id)
                              ? null
                              : () => _handleDelete(construction.id),
                        ),
                      ),
                    ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) =>
                Center(child: Text('Ошибка загрузки библиотеки: $error')),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              Center(child: Text('Ошибка загрузки материалов: $error')),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Ошибка загрузки каталога: $error')),
      ),
    );
  }

  Future<void> _handleCreate() async {
    final catalog = await ref.read(catalogSnapshotProvider.future);
    final materialEntries = await ref.read(
      materialCatalogEntriesProvider.future,
    );
    if (!mounted) {
      return;
    }
    final created = await showConstructionEditor(
      context,
      catalog: catalog,
      materialEntries: materialEntries,
      onSaveCustomMaterial: (material) async {
        await ref.read(projectEditorProvider).saveCustomMaterial(material);
        return material;
      },
    );
    if (!mounted || created == null) {
      return;
    }
    try {
      await ref.read(projectEditorProvider).saveConstructionToLibrary(created);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_humanizeError(error))));
    }
  }

  Future<void> _handleEdit(
    CatalogSnapshot catalog,
    List<MaterialCatalogEntry> materialEntries,
    Construction construction,
  ) async {
    if (!mounted) {
      return;
    }
    final updated = await showConstructionEditor(
      context,
      catalog: catalog,
      materialEntries: materialEntries,
      construction: construction,
      onSaveCustomMaterial: (material) async {
        await ref.read(projectEditorProvider).saveCustomMaterial(material);
        return material;
      },
    );
    if (!mounted || updated == null) {
      return;
    }
    try {
      await ref.read(projectEditorProvider).updateLibraryConstruction(updated);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_humanizeError(error))));
    }
  }

  Future<void> _handleDelete(String constructionId) async {
    try {
      await ref
          .read(projectEditorProvider)
          .deleteConstructionFromLibrary(constructionId);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_humanizeError(error))));
    }
  }
}

class _ConstructionDirectoryRow extends StatelessWidget {
  const _ConstructionDirectoryRow({
    required this.construction,
    required this.sourceLabel,
    required this.showDelete,
    required this.onInfo,
    required this.onEdit,
    this.onDelete,
  });

  final Construction construction;
  final String sourceLabel;
  final bool showDelete;
  final VoidCallback onInfo;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Row(
          children: [
            Expanded(
              child: Text(
                construction.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            _ConstructionSourceBadge(label: sourceLabel),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(_constructionSummary(construction)),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Информация',
              onPressed: onInfo,
              icon: const Icon(Icons.info_outline),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    onEdit();
                  case 'delete':
                    onDelete?.call();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Text('Редактировать'),
                ),
                if (showDelete)
                  const PopupMenuItem(value: 'delete', child: Text('Удалить')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showConstructionPickerModal(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _ConstructionPickerSheet(),
  );
}

class _ConstructionPickerSheet extends ConsumerStatefulWidget {
  const _ConstructionPickerSheet();

  @override
  ConsumerState<_ConstructionPickerSheet> createState() =>
      _ConstructionPickerSheetState();
}

class _ConstructionPickerSheetState
    extends ConsumerState<_ConstructionPickerSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tutorialController;

  String _query = '';
  bool _showTutorial = false;
  bool _autoTutorialHandled = false;
  bool _markingTutorialSeen = false;

  @override
  void initState() {
    super.initState();
    _tutorialController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _tutorialController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(catalogSnapshotProvider);
    final materialEntriesAsync = ref.watch(materialCatalogEntriesProvider);
    final libraryAsync = ref.watch(constructionLibraryProvider);
    final tutorialSeenAsync = ref.watch(
      constructionPickerSwipeTutorialSeenProvider,
    );

    return FractionallySizedBox(
      heightFactor: 0.92,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: catalogAsync.when(
          data: (catalog) => materialEntriesAsync.when(
            data: (materialEntries) => libraryAsync.when(
              data: (library) => tutorialSeenAsync.when(
                data: (tutorialSeen) => _buildLoadedState(
                  context,
                  catalog: catalog,
                  materialEntries: materialEntries,
                  library: library,
                  tutorialSeen: tutorialSeen,
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) =>
                    Center(child: Text('Ошибка загрузки настроек: $error')),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('Ошибка загрузки библиотеки: $error')),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) =>
                Center(child: Text('Ошибка загрузки материалов: $error')),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              Center(child: Text('Ошибка загрузки каталога: $error')),
        ),
      ),
    );
  }

  Widget _buildLoadedState(
    BuildContext context, {
    required CatalogSnapshot catalog,
    required List<MaterialCatalogEntry> materialEntries,
    required List<Construction> library,
    required bool tutorialSeen,
  }) {
    final seededIds = catalog.constructionTemplates
        .map((item) => item.id)
        .toSet();
    final materialMap = {
      for (final entry in materialEntries) entry.material.id: entry.material,
    };
    final filtered = _filterConstructions(library, query: _query);
    final hasSwipeableItems = filtered.any(
      (construction) => !seededIds.contains(construction.id),
    );

    if (!_autoTutorialHandled && !tutorialSeen && hasSwipeableItems) {
      _autoTutorialHandled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _setTutorialVisible(true);
        unawaited(_markTutorialSeen());
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Добавить конструкцию',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text(
          'Выберите готовую конструкцию, создайте новую или удалите свою из общей библиотеки прямо здесь.',
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: () => _handleCreate(context, catalog, materialEntries),
              icon: const Icon(Icons.add),
              label: const Text('Создать конструкцию'),
            ),
            OutlinedButton.icon(
              onPressed: hasSwipeableItems
                  ? () => _setTutorialVisible(!_showTutorial)
                  : null,
              icon: const Icon(Icons.help_outline),
              label: const Text('Помощь'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Поиск по названию',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        if (_showTutorial && hasSwipeableItems) ...[
          const SizedBox(height: 16),
          _SwipeTutorialCard(
            controller: _tutorialController,
            onClose: () => _setTutorialVisible(false),
          ),
        ],
        const SizedBox(height: 16),
        Expanded(
          child: filtered.isEmpty
              ? _PickerEmptyState(
                  isFiltered: _query.trim().isNotEmpty,
                  onCreate: () =>
                      _handleCreate(context, catalog, materialEntries),
                )
              : ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final construction = filtered[index];
                    final isTemplate = seededIds.contains(construction.id);
                    final row = _PickerConstructionRow(
                      construction: construction,
                      sourceLabel: isTemplate ? 'Шаблон' : 'Моя',
                      onTap: () =>
                          _handleSelect(context, construction: construction),
                      onCopy: () => _handleCopy(
                        context,
                        construction: construction,
                        materialEntries: materialEntries,
                      ),
                      onInfo: () => showConstructionInfoSheet(
                        context,
                        construction: construction,
                        materialMap: materialMap,
                      ),
                    );
                    if (isTemplate) {
                      return row;
                    }
                    return Dismissible(
                      key: ValueKey('picker-construction-${construction.id}'),
                      direction: DismissDirection.endToStart,
                      background: const _SwipeDeleteBackground(),
                      confirmDismiss: (_) =>
                          _confirmDelete(context, construction: construction),
                      child: row,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _handleCreate(
    BuildContext context,
    CatalogSnapshot catalog,
    List<MaterialCatalogEntry> materialEntries,
  ) async {
    final created = await showConstructionEditor(
      context,
      catalog: catalog,
      materialEntries: materialEntries,
      onSaveCustomMaterial: (material) async {
        await ref.read(projectEditorProvider).saveCustomMaterial(material);
        return material;
      },
    );
    if (!mounted || created == null) {
      return;
    }
    try {
      await ref.read(projectEditorProvider).addConstruction(created);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _handleSelect(
    BuildContext context, {
    required Construction construction,
  }) async {
    try {
      await ref
          .read(projectEditorProvider)
          .selectConstructionForProject(construction);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _handleCopy(
    BuildContext context, {
    required Construction construction,
    required List<MaterialCatalogEntry> materialEntries,
  }) async {
    final draft = construction.copyWith(
      id: buildEditorEntityId('construction'),
      title: '${construction.title} (копия)',
      layers: [
        for (final layer in construction.layers)
          layer.copyWith(id: buildEditorEntityId('layer')),
      ],
    );
    final copied = await showQuickConstructionCopyEditor(
      context,
      construction: draft,
      materialEntries: materialEntries,
      onSaveCustomMaterial: (material) async {
        await ref.read(projectEditorProvider).saveCustomMaterial(material);
        return material;
      },
    );
    if (!mounted || copied == null) {
      return;
    }
    final target = await showConstructionSaveTargetSheet(context);
    if (!mounted || target == null) {
      return;
    }
    try {
      switch (target) {
        case ConstructionSaveTarget.projectOnly:
          await ref
              .read(projectEditorProvider)
              .addProjectOnlyConstruction(copied);
        case ConstructionSaveTarget.libraryAndProject:
          await ref.read(projectEditorProvider).addConstruction(copied);
      }
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      _showError(error);
    }
  }

  Future<bool> _confirmDelete(
    BuildContext context, {
    required Construction construction,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить конструкцию?'),
        content: Text(
          'Конструкция "${construction.title}" будет удалена из общей библиотеки.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return false;
    }
    try {
      await ref
          .read(projectEditorProvider)
          .deleteConstructionFromLibrary(construction.id);
      return true;
    } catch (error) {
      _showError(error);
      return false;
    }
  }

  Future<void> _markTutorialSeen() async {
    if (_markingTutorialSeen) {
      return;
    }
    _markingTutorialSeen = true;
    try {
      await ref
          .read(appPreferencesRepositoryProvider)
          .setConstructionPickerSwipeTutorialSeen(true);
      ref.invalidate(constructionPickerSwipeTutorialSeenProvider);
    } finally {
      _markingTutorialSeen = false;
    }
  }

  void _showError(Object error) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_humanizeError(error))));
  }

  void _setTutorialVisible(bool visible) {
    if (!mounted) {
      return;
    }
    if (visible) {
      _tutorialController
        ..value = 0
        ..repeat(reverse: true);
    } else {
      _tutorialController
        ..stop()
        ..value = 0;
    }
    setState(() => _showTutorial = visible);
  }
}

class _PickerEmptyState extends StatelessWidget {
  const _PickerEmptyState({required this.isFiltered, required this.onCreate});

  final bool isFiltered;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isFiltered
                    ? 'По текущему запросу ничего не найдено.'
                    : 'В библиотеке пока нет конструкций.',
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add),
                label: const Text('Создать конструкцию'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickerConstructionRow extends StatelessWidget {
  const _PickerConstructionRow({
    required this.construction,
    required this.sourceLabel,
    required this.onTap,
    required this.onCopy,
    required this.onInfo,
  });

  final Construction construction;
  final String sourceLabel;
  final VoidCallback onTap;
  final VoidCallback onCopy;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Row(
          children: [
            Expanded(
              child: Text(
                construction.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            _ConstructionSourceBadge(label: sourceLabel),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(_constructionSummary(construction)),
        ),
        onTap: onTap,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Копировать',
              onPressed: onCopy,
              icon: const Icon(Icons.content_copy_outlined),
            ),
            IconButton(
              tooltip: 'Информация',
              onPressed: onInfo,
              icon: const Icon(Icons.info_outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConstructionSourceBadge extends StatelessWidget {
  const _ConstructionSourceBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isTemplate = label == 'Шаблон';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isTemplate ? const Color(0xFFEAF1FB) : const Color(0xFFEAF3F0),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _SwipeDeleteBackground extends StatelessWidget {
  const _SwipeDeleteBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFB3261E),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: Alignment.centerRight,
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.delete_outline, color: Colors.white),
          SizedBox(width: 8),
          Text(
            'Удалить',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _SwipeTutorialCard extends StatelessWidget {
  const _SwipeTutorialCard({required this.controller, required this.onClose});

  final AnimationController controller;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F1E6),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Свайп влево удаляет вашу конструкцию из библиотеки',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                tooltip: 'Скрыть подсказку',
                onPressed: onClose,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Шаблоны не удаляются. Для своих конструкций проведите строку влево и подтвердите удаление.',
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 72,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: const Color(0xFFB3261E),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    alignment: Alignment.centerRight,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete_outline, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Удалить',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedBuilder(
                    animation: controller,
                    builder: (context, child) {
                      final slide = Tween<double>(
                        begin: 0,
                        end: -96,
                      ).transform(Curves.easeInOut.transform(controller.value));
                      return Transform.translate(
                        offset: Offset(slide, 0),
                        child: child,
                      );
                    },
                    child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Моя стена с утеплением',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  'Свайпните влево',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.swipe_left_outlined),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<ConstructionSaveTarget?> showConstructionSaveTargetSheet(
  BuildContext context,
) {
  return showModalBottomSheet<ConstructionSaveTarget>(
    context: context,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Куда сохранить конструкцию?',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'После быстрой правки решите, нужна ли эта копия только для текущего проекта или её надо добавить и в общий справочник.',
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.folder_copy_outlined),
              title: const Text('Только для этого проекта'),
              subtitle: const Text('Не добавлять в общий справочник'),
              onTap: () =>
                  Navigator.of(context).pop(ConstructionSaveTarget.projectOnly),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.library_add_outlined),
              title: const Text('Добавить в справочник и в проект'),
              subtitle: const Text(
                'Сохранить в библиотеку для повторного выбора',
              ),
              onTap: () => Navigator.of(
                context,
              ).pop(ConstructionSaveTarget.libraryAndProject),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<Construction?> showQuickConstructionCopyEditor(
  BuildContext context, {
  required Construction construction,
  required List<MaterialCatalogEntry> materialEntries,
  CustomMaterialSaver? onSaveCustomMaterial,
}) async {
  final titleController = TextEditingController(text: construction.title);
  final layers = [...construction.layers];
  final availableEntries = [...materialEntries];
  final availableMaterials = [
    for (final entry in availableEntries) entry.material,
  ];

  final result = await showModalBottomSheet<Construction>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          final materialMap = {
            for (final material in availableMaterials) material.id: material,
          };
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
                  'Быстрая копия конструкции',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Измените название и состав слоев. Остальные параметры копии сохраняются как у исходной конструкции.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Название'),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      'Слои',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () async {
                        final added = await showLayerEditor(
                          context,
                          materialEntries: availableEntries,
                          onSaveCustomMaterial: onSaveCustomMaterial,
                        );
                        if (added == null) {
                          return;
                        }
                        _upsertMaterialLocal(
                          availableMaterials,
                          added.material,
                        );
                        _upsertMaterialEntryLocal(
                          availableEntries,
                          MaterialCatalogEntry(
                            material: added.material,
                            source: added.material.isCustom
                                ? MaterialCatalogSource.custom
                                : MaterialCatalogSource.seed,
                            isFavorite: false,
                          ),
                        );
                        setState(() => layers.add(added.layer));
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
                              title: Text(
                                '${material?.name ?? layer.materialId} • ${layer.kind.label}',
                              ),
                              subtitle: Text(
                                '${layer.thicknessMm.toStringAsFixed(0)} мм'
                                '${layer.enabled ? '' : ' • выключен'}',
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) async {
                                  switch (value) {
                                    case 'edit':
                                      final updated = await showLayerEditor(
                                        context,
                                        materialEntries: availableEntries,
                                        layer: layer,
                                        onSaveCustomMaterial:
                                            onSaveCustomMaterial,
                                      );
                                      if (updated != null) {
                                        _upsertMaterialLocal(
                                          availableMaterials,
                                          updated.material,
                                        );
                                        _upsertMaterialEntryLocal(
                                          availableEntries,
                                          MaterialCatalogEntry(
                                            material: updated.material,
                                            source: updated.material.isCustom
                                                ? MaterialCatalogSource.custom
                                                : MaterialCatalogSource.seed,
                                            isFavorite: false,
                                          ),
                                        );
                                        layers[index] = updated.layer;
                                        setState(() {});
                                      }
                                    case 'delete':
                                      layers.removeAt(index);
                                      setState(() {});
                                  }
                                },
                                itemBuilder: (context) => const [
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
                            construction.copyWith(
                              title: requiredEditorText(
                                titleController.text,
                                fallback: construction.title,
                              ),
                              layers: List.unmodifiable(layers),
                            ),
                          );
                        },
                  child: const Text('Продолжить'),
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

Future<void> showConstructionInfoSheet(
  BuildContext context, {
  required Construction construction,
  required Map<String, MaterialEntry> materialMap,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => Consumer(
      builder: (context, ref, _) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  construction.title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(_constructionSummary(construction)),
                const SizedBox(height: 16),
                Text(
                  'Состав',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                ...construction.layers.map(
                  (layer) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F4ED),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        '${materialMap[layer.materialId]?.name ?? layer.materialId} • ${layer.kind.label} • ${layer.thicknessMm.toStringAsFixed(0)} мм'
                        '${layer.enabled ? '' : ' • выключен'}',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ConstructionCalculationPanel(constructionId: construction.id),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class ConstructionCalculationPanel extends ConsumerWidget {
  const ConstructionCalculationPanel({super.key, required this.constructionId});

  final String constructionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calculationAsync = ref.watch(
      calculationResultForConstructionProvider(constructionId),
    );

    return calculationAsync.when(
      data: (result) {
        if (result == null) {
          return _InfoBox(
            child: _OpenCalculationButton(constructionId: constructionId),
          );
        }

        return _InfoBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text(result.scenarioStatus.label)),
                  Chip(
                    label: Text(
                      'R ${result.totalResistance.toStringAsFixed(2)} / ${result.requiredResistance.toStringAsFixed(2)}',
                    ),
                  ),
                  Chip(label: Text(result.moistureCheck.verdict.label)),
                ],
              ),
              const SizedBox(height: 8),
              Text(result.scenarioMessage),
              const SizedBox(height: 8),
              Text(result.moistureCheck.summary),
              const SizedBox(height: 12),
              _OpenCalculationButton(constructionId: constructionId),
            ],
          ),
        );
      },
      loading: () => const _InfoBox(child: LinearProgressIndicator()),
      error: (error, _) => _InfoBox(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ошибка расчета: $error'),
            const SizedBox(height: 12),
            _OpenCalculationButton(constructionId: constructionId),
          ],
        ),
      ),
    );
  }
}

class _OpenCalculationButton extends ConsumerWidget {
  const _OpenCalculationButton({required this.constructionId});

  final String constructionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FilledButton.icon(
      onPressed: () {
        ref
            .read(selectedConstructionIdProvider.notifier)
            .select(constructionId);
        ref.read(selectedEnvelopeElementIdProvider.notifier).select(null);
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ThermocalcScreen(
              constructionId: constructionId,
              showElementContext: false,
            ),
          ),
        );
      },
      icon: const Icon(Icons.analytics_outlined),
      label: const Text('Открыть расчет'),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F4ED),
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }
}

List<Construction> _filterConstructions(
  List<Construction> constructions, {
  required String query,
}) {
  final normalized = query.trim().toLowerCase();
  return constructions
      .where((construction) {
        if (normalized.isEmpty) {
          return true;
        }
        return construction.title.toLowerCase().contains(normalized);
      })
      .toList(growable: false);
}

String _constructionSummary(Construction construction) {
  return [
    construction.elementKind.label,
    if (construction.floorConstructionType case final floorType?)
      floorType.label,
    if (construction.crawlSpaceVentilationMode case final ventilationMode?)
      ventilationMode.label,
    'слоев ${construction.layers.length}',
  ].join(' • ');
}

void _upsertMaterialEntryLocal(
  List<MaterialCatalogEntry> entries,
  MaterialCatalogEntry entry,
) {
  final index = entries.indexWhere(
    (item) => item.material.id == entry.material.id,
  );
  if (index == -1) {
    entries.add(entry);
    return;
  }
  entries[index] = entry;
}

void _upsertMaterialLocal(
  List<MaterialEntry> materials,
  MaterialEntry material,
) {
  final index = materials.indexWhere((item) => item.id == material.id);
  if (index == -1) {
    materials.add(material);
    return;
  }
  materials[index] = material;
}

String _humanizeError(Object error) {
  final text = error.toString();
  if (text.startsWith('Bad state: ')) {
    return text.substring('Bad state: '.length);
  }
  if (text.startsWith('StateError: ')) {
    return text.substring('StateError: '.length);
  }
  return text;
}
