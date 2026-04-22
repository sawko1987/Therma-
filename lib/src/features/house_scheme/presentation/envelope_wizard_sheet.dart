import 'package:flutter/material.dart';

import '../../../core/models/catalog.dart';
import '../../../core/models/project.dart';
import 'floor_plan_geometry.dart';
import 'house_scheme_editor_helpers.dart';

class EnvelopeWizardResult {
  const EnvelopeWizardResult({
    required this.element,
    required this.openings,
  });

  final HouseEnvelopeElement element;
  final List<EnvelopeOpening> openings;
}

Future<EnvelopeWizardResult?> showEnvelopeWizardSheet(
  BuildContext context, {
  required Project project,
  required CatalogSnapshot catalog,
  required Room room,
}) {
  return showModalBottomSheet<EnvelopeWizardResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => EnvelopeWizardSheet(
      project: project,
      catalog: catalog,
      room: room,
    ),
  );
}

class EnvelopeWizardSheet extends StatefulWidget {
  const EnvelopeWizardSheet({
    super.key,
    required this.project,
    required this.catalog,
    required this.room,
  });

  final Project project;
  final CatalogSnapshot catalog;
  final Room room;

  @override
  State<EnvelopeWizardSheet> createState() => _EnvelopeWizardSheetState();
}

class _EnvelopeWizardSheetState extends State<EnvelopeWizardSheet> {
  final TextEditingController _lengthController = TextEditingController(
    text: defaultRoomLayoutWidthMeters.toStringAsFixed(1),
  );
  final TextEditingController _areaController = TextEditingController(
    text: defaultHouseElementAreaSquareMeters.toStringAsFixed(1),
  );

  int _step = 0;
  ConstructionElementKind _kind = ConstructionElementKind.wall;
  WallOrientation _orientation = WallOrientation.north;
  RoomSide _roomSide = RoomSide.top;
  late String? _selectedConstructionId = _initialConstructionId();
  final List<EnvelopeOpening> _openings = <EnvelopeOpening>[];

  @override
  void dispose() {
    _lengthController.dispose();
    _areaController.dispose();
    super.dispose();
  }

  String? _initialConstructionId() {
    final constructions = widget.project.constructions
        .where((item) => item.elementKind == _kind)
        .toList(growable: false);
    return constructions.isEmpty ? null : constructions.first.id;
  }

  List<Construction> get _availableConstructions => widget.project.constructions
      .where((item) => item.elementKind == _kind)
      .toList(growable: false);

  Construction? get _selectedConstruction {
    final id = _selectedConstructionId;
    if (id == null) {
      return null;
    }
    for (final construction in _availableConstructions) {
      if (construction.id == id) {
        return construction;
      }
    }
    return null;
  }

  double get _wallLength {
    final fallback = widget.room.layout.sideLength(_roomSide);
    final raw = parseEditorDouble(_lengthController.text, fallback: fallback);
    final placement = snapWallPlacement(
      EnvelopeWallPlacement(
        side: _roomSide,
        offsetMeters: 0,
        lengthMeters: raw,
      ),
      sideLength: widget.room.layout.sideLength(_roomSide),
    );
    return placement.lengthMeters;
  }

  double get _area {
    if (_kind == ConstructionElementKind.wall) {
      return _wallLength * widget.room.heightMeters;
    }
    return parseEditorDouble(
      _areaController.text,
      fallback: defaultHouseElementAreaSquareMeters,
    );
  }

  Future<void> _handleAddOpening() async {
    final draftElement = _buildDraftElement();
    final opening = await showOpeningEditorSheet(
      context,
      catalog: widget.catalog,
      elementId: draftElement.id,
    );
    if (!mounted || opening == null) {
      return;
    }
    setState(() => _openings.add(opening));
  }

  HouseEnvelopeElement _buildDraftElement() {
    final construction = _selectedConstruction;
    if (construction == null) {
      throw StateError('Не выбрана конструкция.');
    }
    return HouseEnvelopeElement(
      id: buildEditorId('element'),
      roomId: widget.room.id,
      title: construction.elementKind.label,
      elementKind: construction.elementKind,
      areaSquareMeters: _area,
      construction: construction.copyWith(),
      sourceConstructionId: construction.id,
      sourceConstructionTitle: construction.title,
      wallOrientation:
          construction.elementKind == ConstructionElementKind.wall
          ? _orientation
          : null,
      wallPlacement:
          construction.elementKind == ConstructionElementKind.wall
          ? snapWallPlacement(
              EnvelopeWallPlacement(
                side: _roomSide,
                offsetMeters: 0,
                lengthMeters: _wallLength,
              ),
              sideLength: widget.room.layout.sideLength(_roomSide),
            )
          : null,
    );
  }

