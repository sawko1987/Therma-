import 'package:flutter/material.dart';

import '../../construction_library/presentation/construction_directory_screen.dart';
import '../../construction_library/presentation/material_management_screen.dart';
import 'diagnostics_logs_screen.dart';
import 'heating_device_directory_screen.dart';
import 'opening_directory_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Справочники',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Здесь находятся вспомогательные справочники приложения: материалы, конструкции, окна и двери.',
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.library_books_outlined),
                    title: const Text('Справочник конструкций'),
                    subtitle: const Text('Создание, редактирование и просмотр'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ConstructionDirectoryScreen(),
                      ),
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.inventory_2_outlined),
                    title: const Text('Справочник материалов'),
                    subtitle: const Text('Каталог материалов и избранное'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const MaterialManagementScreen(),
                      ),
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.window_outlined),
                    title: const Text('Справочник проёмов'),
                    subtitle: const Text(
                      'Окна, двери и пользовательские шаблоны',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const OpeningTypeDirectoryScreen(),
                      ),
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.thermostat_outlined),
                    title: const Text('Справочник приборов отопления'),
                    subtitle: const Text(
                      'Радиаторы, типоразмеры и пользовательские приборы',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const HeatingDeviceDirectoryScreen(),
                      ),
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.health_and_safety_outlined),
                    title: const Text('Диагностика и логи'),
                    subtitle: const Text(
                      'Консоль, история логов и экспорт файла',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const DiagnosticsLogsScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
