import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/building_heat_loss.dart';
import '../../../core/models/heating_economics.dart';
import '../../../core/models/project.dart';
import '../../../core/providers.dart';
import '../../building_heat_loss/presentation/building_heat_loss_screen.dart';

class HeatingEconomicsScreen extends ConsumerStatefulWidget {
  const HeatingEconomicsScreen({super.key});

  @override
  ConsumerState<HeatingEconomicsScreen> createState() =>
      _HeatingEconomicsScreenState();
}

class _HeatingEconomicsScreenState
    extends ConsumerState<HeatingEconomicsScreen> {
  late final TextEditingController _electricityPriceController;
  late final TextEditingController _gasPriceController;
  String? _lastSyncedProjectId;

  @override
  void initState() {
    super.initState();
    _electricityPriceController = TextEditingController();
    _gasPriceController = TextEditingController();
  }

  @override
  void dispose() {
    _electricityPriceController.dispose();
    _gasPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projectAsync = ref.watch(selectedProjectProvider);
    final buildingHeatLossAsync = ref.watch(buildingHeatLossResultProvider);
    final economicsAsync = ref.watch(heatingEconomicsResultProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Шаг 3. Отопление и экономика',
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
              _syncControllers(project);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProjectStatusCard(project: project),
                  const SizedBox(height: 16),
                  buildingHeatLossAsync.when(
                    data: (buildingHeatLoss) {
                      if (buildingHeatLoss == null) {
                        return const Text('Расчет теплопотерь недоступен.');
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _HeatLossSummaryCard(result: buildingHeatLoss),
                          const SizedBox(height: 16),
                          _TariffCard(
                            electricityPriceController:
                                _electricityPriceController,
                            gasPriceController: _gasPriceController,
                            onSave: () => _saveTariffs(project),
                          ),
                          const SizedBox(height: 16),
                          economicsAsync.when(
                            data: (economics) {
                              if (economics == null) {
                                return const Text(
                                  'Экономика отопления недоступна.',
                                );
                              }
                              return _EconomicsBody(
                                project: project,
                                buildingHeatLoss: buildingHeatLoss,
                                economics: economics,
                              );
                            },
                            loading: () => const LinearProgressIndicator(),
                            error: (error, _) =>
                                Text('Ошибка экономики: $error'),
                          ),
                        ],
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (error, _) => Text('Ошибка теплопотерь: $error'),
                  ),
                ],
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text('Ошибка проекта: $error'),
          ),
        ],
      ),
    );
  }

  void _syncControllers(Project project) {
    if (_lastSyncedProjectId == project.id) {
      return;
    }
    _lastSyncedProjectId = project.id;
    _electricityPriceController.text = project
        .heatingEconomicsSettings
        .electricityPricePerKwh
        .toStringAsFixed(2);
    _gasPriceController.text = project
        .heatingEconomicsSettings
        .gasPricePerCubicMeter
        .toStringAsFixed(2);
  }

  Future<void> _saveTariffs(Project project) async {
    final electricityPrice = double.tryParse(
      _electricityPriceController.text.replaceAll(',', '.'),
    );
    final gasPrice = double.tryParse(
      _gasPriceController.text.replaceAll(',', '.'),
    );
    if (electricityPrice == null ||
        gasPrice == null ||
        electricityPrice < 0 ||
        gasPrice < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите корректные тарифы.')),
      );
      return;
    }

    try {
      await ref
          .read(projectEditorProvider)
          .updateHeatingEconomicsSettings(
            project.heatingEconomicsSettings.copyWith(
              electricityPricePerKwh: electricityPrice,
              gasPricePerCubicMeter: gasPrice,
            ),
          );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Тарифы сохранены.')));
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

class _ProjectStatusCard extends StatelessWidget {
  const _ProjectStatusCard({required this.project});

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
              'Шаг 3 использует собранную модель дома и климат объекта для оценки сезонной стоимости отопления.',
            ),
          ],
        ),
      ),
    );
  }
}

class _HeatLossSummaryCard extends StatelessWidget {
  const _HeatLossSummaryCard({required this.result});