  void _handleKindChanged(ConstructionElementKind kind) {
    setState(() {
      _kind = kind;
      final constructions = _availableConstructions;
      _selectedConstructionId = constructions.isEmpty ? null : constructions.first.id;
    });
  }

  void _handleSave() {
    final element = _buildDraftElement();
    final openings = [
      for (final opening in _openings) opening.copyWith(elementId: element.id),
    ];
    Navigator.of(context).pop(
      EnvelopeWizardResult(element: element, openings: openings),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final selectedConstruction = _selectedConstruction;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF3EFE5),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Padding(
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Новое ограждение',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 12),
                Text('Шаг ${_step + 1} из 2'),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: (_step + 1) / 2),
            const SizedBox(height: 20),
            if (_step == 0) ...[
              Text(
                'Тип ограждения',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final kind in ConstructionElementKind.values)
                    ChoiceChip(
                      key: ValueKey('envelope-kind-${kind.storageKey}'),
                      label: Text(kind.label),
                      selected: _kind == kind,
                      onSelected: (_) => _handleKindChanged(kind),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: const ValueKey('envelope-construction-field'),
                initialValue: _selectedConstructionId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Конструкция'),
                items: _availableConstructions
                    .map(
                      (construction) => DropdownMenuItem(
                        value: construction.id,
                        child: Text(construction.title),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedConstructionId = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              if (_kind == ConstructionElementKind.wall) ...[
                DropdownButtonFormField<WallOrientation>(
                  key: const ValueKey('envelope-orientation-field'),
                  initialValue: _orientation,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Сторона света',
                  ),
                  items: WallOrientation.values
                      .map(
                        (orientation) => DropdownMenuItem(
                          value: orientation,
                          child: Text(orientation.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _orientation = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<RoomSide>(
                  key: const ValueKey('envelope-room-side-field'),
                  initialValue: _roomSide,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Сторона помещения',
                  ),
                  items: RoomSide.values
                      .map(
                        (side) => DropdownMenuItem(
                          value: side,
                          child: Text(side.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _roomSide = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('envelope-length-field'),
                  controller: _lengthController,
                  decoration: const InputDecoration(labelText: 'Длина сегмента, м'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                Text(
                  'Площадь: ${_area.toStringAsFixed(2)} м²',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                  ),
                ),
              ] else ...[
                TextField(
                  key: const ValueKey('envelope-area-field'),
                  controller: _areaController,
                  decoration: const InputDecoration(labelText: 'Площадь, м²'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedConstruction?.title ?? 'Конструкция не выбрана',
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_kind.label} • ${_area.toStringAsFixed(2)} м²',
                    ),
                    if (_kind == ConstructionElementKind.wall)
                      Text(
                        '${_orientation.label} • ${_roomSide.label} • сегмент ${_wallLength.toStringAsFixed(1)} м',
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                key: const ValueKey('envelope-add-opening-button'),
                onPressed: _handleAddOpening,
                icon: const Icon(Icons.add),
                label: const Text('Добавить проём'),
              ),
              const SizedBox(height: 16),
              if (_openings.isEmpty)
                const Text('Проёмы не добавлены.')
              else
                ..._openings.map(
                  (opening) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: colorScheme.outlineVariant),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  opening.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${opening.kind.label} • ${opening.areaSquareMeters.toStringAsFixed(2)} м²',
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            key: ValueKey('delete-opening-${opening.id}'),
                            onPressed: () {
                              setState(() {
                                _openings.removeWhere(
                                  (item) => item.id == opening.id,
                                );
                              });
                            },
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                if (_step > 0)
                  Expanded(
                    child: OutlinedButton(
                      key: const ValueKey('envelope-wizard-back'),
                      onPressed: () => setState(() => _step -= 1),
                      child: const Text('Назад'),
                    ),
                  )
                else
                  Expanded(
                    child: OutlinedButton(
                      key: const ValueKey('envelope-wizard-cancel'),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Отмена'),
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: ValueKey(
                      _step == 0
                          ? 'envelope-wizard-next'
                          : 'envelope-wizard-finish',
                    ),
                    onPressed: selectedConstruction == null
                        ? null
                        : _step == 0
                        ? () => setState(() => _step = 1)
                        : _handleSave,
                    child: Text(_step == 0 ? 'Далее' : 'Готово'),
                  ),
                ),
              ],
            ),
            ],
          ),
        ),
      ),
    );
  }
}
