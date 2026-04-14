import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/catalog.dart';
import '../../../core/models/project.dart';
import '../../../core/providers.dart';
import 'envelope_wizard_sheet.dart';
import 'floor_plan_geometry.dart';
import 'house_scheme_editor_helpers.dart';

Future<void> showRoomWizard(
  BuildContext context,
  Project project,
  CatalogSnapshot catalog,
) async {
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => RoomWizardScreen(project: project, catalog: catalog),
      fullscreenDialog: true,
    ),
  );
}

class RoomWizardScreen extends ConsumerStatefulWidget {
  const RoomWizardScreen({
    super.key,
    required this.project,
    required this.catalog,
  });

  final Project project;
  final CatalogSnapshot catalog;

  @override
  ConsumerState<RoomWizardScreen> createState() => _RoomWizardScreenState();
}

class _RoomWizardScreenState extends ConsumerState<RoomWizardScreen> {
  static const int _totalSteps = 4;

  late final RoomLayoutRect _baseLayout = buildNextRoomLayout(
    widget.project.houseModel.rooms,
  );
  late final String _defaultTitle =
      'Помещение №${widget.project.houseModel.rooms.length + 1}';
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _widthController = TextEditingController(
    text: defaultRoomLayoutWidthMeters.toStringAsFixed(1),
  );
  final TextEditingController _lengthController = TextEditingController(
    text: defaultRoomLayoutHeightMeters.toStringAsFixed(1),
  );
  final TextEditingController _heightController = TextEditingController(
    text: defaultRoomHeightMeters.toStringAsFixed(1),
  );
  final TextEditingController _comfortController = TextEditingController(
    text: defaultRoomComfortTemperatureC.toStringAsFixed(0),
  );
  final TextEditingController _ventilationController = TextEditingController(
    text: defaultRoomVentilationSupplyM3h.toStringAsFixed(0),
  );

  int _currentStep = 0;
  int _previousStep = 0;
  RoomKind _selectedKind = RoomKind.livingRoom;
  bool _titleEditedManually = false;
  bool _isSaving = false;
  final List<_DraftEnvelope> _draftEnvelopes = <_DraftEnvelope>[];

