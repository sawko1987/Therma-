import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/models/catalog.dart';
import '../../../core/models/project.dart';
import '../../../core/providers.dart';

class OpeningDirectoryScreen extends ConsumerStatefulWidget {
  const OpeningDirectoryScreen({super.key});

  @override
  ConsumerState<OpeningDirectoryScreen> createState() =>
      _OpeningDirectoryScreenState();
}

class _OpeningDirectoryScreenState
    extends ConsumerState<OpeningDirectoryScreen> {
  OpeningKind? _filterKind;

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(catalogSnapshotProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Справочник проёмов')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('Добавить'),
      ),
      body: catalogAsync.when(
        data: (catalog) {
          final entries = catalog.openingCatalog
              .where(
                (item) => _filterKind == null || item.kind == _filterKind,
              )
              .toList(growable: false);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Все'),
                    selected: _filterKind == null,
                    onSelected: (_) => setState(() => _filterKind = null),
                  ),
                  ...OpeningKind.values.map(
                    (kind) => ChoiceChip(
                      label: Text(kind.label),
                      selected: _filterKind == kind,
                      onSelected: (_) => setState(() => _filterKind = kind),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...entries.map(
                (entry) => Card(
                  child: ListTile(
                    leading: _OpeningPreview(entry: entry),
                    title: Text(entry.title),
                    subtitle: Text(
                      '${entry.kind.label} • ${entry.subcategory} • ${entry.widthMeters.toStringAsFixed(2)}×${entry.heightMeters.toStringAsFixed(2)} м • U ${entry.heatTransferCoefficient.toStringAsFixed(2)}',
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'edit') {
                          await _openEditor(context, entry: entry);
                        } else if (value == 'delete' && entry.isCustom) {
                          await ref
                              .read(projectEditorProvider)
                              .deleteOpeningCatalogEntry(entry.id);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Редактировать'),
                        ),
                        if (entry.isCustom)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Удалить'),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Ошибка каталога: $error')),
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context, {
    OpeningCatalogEntry? entry,
  }) async {
    final edited = await showOpeningCatalogEditorSheet(context, entry: entry);
    if (!mounted || edited == null) {
      return;
    }
    await ref.read(projectEditorProvider).saveOpeningCatalogEntry(edited);
  }
}

class _OpeningPreview extends StatelessWidget {
  const _OpeningPreview({required this.entry});

  final OpeningCatalogEntry entry;

  @override
  Widget build(BuildContext context) {
    final imagePath = entry.localImagePath;
    if (imagePath != null && File(imagePath).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(imagePath),
          width: 56,
          height: 56,
          fit: BoxFit.cover,
        ),
      );
    }
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: const Color(0xFFEDE7D8),
      ),
      child: Icon(
        entry.kind == OpeningKind.window
            ? Icons.window_outlined
            : Icons.door_front_door_outlined,
      ),
    );
  }
}

