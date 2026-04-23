import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../features/calculations/presentation/calculations_hub_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/house_scheme/presentation/house_scheme_screen.dart';
import '../features/project_hub/presentation/project_hub_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import 'navigation/app_navigation.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _didResolveInitialTab = false;

  @override
  Widget build(BuildContext context) {
    final objectListAsync = ref.watch(objectListProvider);

    return objectListAsync.when(
      data: (objects) {
        if (!_didResolveInitialTab) {
          final initialTab = objects.isEmpty ? AppTab.project : AppTab.home;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) {
              return;
            }
            ref.read(currentAppTabProvider.notifier).select(initialTab);
            setState(() => _didResolveInitialTab = true);
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final currentTab = ref.watch(currentAppTabProvider);
        final screens = const [
          DashboardScreen(),
          ProjectHubScreen(),
          _PlanTabRoot(),
          CalculationsHubScreen(),
          SettingsScreen(),
        ];

        return Scaffold(
          body: IndexedStack(
            index: currentTab.index,
            children: screens,
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: currentTab.index,
            onDestinationSelected: (index) {
              ref
                  .read(currentAppTabProvider.notifier)
                  .select(AppTab.values[index]);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Главная',
              ),
              NavigationDestination(
                icon: Icon(Icons.folder_open_outlined),
                selectedIcon: Icon(Icons.folder_open),
                label: 'Проект',
              ),
              NavigationDestination(
                icon: Icon(Icons.home_work_outlined),
                selectedIcon: Icon(Icons.home_work),
                label: 'План',
              ),
              NavigationDestination(
                icon: Icon(Icons.calculate_outlined),
                selectedIcon: Icon(Icons.calculate),
                label: 'Расчёты',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: 'Настройки',
              ),
            ],
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Ошибка загрузки объектов: $error'),
          ),
        ),
      ),
    );
  }
}

class _PlanTabRoot extends ConsumerWidget {
  const _PlanTabRoot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final objectAsync = ref.watch(selectedObjectProvider);
    final projectAsync = ref.watch(selectedProjectProvider);

    return objectAsync.when(
      data: (object) => projectAsync.when(
        data: (project) {
          if (object == null || project == null) {
            return const _RootEmptyStateScreen(
              title: 'План',
              message:
                  'Сначала выберите активный объект во вкладке «Проект», затем откройте план дома.',
            );
          }
          return const HouseSchemeScreen();
        },
        loading: _buildLoadingState,
        error: (error, _) => _buildErrorState('Ошибка проекта: $error'),
      ),
      loading: _buildLoadingState,
      error: (error, _) => _buildErrorState('Ошибка объекта: $error'),
    );
  }
}

Widget _buildLoadingState() {
  return const Scaffold(
    body: Center(child: CircularProgressIndicator()),
  );
}

Widget _buildErrorState(String message) {
  return Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message),
      ),
    ),
  );
}

class _RootEmptyStateScreen extends ConsumerWidget {
  const _RootEmptyStateScreen({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.folder_open_outlined,
                  size: 56,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => switchToTab(ref, AppTab.project),
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Перейти в Проект'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
