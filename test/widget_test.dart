import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartcalc_mobile/src/app/app.dart';
import 'package:smartcalc_mobile/src/core/models/project.dart';
import 'package:smartcalc_mobile/src/core/providers.dart';
import 'package:smartcalc_mobile/src/core/services/normative_thermal_calculation_engine.dart';
import 'package:smartcalc_mobile/src/features/construction_library/presentation/construction_directory_screen.dart';
import 'package:smartcalc_mobile/src/features/construction_library/presentation/construction_step_screen.dart';
import 'package:smartcalc_mobile/src/features/ground_floor/presentation/ground_floor_screen.dart';
import 'package:smartcalc_mobile/src/features/house_scheme/presentation/house_scheme_screen.dart';
import 'package:smartcalc_mobile/src/features/settings/presentation/settings_screen.dart';

import 'support/fakes.dart';

void main() {
  Future<void> pumpApp(
    WidgetTester tester, {
    FakeProjectRepository? repository,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          projectRepositoryProvider.overrideWithValue(
            repository ?? FakeProjectRepository(),
          ),
          thermalCalculationEngineProvider.overrideWithValue(
            const NormativeThermalCalculationEngine(),
          ),
        ],
        child: const SmartCalcApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> popRoute(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  testWidgets('app starts on project tab when no objects exist', (tester) async {
    await pumpApp(tester, repository: FakeProjectRepository(projects: []));

    expect(find.text('Проект'), findsWidgets);
    expect(find.text('Проектный хаб'), findsOneWidget);
    expect(find.text('Готовность проекта'), findsOneWidget);
  });

  testWidgets('app starts on home tab when object exists', (tester) async {
    await pumpApp(
      tester,
      repository: FakeProjectRepository(
        projects: [buildTestProject(showBuildingStepRoomsOnboarding: false)],
      ),
    );

    expect(find.text('SmartCalc Mobile'), findsOneWidget);
    expect(find.text('Быстрые переходы'), findsOneWidget);
    expect(find.text('Demo project'), findsOneWidget);
  });

  testWidgets('bottom navigation opens each root tab', (tester) async {
    await pumpApp(
      tester,
      repository: FakeProjectRepository(
        projects: [buildTestProject(showBuildingStepRoomsOnboarding: false)],
      ),
    );

    await tester.tap(find.text('Проект').last);
    await tester.pumpAndSettle();
    expect(find.text('Проектный хаб'), findsOneWidget);

    await tester.tap(find.text('План').last);
    await tester.pumpAndSettle();
    expect(find.text('Планировка дома'), findsOneWidget);

    await tester.tap(find.text('Расчёты').last);
    await tester.pumpAndSettle();
    expect(find.text('Thermocalc'), findsOneWidget);
    expect(find.text('Теплопотери здания'), findsOneWidget);

    await tester.tap(find.text('Настройки').last);
    await tester.pumpAndSettle();
    expect(find.text('Справочник материалов'), findsOneWidget);

    await tester.tap(find.text('Главная').last);
    await tester.pumpAndSettle();
    expect(find.text('Быстрые переходы'), findsOneWidget);
  });

  testWidgets('switching tabs preserves root screen state', (tester) async {
    await pumpApp(
      tester,
      repository: FakeProjectRepository(
        projects: [buildTestProject(showBuildingStepRoomsOnboarding: false)],
      ),
    );

    await tester.tap(find.text('Расчёты').last);
    await tester.pumpAndSettle();

    final calculationsList = find.byKey(
      const PageStorageKey<String>('calculations-hub-list'),
    );
    await tester.drag(calculationsList, const Offset(0, -300));
    await tester.pumpAndSettle();

    final scrollableFinder = find.descendant(
      of: calculationsList,
      matching: find.byType(Scrollable),
    );
    final before = tester.state<ScrollableState>(scrollableFinder).position.pixels;
    expect(before, greaterThan(0));

    await tester.tap(find.text('Главная').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Расчёты').last);
    await tester.pumpAndSettle();

    final after = tester.state<ScrollableState>(scrollableFinder).position.pixels;
    expect(after, before);
  });

  testWidgets('plan and calculations tabs show empty state without object', (
    tester,
  ) async {
    await pumpApp(tester, repository: FakeProjectRepository(projects: []));

    await tester.tap(find.text('План').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Сначала выберите активный объект'), findsOneWidget);
    expect(find.text('Перейти в Проект'), findsOneWidget);

    await tester.tap(find.text('Расчёты').last);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('после этого откроются модули расчёта'),
      findsOneWidget,
    );
    expect(find.text('Перейти в Проект'), findsOneWidget);
  });

  testWidgets('project tab opens existing steps 0-3', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpApp(
      tester,
      repository: FakeProjectRepository(
        projects: [buildTestProject(showBuildingStepRoomsOnboarding: false)],
      ),
    );

    await tester.tap(find.text('Проект').last);
    await tester.pumpAndSettle();

    final projectHubList = find.byKey(
      const PageStorageKey<String>('project-hub-list'),
    );
    final projectHubScrollable = find.descendant(
      of: projectHubList,
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('Шаг 0. Объект'),
      200,
      scrollable: projectHubScrollable,
    );
    await tester.tap(find.text('Шаг 0. Объект'));
    await tester.pumpAndSettle();
    expect(find.text('Сначала выберите объект'), findsOneWidget);
    await popRoute(tester);

    await tester.scrollUntilVisible(
      find.text('Шаг 1. Конструкции'),
      200,
      scrollable: projectHubScrollable,
    );
    await tester.tap(find.text('Шаг 1. Конструкции'));
    await tester.pumpAndSettle();
    expect(find.text('Конструкции проекта'), findsOneWidget);
    await popRoute(tester);

    await tester.scrollUntilVisible(
      find.text('Шаг 2. Помещения'),
      200,
      scrollable: projectHubScrollable,
    );
    await tester.tap(find.text('Шаг 2. Помещения'));
    await tester.pumpAndSettle();
    expect(find.text('Шаг 2. Помещения'), findsWidgets);
    await popRoute(tester);

    await tester.scrollUntilVisible(
      find.text('Шаг 3. Отопление и экономика'),
      200,
      scrollable: projectHubScrollable,
    );
    await tester.tap(find.text('Шаг 3. Отопление и экономика'));
    await tester.pumpAndSettle();
    expect(find.text('Шаг 3. Отопление и экономика'), findsWidgets);
  });

  testWidgets('calculations tab opens all four modules', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpApp(
      tester,
      repository: FakeProjectRepository(
        projects: [buildTestProject(showBuildingStepRoomsOnboarding: false)],
      ),
    );

    await tester.tap(find.text('Расчёты').last);
    await tester.pumpAndSettle();

    final calculationsList = find.byKey(
      const PageStorageKey<String>('calculations-hub-list'),
    );
    final calculationsScrollable = find.descendant(
      of: calculationsList,
      matching: find.byType(Scrollable),
    );
    await tester.tap(find.text('Thermocalc'));
    await tester.pumpAndSettle();
    expect(find.text('Проект и исходные условия'), findsOneWidget);
    await popRoute(tester);

    await tester.tap(find.text('Теплопотери здания'));
    await tester.pumpAndSettle();
    expect(find.text('Итого потерь'), findsOneWidget);
    await popRoute(tester);

    await tester.scrollUntilVisible(
      find.text('Полы по грунту'),
      200,
      scrollable: calculationsScrollable,
    );
    await tester.tap(find.text('Полы по грунту'));
    await tester.pumpAndSettle();
    expect(find.text('Полы по грунту'), findsOneWidget);
    await popRoute(tester);

    await tester.scrollUntilVisible(
      find.text('Отопление и экономика'),
      200,
      scrollable: calculationsScrollable,
    );
    await tester.tap(find.text('Отопление и экономика'));
    await tester.pumpAndSettle();
    expect(find.text('Шаг 3. Отопление и экономика'), findsOneWidget);
  });

  testWidgets('settings tab opens material management screen', (tester) async {
    await pumpApp(
      tester,
      repository: FakeProjectRepository(
        projects: [buildTestProject(showBuildingStepRoomsOnboarding: false)],
      ),
    );

    await tester.tap(find.text('Настройки').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Справочник материалов'));
    await tester.pumpAndSettle();

    expect(find.text('Каталог материалов'), findsOneWidget);
  });

  testWidgets('step 1 shows empty project state', (tester) async {
    final emptySelectionProject = buildTestProject().copyWith(
      selectedConstructionIds: const ['missing-construction'],
      projectConstructionSelections: const [
        ProjectConstructionSelection(constructionId: 'missing-construction'),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          projectRepositoryProvider.overrideWithValue(
            FakeProjectRepository(projects: [emptySelectionProject]),
          ),
          thermalCalculationEngineProvider.overrideWithValue(
            const NormativeThermalCalculationEngine(),
          ),
        ],
        child: const MaterialApp(home: ConstructionStepScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.textContaining('В проект пока не добавлена ни одна конструкция'),
      findsOneWidget,
    );
    expect(find.text('Добавить конструкцию'), findsOneWidget);
    expect(
      find.text('Чтобы перейти к шагу 2, добавьте в проект хотя бы одну конструкцию.'),
      findsOneWidget,
    );
    expect(
      tester.widget<FilledButton>(
        find.widgetWithText(
          FilledButton,
          'Перейти к созданию помещений (Шаг 2)',
        ),
      ).onPressed,
      isNull,
    );
  });

  testWidgets(
    'step 1 allows removing the last construction and keeps next step blocked',
    (tester) async {
      final repository = FakeProjectRepository(
        projects: [buildTestProject(showBuildingStepRoomsOnboarding: false)],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
            projectRepositoryProvider.overrideWithValue(repository),
            thermalCalculationEngineProvider.overrideWithValue(
              const NormativeThermalCalculationEngine(),
            ),
          ],
          child: const MaterialApp(home: ConstructionStepScreen()),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Убрать из проекта'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('В проект пока не добавлена ни одна конструкция'),
        findsOneWidget,
      );
      expect(
        tester.widget<FilledButton>(
          find.widgetWithText(
            FilledButton,
            'Перейти к созданию помещений (Шаг 2)',
          ),
        ).onPressed,
        isNull,
      );
      expect((await repository.getProject('demo'))!.constructions, isEmpty);
    },
  );

  testWidgets('step 1 opens construction picker modal', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          projectRepositoryProvider.overrideWithValue(FakeProjectRepository()),
          thermalCalculationEngineProvider.overrideWithValue(
            const NormativeThermalCalculationEngine(),
          ),
        ],
        child: const MaterialApp(home: ConstructionStepScreen()),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Добавить конструкцию'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Добавить конструкцию'), findsWidgets);
    expect(find.text('Создать конструкцию'), findsOneWidget);
    expect(find.text('Помощь'), findsOneWidget);
    expect(find.text('Шаблон стены'), findsOneWidget);
    expect(find.byTooltip('Копировать'), findsWidgets);
  });

  testWidgets('step 1 is not blocked while construction library loads', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          projectRepositoryProvider.overrideWithValue(
            _DelayedLibraryFakeProjectRepository(),
          ),
          thermalCalculationEngineProvider.overrideWithValue(
            const NormativeThermalCalculationEngine(),
          ),
        ],
        child: const MaterialApp(home: ConstructionStepScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Конструкции проекта'), findsOneWidget);
    expect(find.text('Следующий шаг'), findsOneWidget);
  });

  testWidgets(
    'creating construction from picker saves it to library and project',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final repository = FakeProjectRepository(
        projects: [
          buildTestProject(
            constructions: const [],
            houseModel: HouseModel.bootstrapFromConstructions(const []),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            catalogRepositoryProvider.overrideWithValue(
              FakeCatalogRepository(),
            ),
            projectRepositoryProvider.overrideWithValue(repository),
            thermalCalculationEngineProvider.overrideWithValue(
              const NormativeThermalCalculationEngine(),
            ),
          ],
          child: const MaterialApp(home: ConstructionStepScreen()),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Добавить конструкцию'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.text('Создать конструкцию'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      await tester.enterText(
        find.byType(TextField).last,
        'Моя тестовая конструкция',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.ensureVisible(find.text('Сохранить'));
      await tester.tap(find.text('Сохранить'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Моя тестовая конструкция'), findsOneWidget);
      expect(
        (await repository.listConstructions()).any(
          (item) => item.title == 'Моя тестовая конструкция',
        ),
        isTrue,
      );
      expect(
        (await repository.getProject('demo'))!.constructions.any(
          (item) => item.title == 'Моя тестовая конструкция',
        ),
        isTrue,
      );
    },
  );

  testWidgets('picker deletes custom construction after swipe confirmation', (
    tester,
  ) async {
    final customConstruction = buildWallConstruction().copyWith(
      id: 'custom-wall',
      title: 'Моя стена',
    );
    final repository = FakeProjectRepository(
      projects: [
        buildTestProject(
          constructions: const [],
          houseModel: HouseModel.bootstrapFromConstructions(const []),
        ),
        buildTestProject(
          climatePointId: 'novosibirsk',
          construction: customConstruction,
        ).copyWith(id: 'second-project', name: 'Второй проект'),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          projectRepositoryProvider.overrideWithValue(repository),
          thermalCalculationEngineProvider.overrideWithValue(
            const NormativeThermalCalculationEngine(),
          ),
        ],
        child: const MaterialApp(home: ConstructionStepScreen()),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Добавить конструкцию'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    await tester.drag(find.text('Моя стена').last, const Offset(-500, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Удалить конструкцию?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Удалить'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Моя стена'), findsNothing);
  });

  testWidgets('template construction in picker is not swipe deletable', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          projectRepositoryProvider.overrideWithValue(
            FakeProjectRepository(
              projects: [
                buildTestProject(
                  constructions: const [],
                  houseModel: HouseModel.bootstrapFromConstructions(const []),
                ),
              ],
            ),
          ),
          thermalCalculationEngineProvider.overrideWithValue(
            const NormativeThermalCalculationEngine(),
          ),
        ],
        child: const MaterialApp(home: ConstructionStepScreen()),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Добавить конструкцию'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    await tester.drag(find.text('Шаблон стены'), const Offset(-500, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Удалить конструкцию?'), findsNothing);
    expect(find.text('Шаблон'), findsOneWidget);
    expect(find.text('Шаблон стены'), findsOneWidget);
  });

  testWidgets(
    'picker keeps row and shows error when library deletion is forbidden',
    (tester) async {
      final customConstruction = buildWallConstruction().copyWith(
        id: 'custom-wall',
        title: 'Моя стена',
      );
      final guardedProject = buildTestProject(
        climatePointId: 'novosibirsk',
        construction: customConstruction,
        houseModel: HouseModel(
          id: 'house-guarded',
          title: 'Дом',
          rooms: [buildRoom()],
          elements: [
            buildEnvelopeElement(
              construction: customConstruction,
              sourceConstructionId: customConstruction.id,
              sourceConstructionTitle: customConstruction.title,
            ),
          ],
          openings: const [],
        ),
      ).copyWith(id: 'guarded-project', name: 'Проект с ограждением');
      final repository = FakeProjectRepository(
        projects: [
          buildTestProject(
            constructions: const [],
            houseModel: HouseModel.bootstrapFromConstructions(const []),
          ),
          guardedProject,
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            catalogRepositoryProvider.overrideWithValue(
              FakeCatalogRepository(),
            ),
            projectRepositoryProvider.overrideWithValue(repository),
            thermalCalculationEngineProvider.overrideWithValue(
              const NormativeThermalCalculationEngine(),
            ),
          ],
          child: const MaterialApp(home: ConstructionStepScreen()),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Добавить конструкцию'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      await tester.drag(find.text('Моя стена').last, const Offset(-500, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.widgetWithText(FilledButton, 'Удалить'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(
        find.textContaining('Нельзя удалить конструкцию из библиотеки'),
        findsOneWidget,
      );
      expect(
        (await repository.listConstructions()).any(
          (item) => item.id == customConstruction.id,
        ),
        isTrue,
      );
    },
  );

  testWidgets('picker tutorial auto shows once and can be reopened manually', (
    tester,
  ) async {
    final customConstruction = buildWallConstruction().copyWith(
      id: 'custom-wall',
      title: 'Моя стена',
    );
    final repository = FakeProjectRepository(
      projects: [
        buildTestProject(
          constructions: const [],
          houseModel: HouseModel.bootstrapFromConstructions(const []),
        ),
        buildTestProject(
          climatePointId: 'novosibirsk',
          construction: customConstruction,
        ).copyWith(id: 'second-project', name: 'Второй проект'),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          projectRepositoryProvider.overrideWithValue(repository),
          thermalCalculationEngineProvider.overrideWithValue(
            const NormativeThermalCalculationEngine(),
          ),
        ],
        child: const MaterialApp(home: ConstructionStepScreen()),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Добавить конструкцию'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    expect(
      find.text('Свайп влево удаляет вашу конструкцию из библиотеки'),
      findsOneWidget,
    );

    await tester.tapAt(const Offset(10, 10));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.text('Добавить конструкцию'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(
      find.text('Свайп влево удаляет вашу конструкцию из библиотеки'),
      findsNothing,
    );

    await tester.tap(find.text('Помощь'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(
      find.text('Свайп влево удаляет вашу конструкцию из библиотеки'),
      findsOneWidget,
    );
  });

  testWidgets(
    'construction directory does not offer delete for seeded templates',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            catalogRepositoryProvider.overrideWithValue(
              FakeCatalogRepository(),
            ),
            projectRepositoryProvider.overrideWithValue(
              FakeProjectRepository(),
            ),
            thermalCalculationEngineProvider.overrideWithValue(
              const NormativeThermalCalculationEngine(),
            ),
          ],
          child: const MaterialApp(home: ConstructionDirectoryScreen()),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();

      expect(find.text('Редактировать'), findsOneWidget);
      expect(find.text('Удалить'), findsNothing);
    },
  );

  testWidgets('construction directory screen renders directly', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          projectRepositoryProvider.overrideWithValue(FakeProjectRepository()),
          thermalCalculationEngineProvider.overrideWithValue(
            const NormativeThermalCalculationEngine(),
          ),
        ],
        child: const MaterialApp(home: ConstructionDirectoryScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Справочник конструкций'), findsWidgets);
    expect(find.text('Шаблон стены'), findsOneWidget);
  });

  testWidgets('settings screen renders directly', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));

    await tester.pumpAndSettle();

    expect(find.text('Настройки'), findsOneWidget);
    expect(find.text('Справочник конструкций'), findsOneWidget);
    expect(find.text('Справочник материалов'), findsOneWidget);
  });

  testWidgets('house scheme screen still renders directly', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          projectRepositoryProvider.overrideWithValue(FakeProjectRepository()),
        ],
        child: const MaterialApp(home: HouseSchemeScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Планировка дома'), findsOneWidget);
    expect(
      find.textContaining('После выбора ограждающих конструкций'),
      findsOneWidget,
    );
  });

  testWidgets('ground floor screen still renders directly', (tester) async {
    final floorConstruction = Construction(
      id: 'floor',
      title: 'Пол',
      elementKind: ConstructionElementKind.floor,
      floorConstructionType: FloorConstructionType.onGround,
      layers: buildWallConstruction().layers,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          projectRepositoryProvider.overrideWithValue(
            FakeProjectRepository(
              projects: [
                buildTestProject(constructions: [floorConstruction]),
              ],
            ),
          ),
          thermalCalculationEngineProvider.overrideWithValue(
            const NormativeThermalCalculationEngine(),
          ),
        ],
        child: const MaterialApp(home: GroundFloorScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Полы по грунту'), findsOneWidget);
  });
}

class _DelayedLibraryFakeProjectRepository extends FakeProjectRepository {
  _DelayedLibraryFakeProjectRepository()
    : super(
        projects: [buildTestProject(showBuildingStepRoomsOnboarding: false)],
      );

  @override
  Future<List<Construction>> listConstructions() async {
    await Future<void>.delayed(const Duration(seconds: 1));
    return super.listConstructions();
  }
}
