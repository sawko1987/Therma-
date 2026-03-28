import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/project.dart';
import '../../../core/providers.dart';
import '../../construction_library/presentation/construction_step_screen.dart';

class ObjectStepScreen extends ConsumerWidget {
  const ObjectStepScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final objectListAsync = ref.watch(objectListProvider);
    final selectedObjectId = ref.watch(selectedObjectIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Шаг 0. Объект'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          const _HeaderCard(),
          const SizedBox(height: 16),
          objectListAsync.when(
            data: (objects) => _ObjectListCard(
              objects: objects,
              selectedObjectId: selectedObjectId,
              onSelectObject: (object) =>
                  _openStep1ForObject(context, ref, object),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text('Ошибка загрузки объектов: $error'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openObjectEditor(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Новый объект'),
      ),
    );
  }

  Future<void> _openObjectEditor(
    BuildContext context,
    WidgetRef ref, {
    DesignObject? object,
  }) async {
    final result = await showModalBottomSheet<_ObjectEditorResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ObjectEditorSheet(object: object),
    );
    if (!context.mounted || result == null) {
      return;
    }
    try {
      if (object == null) {
        await ref.read(projectEditorProvider).createObject(
          title: result.title,
          address: result.address,
          description: result.description,
          customerPhone: result.customerPhone,
        );
        final createdObject = await ref.read(selectedObjectProvider.future);
        if (!context.mounted || createdObject == null) {
          return;
        }
        _openStep1ForObject(context, ref, createdObject);
      } else {
        await ref.read(projectEditorProvider).updateObject(
          object.copyWith(
            title: result.title,
            address: result.address,
            description: result.description,
            customerPhone: result.customerPhone,
            updatedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
          ),
        );
      }
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  void _openStep1ForObject(
    BuildContext context,
    WidgetRef ref,
    DesignObject object,
  ) {
    ref.read(selectedObjectIdProvider.notifier).select(object.id);
    ref.read(selectedProjectIdProvider.notifier).select(object.projectId);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ConstructionStepScreen(),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Сначала выберите объект',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Шаг 0 фиксирует карточку объекта: адрес, описание и телефон заказчика. Только после выбора объекта открываются инженерные шаги расчета.',
            ),
          ],
        ),
      ),
    );
  }
}

class _ObjectListCard extends ConsumerWidget {
  const _ObjectListCard({
    required this.objects,
    required this.selectedObjectId,
    required this.onSelectObject,
  });

  final List<DesignObject> objects;
  final String? selectedObjectId;
  final ValueChanged<DesignObject> onSelectObject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Объекты',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            if (objects.isEmpty)
              const Text('Пока нет объектов. Создайте первый объект.')
            else
              ...objects.map((object) {
                final isSelected = object.id == selectedObjectId;
                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    title: Text(
                      object.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      [
                        if (object.address.isNotEmpty) object.address,
                        if (object.customerPhone.isNotEmpty)
                          'Телефон: ${object.customerPhone}',
                        if (object.description.isNotEmpty) object.description,
                      ].join('\n'),
                    ),
                    isThreeLine:
                        object.customerPhone.isNotEmpty ||
                        object.description.isNotEmpty,
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) async {
                        switch (value) {
                          case 'select':
                            onSelectObject(object);
                          case 'edit':
                            await showModalBottomSheet<_ObjectEditorResult>(
                              context: context,
                              isScrollControlled: true,
                              builder: (context) =>
                                  _ObjectEditorSheet(object: object),
                            ).then((result) async {
                              if (result == null) {
                                return;
                              }
                              await ref.read(projectEditorProvider).updateObject(
                                object.copyWith(
                                  title: result.title,
                                  address: result.address,
                                  description: result.description,
                                  customerPhone: result.customerPhone,
                                  updatedAtEpochMs:
                                      DateTime.now().millisecondsSinceEpoch,
                                ),
                              );
                            });
                          case 'delete':
                            await ref.read(projectEditorProvider).deleteObject(
                              object.id,
                            );
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'select',
                          child: Text('Выбрать объект'),
                        ),
                        PopupMenuItem(
                          value: 'edit',
                          child: Text('Редактировать'),
                        ),
                        PopupMenuItem(value: 'delete', child: Text('Удалить')),
                      ],
                    ),
                    onTap: () => onSelectObject(object),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _ObjectEditorResult {
  const _ObjectEditorResult({
    required this.title,
    required this.address,
    required this.description,
    required this.customerPhone,
  });

  final String title;
  final String address;
  final String description;
  final String customerPhone;
}

class _ObjectEditorSheet extends ConsumerStatefulWidget {
  const _ObjectEditorSheet({this.object});

  final DesignObject? object;

  @override
  ConsumerState<_ObjectEditorSheet> createState() => _ObjectEditorSheetState();
}

class _ObjectEditorSheetState extends ConsumerState<_ObjectEditorSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _addressController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.object?.title ?? '');
    _addressController = TextEditingController(
      text: widget.object?.address ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.object?.description ?? '',
    );
    _phoneController = TextEditingController(
      text: widget.object?.customerPhone ?? '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final picker = ref.watch(customerPhonePickerProvider);

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
              widget.object == null ? 'Новый объект' : 'Редактирование объекта',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Название объекта'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(labelText: 'Адрес'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Описание'),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Телефон заказчика',
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            FutureBuilder<bool>(
              future: picker.supportsContacts,
              builder: (context, contactsSnapshot) {
                return FutureBuilder<bool>(
                  future: picker.supportsCallLog,
                  builder: (context, callsSnapshot) {
                    final supportsContacts = contactsSnapshot.data ?? false;
                    final supportsCalls = callsSnapshot.data ?? false;
                    if (!supportsContacts && !supportsCalls) {
                      return const SizedBox.shrink();
                    }
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        if (supportsContacts)
                          FilledButton.tonalIcon(
                            onPressed: () => _pickPhone(
                              context,
                              picker.loadContacts,
                            ),
                            icon: const Icon(Icons.contacts_outlined),
                            label: const Text('Из контактов'),
                          ),
                        if (supportsCalls)
                          FilledButton.tonalIcon(
                            onPressed: () => _pickPhone(
                              context,
                              picker.loadCallLog,
                            ),
                            icon: const Icon(Icons.call_outlined),
                            label: const Text('Из журнала вызовов'),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(
                  _ObjectEditorResult(
                    title: _normalizeRequired(_titleController.text, 'Объект'),
                    address: _addressController.text.trim(),
                    description: _descriptionController.text.trim(),
                    customerPhone: _phoneController.text.trim(),
                  ),
                );
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPhone(
    BuildContext context,
    Future<List<CustomerPhoneRecord>> Function() loader,
  ) async {
    final items = await loader();
    if (!context.mounted) {
      return;
    }
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Номера не найдены или доступ запрещен.')),
      );
      return;
    }
    final selected = await showModalBottomSheet<CustomerPhoneRecord>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: items
              .map(
                (item) => ListTile(
                  title: Text(item.label),
                  subtitle: Text(
                    [
                      item.phone,
                      if (item.subtitle != null) item.subtitle!,
                    ].join('\n'),
                  ),
                  isThreeLine: item.subtitle != null,
                  onTap: () => Navigator.of(context).pop(item),
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
    if (selected != null) {
      _phoneController.text = selected.phone;
    }
  }

  String _normalizeRequired(String value, String fallback) {
    final normalized = value.trim();
    return normalized.isEmpty ? fallback : normalized;
  }
}
