import '../../../core/models/catalog.dart';

class HeatingDeviceFilter {
  const HeatingDeviceFilter({
    this.query = '',
    this.manufacturer,
    this.minHeightMm,
    this.maxHeightMm,
    this.minPowerWatts,
    this.maxPowerWatts,
    this.showCustomOnly = false,
    this.minSections,
    this.maxSections,
  });

  final String query;
  final String? manufacturer;
  final double? minHeightMm;
  final double? maxHeightMm;
  final double? minPowerWatts;
  final double? maxPowerWatts;
  final bool showCustomOnly;
  final int? minSections;
  final int? maxSections;

  bool get isActive =>
      query.trim().isNotEmpty ||
      manufacturer != null ||
      minHeightMm != null ||
      maxHeightMm != null ||
      minPowerWatts != null ||
      maxPowerWatts != null ||
      showCustomOnly ||
      minSections != null ||
      maxSections != null;
}

List<HeatingDeviceCatalogItem> applyHeatingDeviceFilter(
  Iterable<HeatingDeviceCatalogItem> items,
  HeatingDeviceFilter filter,
) {
  final query = filter.query.trim().toLowerCase();
  final result = items
      .where((item) {
        final entry = item.entry;
        if (filter.showCustomOnly && !item.isCustom) {
          return false;
        }
        if (filter.manufacturer != null &&
            entry.manufacturer != filter.manufacturer) {
          return false;
        }
        if (!_inDoubleRange(
          entry.heightMm,
          filter.minHeightMm,
          filter.maxHeightMm,
        )) {
          return false;
        }
        if (!_inDoubleRange(
          entry.ratedPowerWatts,
          filter.minPowerWatts,
          filter.maxPowerWatts,
        )) {
          return false;
        }
        if (!_inIntRange(
          entry.sectionCount,
          filter.minSections,
          filter.maxSections,
        )) {
          return false;
        }
        if (query.isNotEmpty && !_matchesQuery(entry, query)) {
          return false;
        }
        return true;
      })
      .toList(growable: false);

  result.sort(_compareHeatingDevices);
  return result;
}

bool _matchesQuery(HeatingDeviceCatalogEntry entry, String query) {
  return [
    entry.title,
    entry.manufacturer,
    entry.series,
    entry.model,
    entry.panelType,
    entry.sourceLabel,
  ].whereType<String>().any((value) => value.toLowerCase().contains(query));
}

bool _inDoubleRange(double? value, double? min, double? max) {
  if (min == null && max == null) {
    return true;
  }
  if (value == null) {
    return false;
  }
  if (min != null && value < min) {
    return false;
  }
  if (max != null && value > max) {
    return false;
  }
  return true;
}

bool _inIntRange(int? value, int? min, int? max) {
  if (min == null && max == null) {
    return true;
  }
  if (value == null) {
    return false;
  }
  if (min != null && value < min) {
    return false;
  }
  if (max != null && value > max) {
    return false;
  }
  return true;
}

int _compareHeatingDevices(
  HeatingDeviceCatalogItem a,
  HeatingDeviceCatalogItem b,
) {
  if (a.isCustom != b.isCustom) {
    return a.isCustom ? -1 : 1;
  }
  return _compareEntry(a.entry, b.entry);
}

int _compareEntry(HeatingDeviceCatalogEntry a, HeatingDeviceCatalogEntry b) {
  final manufacturerCompare = (a.manufacturer ?? '').compareTo(
    b.manufacturer ?? '',
  );
  if (manufacturerCompare != 0) {
    return manufacturerCompare;
  }
  final heightCompare = (a.heightMm ?? double.infinity).compareTo(
    b.heightMm ?? double.infinity,
  );
  if (heightCompare != 0) {
    return heightCompare;
  }
  final powerCompare = a.ratedPowerWatts.compareTo(b.ratedPowerWatts);
  if (powerCompare != 0) {
    return powerCompare;
  }
  return a.title.compareTo(b.title);
}
