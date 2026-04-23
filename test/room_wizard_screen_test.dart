import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartcalc_mobile/src/core/models/project.dart';
import 'package:smartcalc_mobile/src/core/providers.dart';
import 'package:smartcalc_mobile/src/features/house_scheme/presentation/house_scheme_screen.dart';
import 'package:smartcalc_mobile/src/features/house_scheme/presentation/room_wizard_screen.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('room kind updates generated title until user edits manually', (
    tester,
  ) async {
    final repository = FakeProjectRepository();
    final project = (await repository.getProject('demo'))!;

    await _pumpWizard(tester, repository: repository, project: project);

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('room-wizard-title-field')),
        matching: find.text('Помещение №2'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('room-kind-bedroom')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('room-wizard-title-field')),
        matching: find.text('Спальня'),
      ),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('room-wizard-title-field')),
      'Моя спальня',
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('room-kind-kitchen')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('room-wizard-title-field')),
        matching: find.text('Моя спальня'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('wizard saves room layout dimensions', (tester) async {
    final repository = FakeProjectRepository();
    final project = (await repository.getProject('demo'))!;

    await _pumpWizard(tester, repository: repository, project: project);

    await _completeStepOne(tester);
    await tester.enterText(
      find.byKey(const ValueKey('room-wizard-width-field')),
      '5',
    );
    await tester.enterText(
      find.byKey(const ValueKey('room-wizard-length-field')),
      '6',
    );
    await tester.pump();

    expect(find.text('Площадь: 30.00 м²'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('room-wizard-next-step2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('room-wizard-next-step3')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('room-wizard-save')));
    await tester.tap(find.byKey(const ValueKey('room-wizard-save')));
    await tester.pumpAndSettle();

    final savedProject = (await repository.getProject('demo'))!;
    final room = savedProject.houseModel.rooms.last;
    expect(room.layout.widthMeters, 5);
    expect(room.layout.heightMeters, 6);
    expect(room.areaSquareMeters, 30);
  });

  testWidgets(
    'wall envelope sheet uses area input on narrow width without overflow',
    (tester) async {
      final project = buildTestProject(
        constructions: [
          buildWallConstruction().copyWith(
            id: 'wall-long',
            title:
                'Наружная стена с очень длинным названием конструкции для проверки переполнения строки',
          ),
        ],
      );
      final repository = FakeProjectRepository(projects: [project]);

      await _pumpWizard(
        tester,
        repository: repository,
        project: project,
        surfaceSize: const Size(390, 844),
      );

      await _completeStepOne(tester);
      await tester.tap(find.byKey(const ValueKey('room-wizard-next-step2')));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('room-wizard-add-envelope-button')),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey('envelope-room-side-field')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('envelope-length-field')), findsNothing);
      expect(find.byKey(const ValueKey('envelope-area-field')), findsOneWidget);
      expect(find.text('Площадь стены, м²'), findsOneWidget);
    },
  );

  testWidgets('wizard saves draft envelope and opening with room', (
    tester,
  ) async {
    final repository = FakeProjectRepository();
    final project = (await repository.getProject('demo'))!;

    await _pumpWizard(tester, repository: repository, project: project);

    await _completeStepOne(tester);
    await tester.tap(find.byKey(const ValueKey('room-wizard-next-step2')));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('room-wizard-add-envelope-button')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('envelope-room-side-field')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('envelope-length-field')), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('envelope-area-field')),
      '18.5',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('envelope-wizard-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('envelope-add-opening-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить проём'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('envelope-wizard-finish')));
    await tester.pumpAndSettle();

    expect(find.text('Сверху'), findsNothing);
    expect(find.text('Снизу'), findsNothing);
    expect(find.text('Слева'), findsNothing);
    expect(find.text('Справа'), findsNothing);
    expect(find.textContaining('сегмент'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('room-wizard-next-step3')));
    await tester.pumpAndSettle();

    expect(find.text('Сверху'), findsNothing);
    expect(find.text('Снизу'), findsNothing);
    expect(find.text('Слева'), findsNothing);
    expect(find.text('Справа'), findsNothing);
    expect(find.textContaining('сегмент'), findsNothing);

    await tester.ensureVisible(find.byKey(const ValueKey('room-wizard-save')));
    await tester.tap(find.byKey(const ValueKey('room-wizard-save')));
    await tester.pumpAndSettle();

    final savedProject = (await repository.getProject('demo'))!;
    final room = savedProject.houseModel.rooms.last;
    final roomElements = savedProject.houseModel.elements
        .where((element) => element.roomId == room.id)
        .toList(growable: false);

    expect(roomElements, hasLength(1));
    expect(
      savedProject.houseModel.openings.where(
        (opening) => opening.elementId == roomElements.single.id,
      ),
      hasLength(1),
    );
  });

  testWidgets('step four preview reacts to comfort and ventilation changes', (
    tester,
  ) async {
    final repository = FakeProjectRepository();
    final project = (await repository.getProject('demo'))!;

    await _pumpWizard(tester, repository: repository, project: project);

    await _completeStepOne(tester);
    await tester.tap(find.byKey(const ValueKey('room-wizard-next-step2')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('room-wizard-add-envelope-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('envelope-wizard-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('envelope-wizard-finish')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('room-wizard-next-step3')));
    await tester.pumpAndSettle();

    final before = tester
        .widget<Text>(
          find
              .descendant(
                of: find.byKey(const ValueKey('room-wizard-heat-loss-card')),
                matching: find.textContaining('Вт'),
              )
              .last,
        )
        .data!;

    await tester.enterText(
      find.byKey(const ValueKey('room-wizard-review-comfort-field')),
      '25',
    );
    await tester.enterText(
      find.byKey(const ValueKey('room-wizard-review-ventilation-field')),
      '30',
    );
    await tester.pump();

    final after = tester
        .widget<Text>(
          find
              .descendant(
                of: find.byKey(const ValueKey('room-wizard-heat-loss-card')),
                matching: find.textContaining('Вт'),
              )
              .last,
        )
        .data!;
    expect(after, isNot(equals(before)));
  });

  testWidgets('close button exits immediately when no data entered', (
    tester,
  ) async {
    final repository = FakeProjectRepository();
    final project = (await repository.getProject('demo'))!;

    await _pumpWizard(tester, repository: repository, project: project);

    await tester.tap(find.byKey(const ValueKey('room-wizard-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('wizard-host')), findsOneWidget);
  });

  testWidgets('close button asks confirmation after data entry', (
    tester,
  ) async {
    final repository = FakeProjectRepository();
    final project = (await repository.getProject('demo'))!;

    await _pumpWizard(tester, repository: repository, project: project);
    await tester.enterText(
      find.byKey(const ValueKey('room-wizard-title-field')),
      'Тестовое помещение',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('room-wizard-close')));
    await tester.pumpAndSettle();

    expect(find.text('Отменить создание?'), findsOneWidget);
    expect(find.text('Закрыть'), findsOneWidget);
  });

  testWidgets('house scheme add flow opens wizard and saves room', (
    tester,
  ) async {
    final repository = FakeProjectRepository();
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          projectRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: HouseSchemeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await _scrollToPlan(tester);
    final addRoomButton = find.widgetWithText(
      FilledButton,
      'Добавить помещение',
    );
    await tester.ensureVisible(addRoomButton.first);
    await tester.tap(addRoomButton.first);
    await tester.pumpAndSettle();

    expect(find.text('Новое помещение'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('room-wizard-next-step1')),
      findsOneWidget,
    );

    await _completeStepOne(tester);
    await tester.tap(find.byKey(const ValueKey('room-wizard-next-step2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('room-wizard-next-step3')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('room-wizard-save')));
    await tester.tap(find.byKey(const ValueKey('room-wizard-save')));
    await tester.pumpAndSettle();

    final savedProject = (await repository.getProject('demo'))!;
    expect(savedProject.houseModel.rooms, hasLength(2));
  });
}

Future<void> _pumpWizard(
  WidgetTester tester, {
  required FakeProjectRepository repository,
  required Project project,
  Size surfaceSize = const Size(900, 1400),
}) async {
  await tester.binding.setSurfaceSize(surfaceSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
        projectRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(home: _WizardHost(project: project)),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _completeStepOne(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('room-wizard-next-step1')));
  await tester.pumpAndSettle();
}

Future<void> _scrollToPlan(WidgetTester tester) async {
  await tester.drag(find.byType(ListView).first, const Offset(0, -700));
  await tester.pumpAndSettle();
}

class _WizardHost extends StatefulWidget {
  const _WizardHost({required this.project});

  final Project project;

  @override
  State<_WizardHost> createState() => _WizardHostState();
}

class _WizardHostState extends State<_WizardHost> {
  bool _opened = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_opened) {
      return;
    }
    _opened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => RoomWizardScreen(
            project: widget.project,
            catalog: testCatalogSnapshot,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('host', key: ValueKey('wizard-host'))),
    );
  }
}
