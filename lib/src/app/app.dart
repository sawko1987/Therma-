import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talker_flutter/talker_flutter.dart';

import '../core/providers.dart';
import 'app_shell.dart';
import 'theme.dart';

class SmartCalcApp extends ConsumerWidget {
  const SmartCalcApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'SmartCalc Mobile',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      navigatorObservers: [TalkerRouteObserver(ref.watch(talkerProvider))],
      home: const AppShell(),
    );
  }
}
