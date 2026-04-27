import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/catalog.dart';
import '../../../core/models/project.dart';
import '../../../core/providers.dart';

class HeatingDeviceWizardResult {
  const HeatingDeviceWizardResult({
    required this.heatingDevice,
    this.customCatalogEntry,
  });

  final HeatingDevice heatingDevice;
  final HeatingDeviceCatalogEntry? customCatalogEntry;
}

enum RadiatorWizardType { panel, sectional }

extension RadiatorWizardTypeX on RadiatorWizardType {
  String get label => switch (this) {
    RadiatorWizardType.panel => 'Панельный',
    RadiatorWizardType.sectional => 'Алюминиевый секционный',
  };
}

class RadiatorWizardSelectionHelper {
  const RadiatorWizardSelectionHelper();

  List<String> panelTypes(Iterable<HeatingDeviceCatalogEntry> entries) {
    final values =
        entries
            .where((entry) => entry.panelType != null)
            .map((entry) => entry.panelType!)
            .toSet()
            .toList()
          ..sort();
    return values;
  }

  List<double> heights(
    Iterable<HeatingDeviceCatalogEntry> entries, {
    required RadiatorWizardType type,
    String? panelType,
    double? sectionWidthMm,
  }) {
    final values =
        entries
            .where((entry) {
              if (type == RadiatorWizardType.panel) {
                return entry.panelType != null &&
                    (panelType == null || entry.panelType == panelType);
              }
              return entry.isSectional &&
                  (sectionWidthMm == null ||
                      _sameDimension(sectionWidth(entry), sectionWidthMm));
            })
            .map((entry) => entry.heightMm)
            .whereType<double>()
            .toSet()
            .toList()
          ..sort();
    return values;
  }

  List<double> sectionWidths(Iterable<HeatingDeviceCatalogEntry> entries) {
    final values =
        entries
            .where((entry) => entry.isSectional)
            .map(sectionWidth)
            .whereType<double>()
            .toSet()
            .toList()
          ..sort();
    return values;
  }

  Iterable<HeatingDeviceCatalogEntry> panelCandidates({
    required Iterable<HeatingDeviceCatalogEntry> entries,
    required String panelType,
    required double heightMm,
  }) {
    return entries.where(
      (entry) =>
          entry.panelType == panelType &&
          _sameDimension(entry.heightMm, heightMm),
    );
  }

  HeatingDeviceCatalogEntry? sectionalEntry({
    required Iterable<HeatingDeviceCatalogEntry> entries,
    required double sectionWidthMm,
    required double heightMm,
  }) {
    final candidates =
        entries
            .where(
              (entry) =>
                  entry.isSectional &&
                  _sameDimension(sectionWidth(entry), sectionWidthMm) &&
                  _sameDimension(entry.heightMm, heightMm),
            )
            .toList(growable: false)
          ..sort((a, b) {
            final aSections = a.sectionCount ?? 1;
            final bSections = b.sectionCount ?? 1;
            return aSections.compareTo(bSections);
          });
    return candidates.isEmpty ? null : candidates.first;
  }

  double? sectionWidth(HeatingDeviceCatalogEntry entry) {
    final width = entry.widthMm;
    final count = entry.sectionCount;
    if (width == null || count == null || count <= 0) {
      return null;
    }
    return width / count;
  }

  HeatingDeviceCatalogEntry buildManualEntry({
    required String id,
    required RadiatorWizardType type,
    required String title,
    required String panelType,
    required double widthMm,
    required double heightMm,
    required double ratedPowerWatts,
    required double flowTempC,
    required double returnTempC,
    required double roomTempC,
  }) {
    final entryId = 'custom-radiator-$id';
    if (type == RadiatorWizardType.sectional) {
      return HeatingDeviceCatalogEntry(
        id: entryId,
        kind: HeatingDeviceKind.radiator.storageKey,
        title: '$title, 1 секция',
        ratedPowerWatts: ratedPowerWatts,
        sectionCount: 1,
        widthMm: widthMm,
        heightMm: heightMm,
        designFlowTempC: flowTempC,
        designReturnTempC: returnTempC,
        roomTempC: roomTempC,
        heatOutputExponent: 1.25,
        isCustom: true,
      );
    }
    return HeatingDeviceCatalogEntry(
      id: entryId,
      kind: HeatingDeviceKind.radiator.storageKey,
      title: title,
      ratedPowerWatts: ratedPowerWatts,
      widthMm: widthMm,
      heightMm: heightMm,
      panelType: panelType,
      designFlowTempC: flowTempC,
      designReturnTempC: returnTempC,
      roomTempC: roomTempC,
      heatOutputExponent: 1.3,
      isCustom: true,
    );
  }

