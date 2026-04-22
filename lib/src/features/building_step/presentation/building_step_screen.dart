import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../construction_library/presentation/construction_step_screen.dart';
import 'room_editor_step_screen.dart';

class BuildingStepScreen extends ConsumerWidget {
  const BuildingStepScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RoomEditorStepScreen(
      screenTitle: 'Шаг 2. Помещения',
      statusText:
          'После выбора помещения укажите режим «Комфорт», приток воздуха и настройте ограждающие конструкции комнаты. Теплопотери по ограждениям, вентиляции и помещению обновляются автоматически.',
      previousStepLabel: 'Вернуться к шагу 1',
      onOpenPreviousStep: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const ConstructionStepScreen(),
          ),
        );
      },
    );
  }
}
