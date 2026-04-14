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
  required String elementId,
  OpeningKind? initialKind,
  EnvelopeOpening? opening,
}) async {
  final titleController = TextEditingController(text: opening?.title ?? '');
  final areaController = TextEditingController(
    text: (opening?.areaSquareMeters ?? 2.0).toString(),
  );
  final coefficientController = TextEditingController(
    text:
        (opening?.heatTransferCoefficient ??
                (opening?.kind ?? initialKind ?? OpeningKind.window)
                    .defaultHeatTransferCoefficient)
            .toString(),
  );
  var selectedKind = opening?.kind ?? initialKind ?? OpeningKind.window;
  String? selectedCatalogId;

  final result = await showModalBottomSheet<EnvelopeOpening>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          final catalogEntries = catalog.openingCatalog
              .where((item) => item.kind == selectedKind)
              .toList(growable: false);
          if (selectedCatalogId != null &&
              !catalogEntries.any((item) => item.id == selectedCatalogId)) {
            selectedCatalogId = null;
          }
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
                        coefficientController.text = value
                            .defaultHeatTransferCoefficient
                            .toString();
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
                            '${item.title} • ${item.widthMeters.toStringAsFixed(2)}×${item.heightMeters.toStringAsFixed(2)} м • U ${item.heatTransferCoefficient.toStringAsFixed(2)}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedCatalogId = value;
                        if (value == null) {
                          return;
                        }
                        final selected = catalogEntries.firstWhere(
                          (item) => item.id == value,
                        );
                        titleController.text = selected.title;
                        areaController.text = selected.areaSquareMeters
                            .toStringAsFixed(2);
                        coefficientController.text = selected
                            .heatTransferCoefficient
                            .toStringAsFixed(2);
                      });
                    },
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Название'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: areaController,
                  decoration: const InputDecoration(labelText: 'Площадь, м²'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: coefficientController,
                  decoration: const InputDecoration(labelText: 'U, Вт/м²·°C'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop(
                      EnvelopeOpening(
                        id: opening?.id ?? buildEditorId('opening'),
                        elementId: elementId,
                        title: requireEditorText(
                          titleController.text,
                          fallback: selectedKind.label,
                        ),
                        kind: selectedKind,
                        areaSquareMeters: parseEditorDouble(
                          areaController.text,
                          fallback: 2.0,
                        ),
                        heatTransferCoefficient: parseEditorDouble(
                          coefficientController.text,
                          fallback: selectedKind.defaultHeatTransferCoefficient,
                        ),
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

  titleController.dispose();
  areaController.dispose();
  coefficientController.dispose();
  return result;
}