  @override
  void initState() {
    super.initState();
    _titleController.text = _defaultTitle;
    for (final controller in [
      _titleController,
      _widthController,
      _lengthController,
      _heightController,
      _comfortController,
      _ventilationController,
    ]) {
      controller.addListener(_handleAnyFieldChanged);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _widthController.dispose();
    _lengthController.dispose();
    _heightController.dispose();
    _comfortController.dispose();
    _ventilationController.dispose();
    super.dispose();
  }

  void _handleAnyFieldChanged() {
    if (!mounted) {
      return;
    }
    final normalized = _titleController.text.trim();
    final autoTitles = {_defaultTitle, for (final kind in RoomKind.values) kind.label};
    if (!_titleEditedManually && !autoTitles.contains(normalized)) {
      _titleEditedManually = true;
    }
    setState(() {});
  }

  void _goToStep(int step) {
    setState(() {
      _previousStep = _currentStep;
      _currentStep = step;
    });
  }

  void _handleKindChanged(RoomKind kind) {
    setState(() {
      _selectedKind = kind;
      if (!_titleEditedManually) {
        _titleController.text = kind.label;
      }
    });
  }

  double get _width => parseEditorDouble(
    _widthController.text,
    fallback: defaultRoomLayoutWidthMeters,
  );

  double get _length => parseEditorDouble(
    _lengthController.text,
    fallback: defaultRoomLayoutHeightMeters,
  );

  double get _height => parseEditorDouble(
    _heightController.text,
    fallback: defaultRoomHeightMeters,
  );

  double get _comfort => parseEditorDouble(
    _comfortController.text,
    fallback: defaultRoomComfortTemperatureC,
  );

  double get _ventilation => parseEditorDouble(
    _ventilationController.text,
    fallback: defaultRoomVentilationSupplyM3h,
  );

  double get _area => _width * _length;

  Room get _draftRoom => Room(
    id: 'draft-room',
    title: requireEditorText(_titleController.text, fallback: _defaultTitle),
    kind: _selectedKind,
    heightMeters: _height,
    comfortTemperatureC: _comfort,
    ventilationSupplyM3h: _ventilation,
    layout: _baseLayout.copyWith(widthMeters: _width, heightMeters: _length),
  );

  bool get _hasEnteredData {
    return _draftEnvelopes.isNotEmpty ||
        _titleController.text.trim() != _defaultTitle ||
        _selectedKind != RoomKind.livingRoom ||
        (_width - defaultRoomLayoutWidthMeters).abs() > 0.001 ||
        (_length - defaultRoomLayoutHeightMeters).abs() > 0.001 ||
        (_height - defaultRoomHeightMeters).abs() > 0.001 ||
        (_comfort - defaultRoomComfortTemperatureC).abs() > 0.001 ||
        (_ventilation - defaultRoomVentilationSupplyM3h).abs() > 0.001;
  }

  Future<void> _handleClose() async {
    if (!_hasEnteredData) {
      Navigator.of(context).pop();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Отменить создание?'),
        content: const Text(
          'Введённые данные будут потеряны. Закрыть мастер?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Остаться'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleAddEnvelope() async {
    final result = await showEnvelopeWizardSheet(
      context,
      project: widget.project,
      catalog: widget.catalog,
      room: _draftRoom,
    );
    if (!mounted || result == null) {
      return;
    }
    setState(() {
      _draftEnvelopes.add(
        _DraftEnvelope(element: result.element, openings: result.openings),
      );
    });
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    final room = _draftRoom.copyWith(id: buildEditorId('room'));
    try {
      await ref.read(projectEditorProvider).addRoom(room);
      for (final draft in _draftEnvelopes) {
        final element = draft.element.copyWith(roomId: room.id);
        await ref.read(projectEditorProvider).addEnvelopeElement(element);
        for (final opening in draft.openings) {
          await ref.read(projectEditorProvider).addOpening(
            opening.copyWith(elementId: element.id),
          );
        }
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Не удалось сохранить помещение: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = switch (_currentStep) {
      0 => _buildStepOne(context),
      1 => _buildStepTwo(context),
      2 => _buildStepThree(context),
      _ => _buildStepFour(context),
    };
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Новое помещение',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text('Шаг ${_currentStep + 1} из $_totalSteps'),
            ),
          ),
          IconButton(
            key: const ValueKey('room-wizard-close'),
            onPressed: _isSaving ? null : _handleClose,
            icon: const Icon(Icons.close),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(10),
          child: LinearProgressIndicator(
            value: (_currentStep + 1) / _totalSteps,
          ),
        ),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          transitionBuilder: (child, animation) {
            final beginOffset = _currentStep >= _previousStep
                ? const Offset(0.12, 0)
                : const Offset(-0.12, 0);
            final offsetAnimation = Tween<Offset>(
              begin: beginOffset,
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );
            return SlideTransition(position: offsetAnimation, child: child);
          },
          child: KeyedSubtree(
            key: ValueKey('room-wizard-step-$_currentStep'),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              children: [child],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepOne(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Основные данные',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('room-wizard-title-field'),
          controller: _titleController,
          decoration: const InputDecoration(labelText: 'Название помещения'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 20),
        Text(
          'Тип помещения',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final kind in RoomKind.values)
              _RoomKindCard(
                kind: kind,
                selected: _selectedKind == kind,
                onTap: () => _handleKindChanged(kind),
              ),
          ],
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            key: const ValueKey('room-wizard-next-step1'),
            onPressed: () => _goToStep(1),
            child: const Text('Далее'),
          ),
        ),
      ],
    );
  }

  Widget _buildStepTwo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Размеры и климат',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('room-wizard-width-field'),
          controller: _widthController,
          decoration: const InputDecoration(labelText: 'Ширина, м'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('room-wizard-length-field'),
          controller: _lengthController,
          decoration: const InputDecoration(labelText: 'Длина, м'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('room-wizard-height-field'),
          controller: _heightController,
          decoration: const InputDecoration(labelText: 'Высота потолка, м'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 8),
        Text(
          'Площадь: ${_area.toStringAsFixed(2)} м²',
          key: const ValueKey('room-wizard-area-label'),
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('room-wizard-comfort-field'),
          controller: _comfortController,
          decoration: const InputDecoration(labelText: 'Комфортная температура, °C'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('room-wizard-ventilation-field'),
          controller: _ventilationController,
          decoration: const InputDecoration(labelText: 'Приток воздуха, м³/ч'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _goToStep(0),
                child: const Text('Назад'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                key: const ValueKey('room-wizard-next-step2'),
                onPressed: () => _goToStep(2),
                child: const Text('Далее'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStepThree(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ограждения и проёмы',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        FilledButton.tonalIcon(
          key: const ValueKey('room-wizard-add-envelope-button'),
          onPressed: _handleAddEnvelope,
          icon: const Icon(Icons.add),
          label: const Text('Добавить ограждение'),
        ),
        const SizedBox(height: 16),
        if (_draftEnvelopes.isEmpty)
          const Text('Ограждения пока не добавлены.')
        else
          ..._draftEnvelopes.map(
            (draft) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _EnvelopePreviewCard(
                draft: draft,
                onDelete: () {
                  setState(() {
                    _draftEnvelopes.remove(draft);
                  });
                },
              ),
            ),
          ),
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _goToStep(1),
                child: const Text('Назад'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                key: const ValueKey('room-wizard-next-step3'),
                onPressed: () => _goToStep(3),
                child: const Text('Далее'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStepFour(BuildContext context) {
    final preview = _calculatePreviewHeatLoss(
      project: widget.project,
      catalog: widget.catalog,
      room: _draftRoom,
      envelopes: _draftEnvelopes,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Итоговый обзор',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('room-wizard-review-title-field'),
          controller: _titleController,
          decoration: const InputDecoration(labelText: 'Название помещения'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<RoomKind>(
          key: const ValueKey('room-wizard-review-kind-field'),
          initialValue: _selectedKind,
          decoration: const InputDecoration(labelText: 'Тип помещения'),
          items: RoomKind.values
              .map(
                (kind) => DropdownMenuItem(
                  value: kind,
                  child: Text(kind.label),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) {
              _handleKindChanged(value);
            }
          },
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('room-wizard-review-comfort-field'),
          controller: _comfortController,
          decoration: const InputDecoration(labelText: 'Комфортная температура, °C'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('room-wizard-review-ventilation-field'),
          controller: _ventilationController,
          decoration: const InputDecoration(labelText: 'Приток воздуха, м³/ч'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 20),
        Text(
          'Ограждения',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        if (_draftEnvelopes.isEmpty)
          const Text('Ограждения не добавлены.')
        else
          ..._draftEnvelopes.map(
            (draft) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      draft.element.sourceConstructionTitle ??
                          draft.element.construction.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${draft.element.elementKind.label} • ${draft.element.areaSquareMeters.toStringAsFixed(2)} м²',
                    ),
                    if (draft.element.wallOrientation != null)
                      Text(
                        '${draft.element.wallOrientation!.label} • ${draft.element.wallPlacement?.side.label ?? '—'}',
                      ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 20),
        Container(
          key: const ValueKey('room-wizard-heat-loss-card'),
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF3E2),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Live-просмотр теплопотерь',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              _PreviewLine(
                label: 'Через ограждения',
                value: '${preview.envelopeHeatLossWatts.toStringAsFixed(0)} Вт',
              ),
              _PreviewLine(
                label: 'Через проёмы',
                value: '${preview.openingHeatLossWatts.toStringAsFixed(0)} Вт',
              ),
              _PreviewLine(
                label: 'На вентиляцию',
                value: '${preview.ventilationHeatLossWatts.toStringAsFixed(0)} Вт',
              ),
              _PreviewLine(
                label: 'Итого',
                value: '${preview.totalHeatLossWatts.toStringAsFixed(0)} Вт',
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isSaving ? null : () => _goToStep(2),
                child: const Text('Назад'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                key: const ValueKey('room-wizard-save'),
                onPressed: _isSaving ? null : _handleSave,
                child: Text(_isSaving ? 'Сохранение...' : 'Сохранить'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  _PreviewHeatLoss _calculatePreviewHeatLoss({
    required Project project,
    required CatalogSnapshot catalog,
    required Room room,
    required List<_DraftEnvelope> envelopes,
  }) {
    final climate = catalog.climatePoints.firstWhere(
      (point) => point.id == project.climatePointId,
    );
    final materialsById = {for (final material in catalog.materials) material.id: material};
    final deltaT = room.comfortTemperatureC - climate.designTemperature;
    var envelopeHeatLoss = 0.0;
    var openingHeatLoss = 0.0;

    for (final draft in envelopes) {
      final openingArea = draft.openings.fold<double>(
        0,
        (sum, opening) => sum + opening.areaSquareMeters,
      );
      final opaqueArea = math.max(0, draft.element.areaSquareMeters - openingArea);
      var resistance = 0.0;
      for (final layer in draft.element.construction.layers) {
        if (!layer.enabled) {
          continue;
        }
        final material = materialsById[layer.materialId];
        if (material == null || material.thermalConductivity <= 0) {
          continue;
        }
        resistance += (layer.thicknessMm / 1000) / material.thermalConductivity;
      }
      final safeResistance = resistance <= 0 ? 0.0001 : resistance;
      envelopeHeatLoss += deltaT / safeResistance * opaqueArea;
      for (final opening in draft.openings) {
        openingHeatLoss +=
            opening.heatTransferCoefficient * opening.areaSquareMeters * deltaT;
      }
    }

    final ventilationHeatLoss = 0.335 * room.ventilationSupplyM3h * deltaT;
    return _PreviewHeatLoss(
      envelopeHeatLossWatts: envelopeHeatLoss,
      openingHeatLossWatts: openingHeatLoss,
      ventilationHeatLossWatts: ventilationHeatLoss,
    );
  }
}

class _DraftEnvelope {
  const _DraftEnvelope({
    required this.element,
    required this.openings,
  });

  final HouseEnvelopeElement element;
  final List<EnvelopeOpening> openings;
}

class _PreviewHeatLoss {
  const _PreviewHeatLoss({
    required this.envelopeHeatLossWatts,
    required this.openingHeatLossWatts,
    required this.ventilationHeatLossWatts,
  });

  final double envelopeHeatLossWatts;
  final double openingHeatLossWatts;
  final double ventilationHeatLossWatts;

  double get totalHeatLossWatts =>
      envelopeHeatLossWatts + openingHeatLossWatts + ventilationHeatLossWatts;
}

class _RoomKindCard extends StatelessWidget {
  const _RoomKindCard({
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  final RoomKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      key: ValueKey('room-kind-${kind.storageKey}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 148,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF3EFE5),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? colorScheme.primary : colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_iconForRoomKind(kind), color: colorScheme.primary),
            const SizedBox(height: 12),
            Text(kind.label, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  IconData _iconForRoomKind(RoomKind kind) {
    return switch (kind) {
      RoomKind.livingRoom => Icons.weekend_outlined,
      RoomKind.bedroom => Icons.bed_outlined,
      RoomKind.kitchen => Icons.soup_kitchen_outlined,
      RoomKind.bathroom => Icons.bathtub_outlined,
      RoomKind.hall => Icons.meeting_room_outlined,
      RoomKind.boilerRoom => Icons.local_fire_department_outlined,
      RoomKind.other => Icons.category_outlined,
    };
  }
}

class _EnvelopePreviewCard extends StatelessWidget {
  const _EnvelopePreviewCard({
    required this.draft,
    required this.onDelete,
  });

  final _DraftEnvelope draft;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final wallPlacement = draft.element.wallPlacement;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  draft.element.sourceConstructionTitle ??
                      draft.element.construction.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '${draft.element.elementKind.label} • ${draft.element.areaSquareMeters.toStringAsFixed(2)} м²',
                ),
                if (draft.element.wallOrientation != null && wallPlacement != null)
                  Text(
                    '${draft.element.wallOrientation!.label} • ${wallPlacement.side.label} • ${wallPlacement.lengthMeters.toStringAsFixed(1)} м',
                  ),
                Text('Проёмы: ${draft.openings.length}'),
              ],
            ),
          ),
          IconButton(
            key: ValueKey('delete-envelope-${draft.element.id}'),
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}

class _PreviewLine extends StatelessWidget {
  const _PreviewLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
