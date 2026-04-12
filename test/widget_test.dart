import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartcalc_mobile/src/app/app.dart';
import 'package:smartcalc_mobile/src/core/models/project.dart';
import 'package:smartcalc_mobile/src/core/providers.dart';
import 'package:smartcalc_mobile/src/core/services/normative_thermal_calculation_engine.dart';
import 'package:smartcalc_mobile/src/features/building_step/presentation/building_step_screen.dart';
import 'package:smartcalc_mobile/src/features/construction_library/presentation/construction_directory_screen.dart';
import 'package:smartcalc_mobile/src/features/construction_library/presentation/construction_step_screen.dart';
import 'package:smartcalc_mobile/src/features/ground_floor/presentation/ground_floor_screen.dart';
import 'package:smartcalc_mobile/src/features/house_scheme/presentation/house_scheme_screen.dart';
import 'package:smartcalc_mobile/src/features/settings/presentation/settings_screen.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('app starts from object step screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          projectRepositoryProvider.overrideWithValue(
            FakeProjectRepository(
              projects: [
                buildTestProject(showBuildingStepRoomsOnboarding: false),
              ],
            ),
          ),
          thermalCalculationEngineProvider.overrideWithValue(
            const NormativeThermalCalculationEngine(),
          ),
        ],
        child: const SmartCalcApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Шаг 0. Объект'), findsOneWidget);
    expect(find.text('Сначала выберите объект'), findsOneWidget);
    expect(find.text('Объекты'), findsWidgets);
    expect(find.text('Новый объект'), findsOneWidget);
  });

  testWidgets('selecting object from step 0 opens step 1', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          projectRepositoryProvider.overrideWithValue(
            FakeProjectRepository(
              projects: [
                buildTestProject(showBuildingStepRoomsOnboarding: false),
              ],
            ),
          ),
          thermalCalculationEngineProvider.overrideWithValue(
            const NormativeThermalCalculationEngine(),
          ),
        ],
        child: const SmartCalcApp(),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Demo project'));
    await tester.pumpAndSettle();

    expect(find.text('Шаг 1. Конструкции'), findsOneWidget);
    expect(find.text('Конструкции проекта'), findsOneWidget);
    expect(find.text('Перейти к созданию помещений (Шаг 2)'), findsOneWidget);
  });

  testWidgets('settings screen opens material management screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          projectRepositoryProvider.overrideWithValue(
            FakeProjectRepository(
              projects: [
                buildTestProject(showBuildingStepRoomsOnboarding: false),
              ],
            ),
          ),
          thermalCalculationEngineProvider.overrideWithValue(
            const NormativeThermalCalculationEngine(),
          ),
        ],
        child: const SmartCalcApp(),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Настройки'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Справочник материалов'));
    await tester.pumpAndSettle();

    expect(find.text('Каталог материалов'), findsOneWidget);
  });

  testWidgets('creating object from step 0 opens step 1', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          projectRepositoryProvider.overrideWithValue(
            FakeProjectRepository(
              projects: [
                buildTestProject(showBuildingStepRoomsOnboarding: false),
              ],
            ),
          ),
          thermalCalculationEngineProvider.overrideWithValue(
            const NormativeThermalCalculationEngine(),
          ),
        ],
        child: const SmartCalcApp(),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Новый объект'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Новый объект');
    await tester.enterText(find.byType(TextField).at(1), 'Москва, ул. Тест');
    await tester.enterText(find.byType(TextField).at(2), 'Описание');
    await tester.enterText(find.byType(TextField).at(3), '+79991234567');
    await tester.ensureVisible(find.text('Сохранить'));
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    expect(find.text('Шаг 1. Конструкции'), findsOneWidget);
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
  });

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
    await tester.pumpAndSettle();

    expect(find.text('Добавить конструкцию'), findsWidgets);
    expect(find.text('Шаблон стены'), findsOneWidget);
    expect(find.byTooltip('Копировать'), findsWidgets);
  });

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

  testWidgets('building step screen still renders directly', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          projectRepositoryProvider.overrideWithValue(FakeProjectRepository()),
          thermalCalculationEngineProvider.overrideWithValue(
            const NormativeThermalCalculationEngine(),
          ),
        ],
        child: const MaterialApp(home: BuildingStepScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Шаг 2. Помещения'), findsOneWidget);
    expect(find.text('Помещения дома'), findsOneWidget);
    expect(find.text('Расчётные температуры, °C'), findsOneWidget);
    expect(find.text('Вентиляция (Проветривание)'), findsOneWidget);
    expect(find.text('Конструктор дома'), findsNothing);
  });

  testWidgets('building step shows room-centric editor', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          projectRepositoryProvider.overrideWithValue(FakeProjectRepository()),
          thermalCalculationEngineProvider.overrideWithValue(
            const NormativeThermalCalculationEngine(),
          ),
        ],
        child: const MaterialApp(home: BuildingStepScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.text('Воздух в помещении в режиме “Комфорт”'),
      findsOneWidget,
    );
    expect(find.text('Приток, м³/ч'), findsOneWidget);
    expect(find.text('Эконом'), findsNothing);
    expect(find.text('Защита от замерзания'), findsNothing);
  });

  testWidgets('building step room sidebar selects room', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = FakeProjectRepository(
      projects: [
        buildTestProject(
          showBuildingStepRoomsOnboarding: false,
          houseModel: HouseModel(
            id: 'house-model',
            title: 'Конструктор дома',
            rooms: [
              buildRoom(
                id: 'room-main',
                title: 'Гостиная',
                layout: buildRoomLayout(widthMeters: 4, heightMeters: 4),
              ),
              buildRoom(
                id: 'room-bedroom',
                title: 'Спальня',
                kind: RoomKind.bedroom,
                layout: buildRoomLayout(
                  xMeters: 5,
                  yMeters: 0,
                  widthMeters: 3,
                  heightMeters: 4,
                ),
              ),
            ],
            elements: [
              HouseEnvelopeElement.fromConstruction(
                buildWallConstruction(),
                roomId: 'room-main',
                room: buildRoom(
                  id: 'room-main',
                  title: 'Гостиная',
                  layout: buildRoomLayout(widthMeters: 4, heightMeters: 4),
                ),
              ),
            ],
            openings: const [],
          ),
        ),
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
        child: const MaterialApp(home: BuildingStepScreen()),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('room-sidebar-toggle')));
    await tester.pumpAndSettle();

    expect(find.text('Гостиная'), findsWidgets);

    await tester.tap(
      find.byKey(const ValueKey('room-sidebar-room-room-bedroom')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('room-sidebar-toggle')));
    await tester.pumpAndSettle();

    expect(find.text('Гостиная'), findsWidgets);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('room-editor-room-bedroom')),
        matching: find.text('Спальня'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('building step inline room settings persist', (
    tester,
  ) async {
    final repository = FakeProjectRepository(projects: [buildTestProject()]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
          projectRepositoryProvider.overrideWithValue(repository),
          thermalCalculationEngineProvider.overrideWithValue(
            const NormativeThermalCalculationEngine(),
          ),
        ],
        child: const MaterialApp(home: BuildingStepScreen()),
      ),
    );

    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(
        const ValueKey('ventilation-room-main-0.0'),
      ),
      '55',
    );
    await tester.pumpAndSettle();

    final savedProject = (await repository.getProject('demo'))!;
    expect(savedProject.houseModel.rooms.single.ventilationSupplyM3h, 55);
  });

  testWidgets(
    'building step sidebar shows house construction overview',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            catalogRepositoryProvider.overrideWithValue(
              FakeCatalogRepository(),
            ),
            projectRepositoryProvider.overrideWithValue(
              FakeProjectRepository(
                projects: [
                  buildTestProject(showBuildingStepRoomsOnboarding: false),
                ],
              ),
            ),
            thermalCalculationEngineProvider.overrideWithValue(
              const NormativeThermalCalculationEngine(),
            ),
          ],
          child: const MaterialApp(home: BuildingStepScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsNothing);

      await tester.tap(find.byKey(const ValueKey('room-sidebar-toggle')));
      await tester.pumpAndSettle();

      expect(find.text('Конструкции дома'), findsOneWidget);
      expect(find.textContaining('Наружная стена'), findsWidgets);
    },
  );

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
