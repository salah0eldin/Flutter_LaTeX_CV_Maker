// =====================================
// Imports and Dependencies
// =====================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/cv_data_provider.dart';
import 'widgets/main_screen.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter/foundation.dart';

// =====================================
// main() Entry Point
// =====================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Only initialize window_manager on desktop platforms
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
    await windowManager.ensureInitialized();
  }
  runApp(
    ChangeNotifierProvider(
      create: (context) => CVDataProvider(),
      child: const MyApp(),
    ),
  );
}

// =====================================
// MyApp Widget
// =====================================
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<CVDataProvider>().themeMode;
    return MaterialApp(
      title: 'CV Maker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      themeMode: themeMode,
      home: const MainScreen(),
    );
  }
}
