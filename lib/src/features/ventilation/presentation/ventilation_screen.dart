import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/project.dart';
import '../../../core/models/ventilation_settings.dart';
import '../../../core/providers.dart';
import '../../../core/services/ventilation_heat_loss_service.dart';

class VentilationScreen extends ConsumerStatefulWidget {
  const VentilationScreen({super.key});

  @override
  ConsumerState<VentilationScreen> createState() => _VentilationScreenState();
}

class _VentilationScreenState extends ConsumerState<VentilationScreen> {
  final _titleController = TextEditingController();
  final _airExchangeRateController = TextEditingController();
  final _efficiencyController = TextEditingController();
  final _notesController = TextEditingController();

  String? _syncedSettingsId;
  VentilationKind _selectedKind = VentilationKind.natural;
  String? _selectedRoomId;

  @override
  void dispose() {
    _titleController.dispose();
    _airExchangeRateController.dispose();
    _efficiencyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projectAsync = ref.watch(selectedProjectProvider);
    final settingsAsync = ref.watch(selectedVentilationSettingsProvider);
    final resultsAsync = ref.watch(ventilationResultProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Вентиляция',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          projectAsync.when(
            data: (project) {
              if (project == null) {
                return const Text('Активный проект не найден.');
              }
              return settingsAsync.when(
                data: (settings) {
                  _syncForm(settings);
                  return Column(
                    children: [
                      _ProjectSummary(project: project),
                      const SizedBox(height: 16),
                      _SettingsListCard(
                        project: project,
                        selectedSettingsId: settings?.id,
                        onSelect: (id) {
                          ref
                              .read(selectedVentilationSettingsIdProvider.notifier)
                              .select(id);
                        },
                        onAdd: () => _handleAdd(project),
                      ),
                      const SizedBox(height: 16),
                      if (settings == null)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Text(
                              'В проекте пока нет настроек вентиляции.',
                            ),
                          ),
                        )
                      else
                        _EditorCard(
                          project: project,
                          selectedKind: _selectedKind,
                          selectedRoomId: _selectedRoomId,
                          titleController: _titleController,
                          airExchangeRateController: _airExchangeRateController,
                          efficiencyController: _efficiencyController,
                          notesController: _notesController,
                          onKindChanged: (value) {
                            setState(() {
                              _selectedKind = value;
                            });
                          },
                          onRoomChanged: (value) {
                            setState(() {
                              _selectedRoomId = value;
                            });
                          },
                          onSave: () => _handleSave(settings),
                          onDelete: () => _handleDelete(settings.id),
                        ),
                      const SizedBox(height: 16),
                      resultsAsync.when(
                        data: (results) {
                          VentilationHeatLossResult? selectedResult;
                          if (settings != null) {
                            for (final item in results) {
                              if (item.settings.id == settings.id) {
                                selectedResult = item;
                                break;
                              }
                            }
                          }
                          return _ResultCard(result: selectedResult);
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (error, _) => Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text('Ошибка расчета вентиляции: $error'),
                          ),
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (error, _) => Text('Ошибка выбранной записи: $error'),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text('Ошибка проекта: $error'),
          ),
        ],
      ),
    );
  }

  void _syncForm(VentilationSettings? settings) {
    if (settings == null || _syncedSettingsId == settings.id) {
      return;
    }
    _syncedSettingsId = settings.id;
    _titleController.text = settings.title;
    _airExchangeRateController.text = settings.airExchangeRate.toStringAsFixed(2);
    _efficiencyController.text = settings.heatRecoveryEfficiency == null
        ? ''
        : settings.heatRecoveryEfficiency!.toStringAsFixed(2);
    _notesController.text = settings.notes ?? '';
    _selectedKind = settings.kind;
    _selectedRoomId = settings.roomId;
  }

  Future<void> _handleAdd(Project project) async {
    final defaultRoomId = project.houseModel.rooms.isEmpty
        ? null
        : project.houseModel.rooms.first.id;
    final settings = VentilationSettings(
      id: 'vent-${DateTime.now().microsecondsSinceEpoch}',
      title: 'Новая вентиляция',
      kind: VentilationKind.natural,
      airExchangeRate: 0.5,
      roomId: defaultRoomId,
    );
    try {
      await ref.read(projectEditorProvider).addVentilationSettings(settings);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _handleSave(VentilationSettings source) async {
    final airExchangeRate = double.tryParse(
      _airExchangeRateController.text.replaceAll(',', '.'),
    );
    final efficiencyText = _efficiencyController.text.trim();
    final efficiency = efficiencyText.isEmpty
        ? null
        : double.tryParse(efficiencyText.replaceAll(',', '.'));
    if (_titleController.text.trim().isEmpty || airExchangeRate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните название и кратность обмена.')),
      );
      return;
    }
    if (_selectedKind == VentilationKind.heatRecovery &&
        (efficiency == null || efficiency < 0 || efficiency > 1)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Для рекуперации нужен КПД 0..1.')),
      );
      return;
    }

    final updated = source.copyWith(
      title: _titleController.text.trim(),
      kind: _selectedKind,
      airExchangeRate: airExchangeRate,
      heatRecoveryEfficiency: efficiency,
      roomId: _selectedRoomId,
      notes: _notesController.text.trim(),
      clearHeatRecoveryEfficiency: _selectedKind != VentilationKind.heatRecovery,
      clearRoomId: _selectedRoomId == null,
      clearNotes: _notesController.text.trim().isEmpty,
    );

    try {
      await ref.read(projectEditorProvider).updateVentilationSettings(updated);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Настройки вентиляции сохранены.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _handleDelete(String settingsId) async {
    try {
      await ref.read(projectEditorProvider).deleteVentilationSettings(settingsId);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }
}

class _ProjectSummary extends StatelessWidget {
  const _ProjectSummary({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    return Card(
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
              'Задайте воздухообмен для отдельной комнаты или всего дома. Расчет использует СП 60.13330.2020 и учитывает КПД рекуперации.',
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsListCard extends StatelessWidget {
  const _SettingsListCard({
    required this.project,
    required this.selectedSettingsId,
    required this.onSelect,
    required this.onAdd,
  });

  final Project project;
  final String? selectedSettingsId;
  final ValueChanged<String> onSelect;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final roomMap = {for (final room in project.houseModel.rooms) room.id: room};
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
                    'Настройки вентиляции',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                FilledButton.icon(
                  key: const ValueKey('ventilation-add'),
                  onPressed: onAdd,
                  icon: const Icon(Icons.add),
                  label: const Text('Добавить'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (project.ventilationSettings.isEmpty)
              const Text('Пока нет ни одной сохраненной схемы вентиляции.')
            else
              ...project.ventilationSettings.map((item) {
                final isSelected = item.id == selectedSettingsId;
                final scopeLabel = item.roomId == null
                    ? 'Весь дом'
                    : (roomMap[item.roomId]?.title ?? 'Комната');
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      side: BorderSide(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outlineVariant,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: Text(
                      item.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${item.kind.label} • ${item.airExchangeRate.toStringAsFixed(2)} 1/ч • $scopeLabel',
                    ),
                    trailing: Icon(
                      isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off_outlined,
                    ),
                    onTap: () => onSelect(item.id),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _EditorCard extends StatelessWidget {
  const _EditorCard({
    required this.project,
    required this.selectedKind,
    required this.selectedRoomId,
    required this.titleController,
    required this.airExchangeRateController,
    required this.efficiencyController,
    required this.notesController,
    required this.onKindChanged,
    required this.onRoomChanged,
    required this.onSave,
    required this.onDelete,
  });

  final Project project;
  final VentilationKind selectedKind;
  final String? selectedRoomId;
  final TextEditingController titleController;
  final TextEditingController airExchangeRateController;
  final TextEditingController efficiencyController;
  final TextEditingController notesController;
  final ValueChanged<VentilationKind> onKindChanged;
  final ValueChanged<String?> onRoomChanged;
  final VoidCallback onSave;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final requiresEfficiency = selectedKind == VentilationKind.heatRecovery;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Редактор',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('ventilation-title'),
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Название'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<VentilationKind>(
              initialValue: selectedKind,
              decoration: const InputDecoration(labelText: 'Тип вентиляции'),
              items: VentilationKind.values
                  .map(
                    (item) => DropdownMenuItem(
                      value: item,
                      child: Text(item.label),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) {
                  onKindChanged(value);
                }
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: selectedRoomId,
              decoration: const InputDecoration(labelText: 'Область действия'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Весь дом'),
                ),
                ...project.houseModel.rooms.map(
                  (room) => DropdownMenuItem<String?>(
                    value: room.id,
                    child: Text(room.title),
                  ),
                ),
              ],
              onChanged: onRoomChanged,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('ventilation-air-rate'),
              controller: airExchangeRateController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Кратность воздухообмена',
                suffixText: '1/ч',
              ),
            ),
            if (requiresEfficiency) ...[
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('ventilation-efficiency'),
                controller: efficiencyController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'КПД рекуперации',
                  helperText: 'Значение от 0 до 1',
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Примечание'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                FilledButton(
                  key: const ValueKey('ventilation-save'),
                  onPressed: onSave,
                  child: const Text('Сохранить'),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  key: const ValueKey('ventilation-delete'),
                  onPressed: onDelete,
                  child: const Text('Удалить'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final VentilationHeatLossResult? result;

  @override
  Widget build(BuildContext context) {
    if (result == null) {
      return const SizedBox.shrink();
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Результат',
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
                  label: 'Потери',
                  value: '${result!.heatLossWatts.toStringAsFixed(0)} Вт',
                ),
                _MetricTile(
                  label: 'Объем',
                  value: '${result!.volumeCubicMeters.toStringAsFixed(1)} м³',
                ),
                _MetricTile(
                  label: 'ΔT',
                  value: '${result!.deltaTemperature.toStringAsFixed(0)} °C',
                ),
                _MetricTile(
                  label: 'Рекуперация',
                  value:
                      '${(result!.heatRecoveryEfficiency * 100).toStringAsFixed(0)} %',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'СП 60.13330.2020: Q = 0.278 * n * V * ρ * c * ΔT * (1 - η)',
            ),
          ],
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6F1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