  final BuildingHeatLossResult result;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Итог теплопотерь',
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
                  label: 'Итого',
                  value: '${result.totalHeatLossWatts.toStringAsFixed(0)} Вт',
                ),
                _MetricTile(
                  label: 'Ограждения',
                  value:
                      '${result.totalOpaqueHeatLossWatts.toStringAsFixed(0)} Вт',
                ),
                _MetricTile(
                  label: 'Проемы',
                  value:
                      '${result.totalOpeningHeatLossWatts.toStringAsFixed(0)} Вт',
                ),
                _MetricTile(
                  label: 'Баланс отопления',
                  value:
                      '${result.totalHeatingPowerDeltaWatts.toStringAsFixed(0)} Вт',
                ),
                _MetricTile(
                  label: 'Помещения',
                  value: '${result.totalRoomCount}',
                ),
                _MetricTile(
                  label: 'Без расчета',
                  value: '${result.unresolvedElements.length}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TariffCard extends StatelessWidget {
  const _TariffCard({
    required this.electricityPriceController,
    required this.gasPriceController,
    required this.onSave,
  });

  final TextEditingController electricityPriceController;
  final TextEditingController gasPriceController;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Тарифы',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('electricity-price-field'),
              controller: electricityPriceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Стоимость 1 кВт·ч электроэнергии',
                suffixText: '₽',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('gas-price-field'),
              controller: gasPriceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Стоимость 1 м³ газа',
                suffixText: '₽',
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: onSave,
                child: const Text('Сохранить тарифы'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EconomicsBody extends StatelessWidget {
  const _EconomicsBody({
    required this.project,
    required this.buildingHeatLoss,
    required this.economics,
  });

  final Project project;
  final BuildingHeatLossResult buildingHeatLoss;
  final HeatingEconomicsResult economics;

  @override
  Widget build(BuildContext context) {
    final settings = project.heatingEconomicsSettings;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (buildingHeatLoss.unresolvedElements.isNotEmpty) ...[
          Card(
            color: const Color(0xFFFFF4E5),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'В расчете пропущено элементов: ${buildingHeatLoss.unresolvedElements.length}. Экономика рассчитана только по учтенным ограждениям.',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Экономика за сезон',
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
                      label: 'Потребность в тепле',
                      value:
                          '${economics.seasonalHeatDemandKwh.toStringAsFixed(0)} кВт·ч',
                    ),
                    _MetricTile(
                      label: 'Отопительный период',
                      value: '${economics.heatingPeriodDays} сут',
                    ),
                    _MetricTile(
                      label: 'Средняя внутренняя',
                      value:
                          '${economics.averageIndoorTemperature.toStringAsFixed(1)} °C',
                    ),
                    _MetricTile(
                      label: 'Средняя цена/мес',
                      value:
                          '${economics.electricity.averageMonthlyCost.toStringAsFixed(0)} ₽ эл.',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SourceCard(
                  title: 'Электричество',
                  energyLabel:
                      '${economics.electricity.energyInputKwh.toStringAsFixed(0)} кВт·ч за сезон',
                  seasonalCost:
                      '${economics.electricity.seasonalCost.toStringAsFixed(0)} ₽ за сезон',
                  monthlyCost:
                      '${economics.electricity.averageMonthlyCost.toStringAsFixed(0)} ₽/мес',
                ),
                const SizedBox(height: 12),
                _SourceCard(
                  title: 'Газ',
                  energyLabel:
                      '${economics.gas.gasConsumptionCubicMeters?.toStringAsFixed(0) ?? '0'} м³ за сезон',
                  seasonalCost:
                      '${economics.gas.seasonalCost.toStringAsFixed(0)} ₽ за сезон',
                  monthlyCost:
                      '${economics.gas.averageMonthlyCost.toStringAsFixed(0)} ₽/мес',
                ),
                const SizedBox(height: 12),
                _SourceCard(
                  title: 'Тепловой насос',
                  energyLabel:
                      '${economics.heatPump.energyInputKwh.toStringAsFixed(0)} кВт·ч эл. за сезон',
                  seasonalCost:
                      '${economics.heatPump.seasonalCost.toStringAsFixed(0)} ₽ за сезон',
                  monthlyCost:
                      '${economics.heatPump.averageMonthlyCost.toStringAsFixed(0)} ₽/мес',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Принятые допущения',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'КПД газового котла: ${settings.gasBoilerEfficiency.toStringAsFixed(2)}. '
                  'COP теплового насоса: ${settings.heatPumpCop.toStringAsFixed(1)}. '
                  'Теплота газа: 9.3 кВт·ч/м³. '
                  'v1 уже учитывает вентиляцию и инфильтрацию, но пока не учитывает мостики холода.',
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const BuildingHeatLossScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.analytics_outlined),
                  label: const Text('Открыть детальный расчет'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.title,
    required this.energyLabel,
    required this.seasonalCost,
    required this.monthlyCost,
  });

  final String title;
  final String energyLabel;
  final String seasonalCost;
  final String monthlyCost;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F5EE),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(energyLabel),
            const SizedBox(height: 4),
            Text(seasonalCost),
            const SizedBox(height: 4),
            Text(monthlyCost),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(label),
        ],
      ),
    );
  }
}
