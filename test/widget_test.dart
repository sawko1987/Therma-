import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartcalc_mobile/src/app/app.dart';
import 'package:smartcalc_mobile/src/core/models/catalog.dart';
import 'package:smartcalc_mobile/src/core/models/project.dart';
import 'package:smartcalc_mobile/src/core/providers.dart';
import 'package:smartcalc_mobile/src/core/services/interfaces.dart';
import 'package:smartcalc_mobile/src/core/services/preview_thermal_calculation_engine.dart';

void main() {
  testWidgets('dashboard renders core project text', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(_FakeCatalogRepository()),
          projectRepositoryProvider.overrideWithValue(_FakeProjectRepository()),
          constructionPerformanceEngineProvider.overrideWithValue(
            const PreviewConstructionPerformanceEngine(),
          ),
        ],
        child: const SmartCalcApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('SmartCalc Mobile'), findsOneWidget);
    expect(find.text('Локальные каталоги'), findsOneWidget);
  });
}

class _FakeCatalogRepository implements CatalogRepository {
  @override
  Future<CatalogSnapshot> loadSnapshot() async {
    return const CatalogSnapshot(
      climatePoints: [
        ClimatePoint(
          id: 'moscow',
          country: 'Россия',
          region: 'Московская область',
          city: 'Москва',
          designTemperature: -23,
          heatingPeriodDays: 202,
          gsop: 4383.4,
        ),
      ],
      materials: [
        MaterialEntry(
          id: 'aac_d500',
          name: 'Газобетон D500',
          category: 'Блоки',
          thermalConductivity: 0.14,
          vaporPermeability: 0.23,
        ),
      ],
      norms: [
        NormReference(
          id: 'sp_50',
          code: 'СП 50.13330.2012',
          clause: 'Тепловая защита зданий',
          title: 'Базовый набор требований',
        ),
      ],
      datasetVersion: 'test',
    );
  }
}

class _FakeProjectRepository implements ProjectRepository {
  @override
  Future<List<Project>> listProjects() async {
    return const [
      Project(
        id: 'demo',
        name: 'Demo project',
        climatePointId: 'moscow',
        constructions: [
          Construction(
            id: 'wall',
            title: 'Наружная стена',
            elementKind: ConstructionElementKind.wall,
            layers: [
              ConstructionLayer(
                id: 'aac',
                materialId: 'aac_d500',
                kind: LayerKind.solid,
                thicknessMm: 300,
              ),
            ],
          ),
        ],
        rooms: [
          Room(
            id: 'living',
            name: 'Гостиная',
            roomType: RoomType.livingRoom,
            floorAreaM2: 20,
            heightM: 2.8,
          ),
        ],
      ),
    ];
  }
}
