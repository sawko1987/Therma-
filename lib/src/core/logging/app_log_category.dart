enum AppLogCategory {
  ui('ui', 'UI'),
  navigation('navigation', 'Navigation'),
  provider('provider', 'Provider'),
  repository('repository', 'Repository'),
  calculation('calculation', 'Calculation'),
  storage('storage', 'Storage'),
  report('report', 'Report');

  const AppLogCategory(this.key, this.label);

  final String key;
  final String label;

  static AppLogCategory? fromKey(String? key) {
    if (key == null) {
      return null;
    }
    for (final value in values) {
      if (value.key == key) {
        return value;
      }
    }
    return null;
  }
}
