import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/building_heat_loss/presentation/building_heat_loss_screen.dart';
import '../../features/building_step/presentation/building_step_screen.dart';
import '../../features/construction_library/presentation/construction_step_screen.dart';
import '../../features/ground_floor/presentation/ground_floor_screen.dart';
import '../../features/heating_economics/presentation/heating_economics_screen.dart';
import '../../features/house_scheme/presentation/house_scheme_screen.dart';
import '../../features/object_step/presentation/object_step_screen.dart';
import '../../features/thermocalc/presentation/thermocalc_screen.dart';

enum AppTab { home, project, plan, calculations, settings }

class CurrentAppTabNotifier extends Notifier<AppTab> {
  @override
  AppTab build() => AppTab.home;

  void select(AppTab tab) {
    state = tab;
  }
}

final currentAppTabProvider = NotifierProvider<CurrentAppTabNotifier, AppTab>(
  CurrentAppTabNotifier.new,
);

void switchToTab(WidgetRef ref, AppTab tab) {
  ref.read(currentAppTabProvider.notifier).select(tab);
}

Future<void> openObjectStepScreen(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const ObjectStepScreen()),
  );
}

Future<void> openConstructionStepScreen(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const ConstructionStepScreen()),
  );
}

Future<void> openBuildingStepScreen(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const BuildingStepScreen()),
  );
}

Future<void> openHouseSchemeScreen(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const HouseSchemeScreen()),
  );
}

Future<void> openThermocalcScreen(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const ThermocalcScreen()),
  );
}

Future<void> openBuildingHeatLossScreen(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const BuildingHeatLossScreen()),
  );
}

Future<void> openGroundFloorScreen(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const GroundFloorScreen()),
  );
}

Future<void> openHeatingEconomicsScreen(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const HeatingEconomicsScreen()),
  );
}