Future<OpeningCatalogEntry?> showOpeningCatalogEditorSheet(
  BuildContext context, {
  OpeningCatalogEntry? entry,
}) async {
  final titleController = TextEditingController(text: entry?.title ?? '');
  final subcategoryController = TextEditingController(
    text: entry?.subcategory ?? '',
  );
  final manufacturerController = TextEditingController(
    text: entry?.manufacturer ?? '',
  );
  final widthController = TextEditingController(
    text: (entry?.widthMeters ?? 1.2).toString(),
  );
  final heightController = TextEditingController(
    text: (entry?.heightMeters ?? 1.4).toString(),
  );
  final coefficientController = TextEditingController(
    text: (entry?.heatTransferCoefficient ?? 1.0).toString(),
  );
  final sourceUrlController = TextEditingController(
    text: entry?.sourceUrl ?? '',
  );
  final sourceLabelController = TextEditingController(
    text: entry?.sourceLabel ?? '',
  );
  final sourceCheckedAtController = TextEditingController(
    text: entry?.sourceCheckedAt ?? DateTime.now().toIso8601String().split('T').first,
  );
  var selectedKind = entry?.kind ?? OpeningKind.window;
  String? localImagePath = entry?.localImagePath;

  final result = await showModalBottomSheet<OpeningCatalogEntry>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
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
                    entry == null
                        ? 'Новый шаблон проёма'
                        : 'Редактирование шаблона',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<OpeningKind>(
                    initialValue: selectedKind,
                    decoration: const InputDecoration(labelText: 'Тип'),
                    items: OpeningKind.values
                        .map(
                          (kind) => DropdownMenuItem(
                            value: kind,
                            child: Text(kind.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => selectedKind = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Название'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: subcategoryController,
                    decoration: const InputDecoration(labelText: 'Подкатегория'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: manufacturerController,
                    decoration: const InputDecoration(labelText: 'Производитель'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: widthController,
                    decoration: const InputDecoration(labelText: 'Ширина, м'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: heightController,
                    decoration: const InputDecoration(labelText: 'Высота, м'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: coefficientController,
                    decoration: const InputDecoration(labelText: 'U, Вт/м²·°C'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: sourceLabelController,
                    decoration: const InputDecoration(labelText: 'Источник'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: sourceUrlController,
                    decoration: const InputDecoration(labelText: 'Ссылка на источник'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: sourceCheckedAtController,
                    decoration: const InputDecoration(labelText: 'Проверено'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: () async {
                          final file = await FilePicker.platform.pickFiles(
                            type: FileType.image,
                          );
                          if (file == null || file.files.single.path == null) {
                            return;
                          }
                          final documentsDir =
                              await getApplicationDocumentsDirectory();
                          final targetDir = Directory(
                            p.join(documentsDir.path, 'opening_images'),
                          );
                          await targetDir.create(recursive: true);
                          final source = File(file.files.single.path!);
                          final target = File(
                            p.join(
                              targetDir.path,
                              '${entry?.id ?? 'opening-${DateTime.now().millisecondsSinceEpoch}'}${p.extension(source.path)}',
                            ),
                          );
                          await source.copy(target.path);
                          setState(() => localImagePath = target.path);
                        },
                        icon: const Icon(Icons.image_outlined),
                        label: const Text('Выбрать изображение'),
                      ),
                      if (localImagePath != null) ...[
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () => setState(() => localImagePath = null),
                          child: const Text('Убрать'),
                        ),
                      ],
                    ],
                  ),
                  if (localImagePath != null) ...[
                    const SizedBox(height: 12),
                    _OpeningPreview(
                      entry: OpeningCatalogEntry(
                        id: entry?.id ?? 'preview',
                        kind: selectedKind,
                        title: titleController.text,
                        subcategory: subcategoryController.text,
                        manufacturer: manufacturerController.text,
                        widthMeters: 1,
                        heightMeters: 1,
                        heatTransferCoefficient: 1,
                        localImagePath: localImagePath,
                        sourceUrl: sourceUrlController.text,
                        sourceLabel: sourceLabelController.text,
                        sourceCheckedAt: sourceCheckedAtController.text,
                        isCustom: true,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop(
                        OpeningCatalogEntry(
                          id:
                              entry?.id ??
                              'custom-opening-${DateTime.now().millisecondsSinceEpoch}',
                          kind: selectedKind,
                          title: titleController.text.trim().isEmpty
                              ? selectedKind.label
                              : titleController.text.trim(),
                          subcategory: subcategoryController.text.trim().isEmpty
                              ? 'Пользовательские'
                              : subcategoryController.text.trim(),
                          manufacturer: manufacturerController.text.trim().isEmpty
                              ? 'Пользователь'
                              : manufacturerController.text.trim(),
                          widthMeters: double.tryParse(widthController.text) ?? 1.2,
                          heightMeters: double.tryParse(heightController.text) ?? 1.4,
                          heatTransferCoefficient:
                              double.tryParse(coefficientController.text) ?? 1.0,
                          localImagePath: localImagePath,
                          sourceUrl: sourceUrlController.text.trim().isEmpty
                              ? 'local://custom'
                              : sourceUrlController.text.trim(),
                          sourceLabel: sourceLabelController.text.trim().isEmpty
                              ? 'Пользовательский шаблон'
                              : sourceLabelController.text.trim(),
                          sourceCheckedAt: sourceCheckedAtController.text.trim(),
                          isCustom: true,
                        ),
                      );
                    },
                    child: const Text('Сохранить'),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  titleController.dispose();
  subcategoryController.dispose();
  manufacturerController.dispose();
  widthController.dispose();
  heightController.dispose();
  coefficientController.dispose();
  sourceUrlController.dispose();
  sourceLabelController.dispose();
  sourceCheckedAtController.dispose();
  return result;
}
