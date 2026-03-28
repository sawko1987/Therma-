import '../../../core/models/catalog.dart';

enum MaterialSourceFilter { all, seed, custom }

extension MaterialSourceFilterX on MaterialSourceFilter {
  String get label => switch (this) {
    MaterialSourceFilter.all => 'Все',
    MaterialSourceFilter.seed => 'Базовые',
    MaterialSourceFilter.custom => 'Свои',
  };
}

extension MaterialSortOptionX on MaterialSortOption {
  String get label => switch (this) {
    MaterialSortOption.name => 'По названию',
    MaterialSortOption.category => 'По категории',
    MaterialSortOption.lambdaAscending => 'λ по возрастанию',
    MaterialSortOption.lambdaDescending => 'λ по убыванию',
  };
}

class MaterialFilterState {
  const MaterialFilterState({
    this.query = '',
    this.category,
    this.source = MaterialSourceFilter.all,
    this.favoritesOnly = false,
    this.lambdaMin,
    this.lambdaMax,
    this.vaporMin,
    this.vaporMax,
    this.sort = MaterialSortOption.name,
  });

  final String query;
  final String? category;
  final MaterialSourceFilter source;
  final bool favoritesOnly;
  final double? lambdaMin;
  final double? lambdaMax;
  final double? vaporMin;
  final double? vaporMax;
  final MaterialSortOption sort;

  MaterialFilterState copyWith({
    String? query,
    String? category,
    bool clearCategory = false,
    MaterialSourceFilter? source,
    bool? favoritesOnly,
    double? lambdaMin,
    bool clearLambdaMin = false,
    double? lambdaMax,
    bool clearLambdaMax = false,
    double? vaporMin,
    bool clearVaporMin = false,
    double? vaporMax,
    bool clearVaporMax = false,
    MaterialSortOption? sort,
  }) {
    return MaterialFilterState(
      query: query ?? this.query,
      category: clearCategory ? null : category ?? this.category,
      source: source ?? this.source,
      favoritesOnly: favoritesOnly ?? this.favoritesOnly,
      lambdaMin: clearLambdaMin ? null : lambdaMin ?? this.lambdaMin,
      lambdaMax: clearLambdaMax ? null : lambdaMax ?? this.lambdaMax,
      vaporMin: clearVaporMin ? null : vaporMin ?? this.vaporMin,
      vaporMax: clearVaporMax ? null : vaporMax ?? this.vaporMax,
      sort: sort ?? this.sort,
    );
  }

  bool get hasActiveFilters =>
      query.trim().isNotEmpty ||
      category != null ||
      source != MaterialSourceFilter.all ||
      favoritesOnly ||
      lambdaMin != null ||
      lambdaMax != null ||
      vaporMin != null ||
      vaporMax != null ||
      sort != MaterialSortOption.name;
}

List<MaterialCatalogEntry> filterMaterialCatalogEntries(
  Iterable<MaterialCatalogEntry> entries,
  MaterialFilterState filter,
) {
  final normalizedQuery = filter.query.trim().toLowerCase();
  final filtered = entries
      .where((entry) {
        final material = entry.material;
        if (filter.category != null && material.category != filter.category) {
          return false;
        }
        if (filter.source == MaterialSourceFilter.seed &&
            entry.source != MaterialCatalogSource.seed) {
          return false;
        }
        if (filter.source == MaterialSourceFilter.custom &&
            entry.source != MaterialCatalogSource.custom) {
          return false;
        }
        if (filter.favoritesOnly && !entry.isFavorite) {
          return false;
        }
        if (filter.lambdaMin != null &&
            material.thermalConductivity < filter.lambdaMin!) {
          return false;
        }
        if (filter.lambdaMax != null &&
            material.thermalConductivity > filter.lambdaMax!) {
          return false;
        }
        if (filter.vaporMin != null &&
            material.vaporPermeability < filter.vaporMin!) {
          return false;
        }
        if (filter.vaporMax != null &&
            material.vaporPermeability > filter.vaporMax!) {
          return false;
        }
        if (normalizedQuery.isEmpty) {
          return true;
        }
        final haystack = [
          material.name,
          material.category,
          material.subcategory,
          material.manufacturer,
          material.notes,
          ...material.aliases,
          ...material.tags,
        ].whereType<String>().join(' ').toLowerCase();
        return haystack.contains(normalizedQuery);
      })
      .toList(growable: false);

  final sorted = [...filtered];
  sorted.sort((a, b) {
    switch (filter.sort) {
      case MaterialSortOption.name:
        return a.material.name.compareTo(b.material.name);
      case MaterialSortOption.category:
        final categoryCompare = a.material.category.compareTo(
          b.material.category,
        );
        return categoryCompare != 0
            ? categoryCompare
            : a.material.name.compareTo(b.material.name);
      case MaterialSortOption.lambdaAscending:
        final lambdaCompare = a.material.thermalConductivity.compareTo(
          b.material.thermalConductivity,
        );
        return lambdaCompare != 0
            ? lambdaCompare
            : a.material.name.compareTo(b.material.name);
      case MaterialSortOption.lambdaDescending:
        final lambdaCompare = b.material.thermalConductivity.compareTo(
          a.material.thermalConductivity,
        );
        return lambdaCompare != 0
            ? lambdaCompare
            : a.material.name.compareTo(b.material.name);
    }
  });
  return sorted;
}