  static bool _sameDimension(double? left, double right) {
    return left != null && (left - right).abs() < 0.5;
  }
}

Future<HeatingDeviceWizardResult?> showRadiatorWizardSheet(
  BuildContext context, {
  required CatalogSnapshot catalog,
  required Room room,
  required double requiredPowerWatts,
  required HeatingSystemParameters? systemParameters,
  required List<EnvelopeOpening> roomOpenings,
  required double underfloorPowerWatts,
  HeatingDevice? heatingDevice,
}) async {
  final helper = const RadiatorWizardSelectionHelper();
  final radiatorEntries = catalog.heatingDevices
      .where((entry) => entry.kind == HeatingDeviceKind.radiator.storageKey)
      .toList(growable: false);
  final existingEntry = heatingDevice?.catalogItemId == null
      ? null
      : radiatorEntries
            .where((entry) => entry.id == heatingDevice!.catalogItemId)
            .firstOrNull;
  var selectedType = existingEntry?.isSectional ?? false
      ? RadiatorWizardType.sectional
      : RadiatorWizardType.panel;
  final titleController = TextEditingController(
    text: heatingDevice?.title ?? existingEntry?.title ?? '',
  );
  final requiredPowerController = TextEditingController(
    text: (heatingDevice?.requiredPowerWatts ?? requiredPowerWatts)
        .toStringAsFixed(0),
  );
  final flowController = TextEditingController(
    text:
        (heatingDevice?.designFlowTempC ??
                systemParameters?.designFlowTempC ??
                70)
            .toStringAsFixed(0),
  );
  final returnController = TextEditingController(
    text:
        (heatingDevice?.designReturnTempC ??
                systemParameters?.designReturnTempC ??
                55)
            .toStringAsFixed(0),
  );
  final manualPanelWidthController = TextEditingController(
    text: existingEntry?.widthMm?.toStringAsFixed(0) ?? '1000',
  );
  final manualPanelPowerController = TextEditingController(
    text: (heatingDevice?.ratedPowerWatts ?? requiredPowerWatts)
        .toStringAsFixed(0),
  );
  final manualSectionPowerController = TextEditingController(
    text: existingEntry?.isSectional ?? false
        ? ((existingEntry!.ratedPowerWatts / (existingEntry.sectionCount ?? 1))
              .toStringAsFixed(0))
        : '150',
  );

  final windows = roomOpenings
      .where((opening) => opening.kind == OpeningKind.window)
      .toList(growable: false);
  String? selectedWindowId = windows.isEmpty ? null : windows.first.id;
  final panelTypes = helper.panelTypes(radiatorEntries);
  var selectedPanelType =
      existingEntry?.panelType ??
      (panelTypes.isEmpty ? '22' : panelTypes.first);
  final sectionWidths = helper.sectionWidths(radiatorEntries);
  var selectedSectionWidth =
      (existingEntry == null ? null : helper.sectionWidth(existingEntry)) ??
      (sectionWidths.isEmpty ? 80.0 : sectionWidths.first);
  var selectedHeight =
      existingEntry?.heightMm ??
      (helper
              .heights(
                radiatorEntries,
                type: selectedType,
                panelType: selectedPanelType,
                sectionWidthMm: selectedSectionWidth,
              )
              .firstOrNull ??
          500.0);
  var manualMode =
      existingEntry?.isCustom ??
      (heatingDevice != null && heatingDevice.catalogItemId == null);
  String? supplyValveId =
      heatingDevice?.supplyValveCatalogItemId ??
      heatingDevice?.valveCatalogItemId;
  String? supplyValveSetting =
      heatingDevice?.supplyValveSetting ?? heatingDevice?.valveSetting;
  String? returnValveId = heatingDevice?.returnValveCatalogItemId;
  String? returnValveSetting = heatingDevice?.returnValveSetting;
  var currentStep = 0;

  HeatingValveCatalogEntry? findValve(String? id) => id == null
      ? null
      : catalog.heatingValves.where((entry) => entry.id == id).firstOrNull;

  try {
    return await showModalBottomSheet<HeatingDeviceWizardResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            return StatefulBuilder(
              builder: (context, setState) {
                final service = ref.read(heatingDeviceSelectionServiceProvider);
                final requiredPower = _parseDouble(
                  requiredPowerController.text,
                  fallback: requiredPowerWatts,
                );
                final flowTemp = _parseDouble(
                  flowController.text,
                  fallback: 70,
                );
                final returnTemp = _parseDouble(
                  returnController.text,
                  fallback: 55,
                );
                final roomTemp = room.comfortTemperatureC;
                final maxWidthMm = selectedWindowId == null
                    ? null
                    : windows
                              .firstWhere(
                                (opening) => opening.id == selectedWindowId,
                              )
                              .effectiveInstallationWidthMeters *
                          1000;
                final heights = helper.heights(
                  radiatorEntries,
                  type: selectedType,
                  panelType: selectedPanelType,
                  sectionWidthMm: selectedSectionWidth,
                );
                if (heights.isNotEmpty &&
                    !heights.any(
                      (height) => (height - selectedHeight).abs() < 0.5,
                    )) {
                  selectedHeight = heights.first;
                }
                final panelEntries = helper.panelCandidates(
                  entries: radiatorEntries,
                  panelType: selectedPanelType,
                  heightMm: selectedHeight,
                );
                final panelSelection = service.selectPanel(
                  entries: panelEntries,
                  requiredPowerWatts: requiredPower,
                  flowTempC: flowTemp,
                  returnTempC: returnTemp,
                  roomTempC: roomTemp,
                  maxWidthMm: maxWidthMm,
                );
                final sectionalEntry = helper.sectionalEntry(
                  entries: radiatorEntries,
                  sectionWidthMm: selectedSectionWidth,
                  heightMm: selectedHeight,
                );
                final sectionalSelection = sectionalEntry == null
                    ? null
                    : service.selectSectional(
                        entry: sectionalEntry,
                        requiredPowerWatts: requiredPower,
                        flowTempC: flowTemp,
                        returnTempC: returnTemp,
                        roomTempC: roomTemp,
                      );
                final usePanel = selectedType == RadiatorWizardType.panel;
                final suggestedEntry = manualMode
                    ? null
                    : usePanel
                    ? panelSelection?.entry
                    : sectionalEntry;
                final manualSectionPower = _parseDouble(
                  manualSectionPowerController.text,
                  fallback: 150,
                );
                final manualSections = manualSectionPower <= 0
                    ? 0
                    : (requiredPower / manualSectionPower).ceil();
                final actualPower = manualMode
                    ? usePanel
                          ? _parseDouble(
                              manualPanelPowerController.text,
                              fallback: requiredPower,
                            )
                          : manualSectionPower * manualSections
                    : usePanel
                    ? (panelSelection?.actualPowerWatts ?? requiredPower)
                    : (sectionalSelection?.actualPowerWatts ?? requiredPower);
                final sectionCount = usePanel
                    ? null
                    : manualMode
                    ? math.max(1, manualSections)
                    : sectionalSelection?.sectionCount;
                final supplyValve = findValve(supplyValveId);
                final returnValve = findValve(returnValveId);
                final previewDevice = HeatingDevice(
                  id: heatingDevice?.id ?? 'preview-heating-device',
                  roomId: room.id,
                  title: _requiredText(
                    titleController.text,
                    fallback: suggestedEntry?.title ?? selectedType.label,
                  ),
                  kind: HeatingDeviceKind.radiator,
                  ratedPowerWatts: actualPower,
                  catalogItemId: suggestedEntry?.id,
                  nominalPowerWatts: suggestedEntry?.ratedPowerWatts,
                  designFlowTempC: flowTemp,
                  designReturnTempC: returnTemp,
                  designRoomTempC: roomTemp,
                  valveCatalogItemId: supplyValve?.id,
                  valveSetting: supplyValveSetting,
                  supplyValveCatalogItemId: supplyValve?.id,
                  supplyValveSetting: supplyValveSetting,
                  returnValveCatalogItemId: returnValve?.id,
                  returnValveSetting: returnValveSetting,
                  sectionCount: sectionCount,
                  requiredPowerWatts: requiredPower,
                );
                final previewCalculation = service.calculateDevice(
                  device: previewDevice,
                  deviceCatalog: catalog.heatingDevices,
                  valveCatalog: catalog.heatingValves,
                  flowTempC: flowTemp,
                  returnTempC: returnTemp,
                  roomTempC: roomTemp,
                  requiredPowerWatts: requiredPower,
                );
                if (supplyValve?.hasSettings ?? false) {
                  supplyValveSetting ??= previewCalculation.supplyValveSetting;
                }
                if (returnValve?.hasSettings ?? false) {
                  returnValveSetting ??= previewCalculation.returnValveSetting;
                }
                if (titleController.text.trim().isEmpty &&
                    suggestedEntry != null) {
                  titleController.text = suggestedEntry.title;
                }

                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    12,
                    16,
                    16 + MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: SafeArea(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            heatingDevice == null
                                ? 'Конструктор радиатора'
                                : 'Редактирование радиатора',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 12),
                          Stepper(
                            currentStep: currentStep,
                            physics: const NeverScrollableScrollPhysics(),
                            controlsBuilder: (context, details) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Wrap(
                                  spacing: 8,
                                  children: [
                                    if (currentStep < 4)
                                      FilledButton(
                                        onPressed: () =>
                                            setState(() => currentStep += 1),
                                        child: const Text('Далее'),
                                      ),
                                    if (currentStep > 0)
                                      TextButton(
                                        onPressed: () =>
                                            setState(() => currentStep -= 1),
                                        child: const Text('Назад'),
                                      ),
                                  ],
                                ),
                              );
                            },
                            steps: [
                              Step(
                                title: const Text('Тип и нагрузка'),
                                isActive: currentStep >= 0,
                                content: Column(
                                  children: [
                                    SegmentedButton<RadiatorWizardType>(
                                      segments: RadiatorWizardType.values
                                          .map(
                                            (type) => ButtonSegment(
                                              value: type,
                                              label: Text(type.label),
                                            ),
                                          )
                                          .toList(),
                                      selected: {selectedType},
                                      onSelectionChanged: (value) {
                                        setState(() {
                                          selectedType = value.single;
                                          manualMode = false;
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: titleController,
                                      decoration: const InputDecoration(
                                        labelText: 'Название',
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: requiredPowerController,
                                      decoration: const InputDecoration(
                                        labelText: 'Требуемая мощность, Вт',
                                      ),
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ],
                                ),
                              ),
                              Step(
                                title: const Text('Параметры модели'),
                                isActive: currentStep >= 1,
                                content: Column(
                                  children: [
                                    if (usePanel)
                                      DropdownButtonFormField<String>(
                                        initialValue: selectedPanelType,
                                        isExpanded: true,
                                        decoration: const InputDecoration(
                                          labelText: 'Тип панели',
                                        ),
                                        items:
                                            (panelTypes.isEmpty
                                                    ? [selectedPanelType]
                                                    : panelTypes)
                                                .map(
                                                  (type) => DropdownMenuItem(
                                                    value: type,
                                                    child: Text('Тип $type'),
                                                  ),
                                                )
                                                .toList(),
                                        onChanged: (value) {
                                          if (value != null) {
                                            setState(() {
                                              selectedPanelType = value;
                                            });
                                          }
                                        },
                                      )
                                    else
                                      DropdownButtonFormField<double>(
                                        initialValue: selectedSectionWidth,
                                        isExpanded: true,
                                        decoration: const InputDecoration(
                                          labelText: 'Ширина секции',
                                        ),
                                        items:
                                            (sectionWidths.isEmpty
                                                    ? [selectedSectionWidth]
                                                    : sectionWidths)
                                                .map(
                                                  (width) => DropdownMenuItem(
                                                    value: width,
                                                    child: Text(
                                                      '${width.toStringAsFixed(0)} мм',
                                                    ),
                                                  ),
                                                )
                                                .toList(),
                                        onChanged: (value) {
                                          if (value != null) {
                                            setState(() {
                                              selectedSectionWidth = value;
                                            });
                                          }
                                        },
                                      ),
                                    const SizedBox(height: 12),
                                    DropdownButtonFormField<double>(
                                      initialValue: selectedHeight,
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                        labelText: 'Высота',
                                      ),
                                      items:
                                          (heights.isEmpty
                                                  ? [selectedHeight]
                                                  : heights)
                                              .map(
                                                (height) => DropdownMenuItem(
                                                  value: height,
                                                  child: Text(
                                                    '${height.toStringAsFixed(0)} мм',
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                      onChanged: (value) {
                                        if (value != null) {
                                          setState(
                                            () => selectedHeight = value,
                                          );
                                        }
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    if (windows.isNotEmpty && usePanel)
                                      DropdownButtonFormField<String>(
                                        initialValue: selectedWindowId,
                                        isExpanded: true,
                                        decoration: const InputDecoration(
                                          labelText: 'Монтажное окно',
                                        ),
                                        items: windows
                                            .map(
                                              (opening) => DropdownMenuItem(
                                                value: opening.id,
                                                child: Text(
                                                  '${opening.title} · ${(opening.effectiveInstallationWidthMeters * 1000).toStringAsFixed(0)} мм',
                                                ),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (value) {
                                          setState(
                                            () => selectedWindowId = value,
                                          );
                                        },
                                      ),
                                    SwitchListTile(
                                      contentPadding: EdgeInsets.zero,
                                      value: manualMode,
                                      title: const Text('Ручной ввод модели'),
                                      onChanged: (value) {
                                        setState(() => manualMode = value);
                                      },
                                    ),
                                    if (manualMode && usePanel) ...[
                                      const SizedBox(height: 8),
                                      TextField(
                                        controller: manualPanelWidthController,
                                        decoration: const InputDecoration(
                                          labelText: 'Ширина, мм',
                                        ),
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                      ),
                                      const SizedBox(height: 12),
                                      TextField(
                                        controller: manualPanelPowerController,
                                        decoration: const InputDecoration(
                                          labelText: 'Мощность модели, Вт',
                                        ),
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ],
                                    if (manualMode && !usePanel) ...[
                                      const SizedBox(height: 8),
                                      TextField(
                                        controller:
                                            manualSectionPowerController,
                                        decoration: const InputDecoration(
                                          labelText:
                                              'Мощность одной секции, Вт',
                                        ),
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Step(
                                title: const Text('Температуры'),
                                isActive: currentStep >= 2,
                                content: Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: flowController,
                                        decoration: const InputDecoration(
                                          labelText: 'Подача, °C',
                                        ),
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextField(
                                        controller: returnController,
                                        decoration: const InputDecoration(
                                          labelText: 'Обратка, °C',
                                        ),
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Step(
                                title: const Text('Арматура'),
                                isActive: currentStep >= 3,
                                content: Column(
                                  children: [
                                    _ValvePicker(
                                      label: 'Арматура подачи',
                                      valves: catalog.heatingValves,
                                      selectedValveId: supplyValveId,
                                      selectedSetting: supplyValveSetting,
                                      onChanged: (valveId, setting) {
                                        setState(() {
                                          supplyValveId = valveId;
                                          supplyValveSetting = setting;
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    _ValvePicker(
                                      label: 'Арматура обратки',
                                      valves: catalog.heatingValves,
                                      selectedValveId: returnValveId,
                                      selectedSetting: returnValveSetting,
                                      onChanged: (valveId, setting) {
                                        setState(() {
                                          returnValveId = valveId;
                                          returnValveSetting = setting;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              Step(
                                title: const Text('Предпросмотр'),
                                isActive: currentStep >= 4,
                                content: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _MetricChip(
                                          label: 'Мощность',
                                          value:
                                              '${actualPower.toStringAsFixed(0)} Вт',
                                        ),
                                        if (sectionCount != null)
                                          _MetricChip(
                                            label: 'Секций',
                                            value: sectionCount.toString(),
                                          ),
                                        _MetricChip(
                                          label: 'Расход',
                                          value:
                                              '${previewCalculation.flowRateLitersPerMinute.toStringAsFixed(2)} л/мин',
                                        ),
                                        if (previewCalculation
                                                .supplyValvePressureDropKpa !=
                                            null)
                                          _MetricChip(
                                            label: 'Подача',
                                            value:
                                                '${previewCalculation.supplyValvePressureDropKpa!.toStringAsFixed(1)} кПа',
                                          ),
                                        if (previewCalculation
                                                .returnValvePressureDropKpa !=
                                            null)
                                          _MetricChip(
                                            label: 'Обратка',
                                            value:
                                                '${previewCalculation.returnValvePressureDropKpa!.toStringAsFixed(1)} кПа',
                                          ),
                                        if (previewCalculation
                                                .valvePressureDropKpa !=
                                            null)
                                          _MetricChip(
                                            label: 'Суммарно',
                                            value:
                                                '${previewCalculation.valvePressureDropKpa!.toStringAsFixed(1)} кПа',
                                          ),
                                        if (suggestedEntry != null)
                                          _MetricChip(
                                            label: 'Каталог',
                                            value: suggestedEntry.title,
                                          ),
                                        if (manualMode)
                                          const _MetricChip(
                                            label: 'Источник',
                                            value: 'Ручная запись',
                                          ),
                                      ],
                                    ),
                                    if (maxWidthMm != null) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        'Окно: ${maxWidthMm.toStringAsFixed(0)} мм',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ],
                                    if (underfloorPowerWatts > 0) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Теплый пол: ${underfloorPowerWatts.toStringAsFixed(0)} Вт уже учтен в остаточной нагрузке.',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ],
                                    if (previewCalculation
                                        .warnings
                                        .isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      ...previewCalculation.warnings.map(
                                        (warning) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 4,
                                          ),
                                          child: Text(
                                            warning,
                                            style: TextStyle(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.error,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 16),
                                    FilledButton.icon(
                                      onPressed: () {
                                        final id =
                                            heatingDevice?.id ??
                                            'heating-device-${DateTime.now().millisecondsSinceEpoch}';
                                        final customEntry = manualMode
                                            ? helper.buildManualEntry(
                                                id: id,
                                                type: selectedType,
                                                title: _requiredText(
                                                  titleController.text,
                                                  fallback: selectedType.label,
                                                ),
                                                panelType: selectedPanelType,
                                                widthMm: usePanel
                                                    ? _parseDouble(
                                                        manualPanelWidthController
                                                            .text,
                                                        fallback: 1000,
                                                      )
                                                    : selectedSectionWidth,
                                                heightMm: selectedHeight,
                                                ratedPowerWatts: usePanel
                                                    ? actualPower
                                                    : manualSectionPower,
                                                flowTempC: flowTemp,
                                                returnTempC: returnTemp,
                                                roomTempC: roomTemp,
                                              )
                                            : null;
                                        final catalogItemId =
                                            customEntry?.id ??
                                            suggestedEntry?.id;
                                        final savedPreview = previewDevice
                                            .copyWith(
                                              id: id,
                                              title: _requiredText(
                                                titleController.text,
                                                fallback:
                                                    customEntry?.title ??
                                                    suggestedEntry?.title ??
                                                    selectedType.label,
                                              ),
                                              catalogItemId: catalogItemId,
                                              nominalPowerWatts:
                                                  customEntry
                                                      ?.ratedPowerWatts ??
                                                  suggestedEntry
                                                      ?.ratedPowerWatts,
                                              clearCatalogItemId:
                                                  catalogItemId == null,
                                              clearNominalPowerWatts:
                                                  customEntry == null &&
                                                  suggestedEntry == null,
                                            );
                                        final savedCalculation = service
                                            .calculateDevice(
                                              device: savedPreview,
                                              deviceCatalog: customEntry == null
                                                  ? catalog.heatingDevices
                                                  : [
                                                      ...catalog.heatingDevices,
                                                      customEntry,
                                                    ],
                                              valveCatalog:
                                                  catalog.heatingValves,
                                              flowTempC: flowTemp,
                                              returnTempC: returnTemp,
                                              roomTempC: roomTemp,
                                              requiredPowerWatts: requiredPower,
                                            );
                                        Navigator.of(context).pop(
                                          HeatingDeviceWizardResult(
                                            customCatalogEntry: customEntry,
                                            heatingDevice: savedPreview.copyWith(
                                              valveCatalogItemId: supplyValveId,
                                              valveSetting: savedCalculation
                                                  .supplyValveSetting,
                                              supplyValveCatalogItemId:
                                                  supplyValveId,
                                              supplyValveSetting:
                                                  savedCalculation
                                                      .supplyValveSetting,
                                              supplyValvePressureDropKpa:
                                                  savedCalculation
                                                      .supplyValvePressureDropKpa,
                                              returnValveCatalogItemId:
                                                  returnValveId,
                                              returnValveSetting:
                                                  savedCalculation
                                                      .returnValveSetting,
                                              returnValvePressureDropKpa:
                                                  savedCalculation
                                                      .returnValvePressureDropKpa,
                                              designFlowRateLitersPerMinute:
                                                  savedCalculation
                                                      .flowRateLitersPerMinute,
                                              valvePressureDropKpa:
                                                  savedCalculation
                                                      .valvePressureDropKpa,
                                              calculatedPowerWatts:
                                                  savedCalculation
                                                      .calculatedPowerWatts,
                                              requiredPowerWatts: requiredPower,
                                              clearValveCatalogItemId:
                                                  supplyValveId == null,
                                              clearValveSetting:
                                                  savedCalculation
                                                      .supplyValveSetting ==
                                                  null,
                                              clearSupplyValveCatalogItemId:
                                                  supplyValveId == null,
                                              clearSupplyValveSetting:
                                                  savedCalculation
                                                      .supplyValveSetting ==
                                                  null,
                                              clearSupplyValvePressureDropKpa:
                                                  savedCalculation
                                                      .supplyValvePressureDropKpa ==
                                                  null,
                                              clearReturnValveCatalogItemId:
                                                  returnValveId == null,
                                              clearReturnValveSetting:
                                                  savedCalculation
                                                      .returnValveSetting ==
                                                  null,
                                              clearReturnValvePressureDropKpa:
                                                  savedCalculation
                                                      .returnValvePressureDropKpa ==
                                                  null,
                                              clearValvePressureDropKpa:
                                                  savedCalculation
                                                      .valvePressureDropKpa ==
                                                  null,
                                            ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.save_outlined),
                                      label: const Text('Сохранить радиатор'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  } finally {
    titleController.dispose();
    requiredPowerController.dispose();
    flowController.dispose();
    returnController.dispose();
    manualPanelWidthController.dispose();
    manualPanelPowerController.dispose();
    manualSectionPowerController.dispose();
  }
}

class _ValvePicker extends StatelessWidget {
  const _ValvePicker({
    required this.label,
    required this.valves,
    required this.selectedValveId,
    required this.selectedSetting,
    required this.onChanged,
  });

  final String label;
  final List<HeatingValveCatalogEntry> valves;
  final String? selectedValveId;
  final String? selectedSetting;
  final void Function(String? valveId, String? setting) onChanged;

  @override
  Widget build(BuildContext context) {
    final selectedValve = selectedValveId == null
        ? null
        : valves.where((entry) => entry.id == selectedValveId).firstOrNull;
    final hasSettings = selectedValve?.hasSettings ?? false;
    final effectiveSetting =
        hasSettings && selectedValve!.settingKvMap.containsKey(selectedSetting)
        ? selectedSetting
        : null;
    return Column(
      children: [
        DropdownButtonFormField<String?>(
          initialValue: selectedValveId,
          isExpanded: true,
          decoration: InputDecoration(labelText: label),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Без арматуры'),
            ),
            ...valves.map(
              (entry) => DropdownMenuItem<String?>(
                value: entry.id,
                child: Text(entry.title),
              ),
            ),
          ],
          onChanged: (value) => onChanged(value, null),
        ),
        if (hasSettings) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: effectiveSetting,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Преднастройка'),
            items: selectedValve!.settingKvMap.entries
                .map(
                  (entry) => DropdownMenuItem(
                    value: entry.key,
                    child: Text(
                      '${entry.key} · Kv ${entry.value.toStringAsFixed(2)}',
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) => onChanged(selectedValveId, value),
          ),
        ],
      ],
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: $value'),
      visualDensity: VisualDensity.compact,
    );
  }
}

double _parseDouble(String value, {required double fallback}) {
  return double.tryParse(value.replaceAll(',', '.')) ?? fallback;
}

String _requiredText(String value, {required String fallback}) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? fallback : trimmed;
}

extension _IterableFirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
