import 'package:flutter/material.dart';

import '../../../core/models/catalog.dart';
import '../../../core/models/project.dart';

String buildEditorId(String prefix) {
  return '$prefix-${DateTime.now().microsecondsSinceEpoch}';
}

double parseEditorDouble(String value, {required double fallback}) {
  return double.tryParse(value.replaceAll(',', '.')) ?? fallback;
}

String requireEditorText(String value, {required String fallback}) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? fallback : trimmed;
}

Future<EnvelopeOpening?> showOpeningEditorSheet(
  BuildContext context, {
  required CatalogSnapshot catalog,
  required HouseEnvelopeElement element,
  OpeningKind? initialKind,
  EnvelopeOpening? opening,
}) async {
  final widthController = TextEditingController(
    text:
        (opening?.widthMeters ??
                (opening?.kind ?? initialKind ?? OpeningKind.window)
                    .defaultOpeningWidthMeters)
            .toStringAsFixed(2),
  );
  final heightController = TextEditingController(
    text:
        (opening?.heightMeters ??
                (opening?.kind ?? initialKind ?? OpeningKind.window)
                    .defaultOpeningHeightMeters)
            .toStringAsFixed(2),
  );
  final coefficientController = TextEditingController(
    text:
        (opening?.heatTransferCoefficient ??
                (opening?.kind ?? initialKind ?? OpeningKind.window)
                    .defaultHeatTransferCoefficient)
            .toStringAsFixed(2),
  );
  var selectedKind = opening?.kind ?? initialKind ?? OpeningKind.window;
  String? selectedCatalogId = opening?.catalogTypeId;

  final result = await showModalBottomSheet<EnvelopeOpening>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          final catalogEntries = catalog.openingCatalog
              .where((item) => item.kind == selectedKind)
              .toList(growable: false);
          OpeningTypeEntry? selectedCatalogEntry;
          if (selectedCatalogId != null) {
            for (final item in catalogEntries) {
              if (item.id == selectedCatalogId) {
                selectedCatalogEntry = item;
                break;
              }
            }
          }
          if (selectedCatalogId != null &&
              !catalogEntries.any((item) => item.id == selectedCatalogId)) {
            selectedCatalogId = null;
          }
          final widthMeters = parseEditorDouble(
            widthController.text,
            fallback: selectedKind.defaultOpeningWidthMeters,
          );
          final heightMeters = parseEditorDouble(
            heightController.text,
            fallback: selectedKind.defaultOpeningHeightMeters,
          );
          final areaSquareMeters = widthMeters * heightMeters;
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
                  opening == null ? 'Новый проём' : 'Редактирование проёма',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<OpeningKind>(
                  initialValue: selectedKind,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Тип проёма'),
                  items: OpeningKind.values
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedKind = value;
                        selectedCatalogId = null;
                        widthController.text = value.defaultOpeningWidthMeters
                            .toStringAsFixed(2);
                        heightController.text = value.defaultOpeningHeightMeters
                            .toStringAsFixed(2);
                        coefficientController.text = value
                            .defaultHeatTransferCoefficient
                            .toStringAsFixed(2);
                      });
                    }
                  },
                ),
                if (catalogEntries.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: selectedCatalogId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Шаблон из каталога',
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Без шаблона'),
                      ),
                      ...catalogEntries.map(
                        (item) => DropdownMenuItem<String?>(
                          value: item.id,
                          child: Text(
                            '${item.title} • U ${item.heatTransferCoefficient.toStringAsFixed(2)}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedCatalogId = value;
                        if (value == null) {
                          widthController.text = selectedKind
                              .defaultOpeningWidthMeters
                              .toStringAsFixed(2);
                          heightController.text = selectedKind
                              .defaultOpeningHeightMeters
                              .toStringAsFixed(2);
                          coefficientController.text = selectedKind
                              .defaultHeatTransferCoefficient
                              .toStringAsFixed(2);
                          return;
                        }
                        final selected = catalogEntries.firstWhere(
                          (item) => item.id == value,
                        );
                        if (selected.defaultWidthMeters != null) {
                          widthController.text = selected.defaultWidthMeters!
                              .toStringAsFixed(2);
                        }
                        if (selected.defaultHeightMeters != null) {
                          heightController.text = selected.defaultHeightMeters!
                              .toStringAsFixed(2);
                        }
                        coefficientController.text = selected
                            .heatTransferCoefficient
                            .toStringAsFixed(2);
                      });
                    },
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: widthController,
                        decoration: const InputDecoration(
                          labelText: 'Ширина, м',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: heightController,
                        decoration: const InputDecoration(
                          labelText: 'Высота, м',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Площадь: ${areaSquareMeters.toStringAsFixed(2)} м²',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: coefficientController,
                  decoration: const InputDecoration(labelText: 'U, Вт/м²·°C'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ограждение: ${element.title} • максимум ${element.areaSquareMeters.toStringAsFixed(2)} м²',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop(
                      EnvelopeOpening(
                        id: opening?.id ?? buildEditorId('opening'),
                        elementId: element.id,
                        title:
                            selectedCatalogEntry?.title ?? selectedKind.label,
                        kind: selectedKind,
                        widthMeters: widthMeters,
                        heightMeters: heightMeters,
                        installationWidthMeters: widthMeters,
                        heatTransferCoefficient: parseEditorDouble(
                          coefficientController.text,
                          fallback: selectedKind.defaultHeatTransferCoefficient,
                        ),
                        catalogTypeId: selectedCatalogEntry?.id,
                      ),
                    );
                  },
                  child: const Text('Сохранить проём'),
                ),
              ],
            ),
          );
        },
      );
    },
  );

  widthController.dispose();
  heightController.dispose();
  coefficientController.dispose();
  return result;
}
