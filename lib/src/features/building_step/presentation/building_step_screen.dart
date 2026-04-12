import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../construction_library/presentation/construction_step_screen.dart';
import '../../house_scheme/presentation/house_scheme_screen.dart';

class BuildingStepScreen extends ConsumerWidget {
  const BuildingStepScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return HouseSchemeScreen(
      screenTitle: 'Шаг 2. План дома',
      statusText:
          'После выбора ограждающих конструкций на шаге 1 здесь формируется план дома: помещения, ограждения и проёмы. Когда планировка собрана, можно сразу открыть расчёт суммарных теплопотерь по зданию.',
      limitToSelectedConstructions: true,
      showConstructionsCard: false,
      showHeatingDevices: false,
      constructorCardTitle: 'Конструктор дома',
      constructorCardCollapsedByDefault: true,
      previousStepLabel: 'Вернуться к шагу 1',
      onOpenPreviousStep: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const ConstructionStepScreen(),
          ),
        );
      },
      showFloorPlanEditor: false,
      showRoomSelectionSidebar: true,
    );
  }
}
