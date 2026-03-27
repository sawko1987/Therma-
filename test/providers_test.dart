import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartcalc_mobile/src/core/models/project.dart';
import 'package:smartcalc_mobile/src/core/providers.dart';

import 'support/fakes.dart';

void main() {
  test('selectedProjectProvider follows selectedProjectIdProvider', () async {
    final secondProject = Project(
      id: 'roof-project',
      name: 'Новосибирск / кровля',
      climatePointId: 'novosibirsk',
      roomPreset: RoomPreset.attic,
      constructions: [
        Construction(
          id: 'roof',
          title: 'Кровля',
          elementKind: ConstructionElementKind.roof,
          layers: buildWallConstruction().layers,
        ),
      ],
    );

    final container = ProviderContainer(
      overrides: [
        projectRepositoryProvider.overrideWithValue(
          FakeProjectRepository(projects: [buildTestProject(), secondProject]),
        ),
      ],
    );
    addTearDown(container.dispose);

    final initialProject = await container.read(selectedProjectProvider.future);
    expect(initialProject?.id, 'demo');

    container.read(selectedProjectIdProvider.notifier).select('roof-project');

    final selectedProject = await container.read(
      selectedProjectProvider.future,
    );
    expect(selectedProject?.id, 'roof-project');
    expect(selectedProject?.name, 'Новосибирск / кровля');
  });
}
