import 'package:flutter/material.dart';
import 'screens/library_screen.dart';
import 'utils/claude_api.dart';
import 'utils/audio_player_manager.dart';
import 'utils/navigation_service.dart';
import 'widgets/mini_player.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Claude API
  await ClaudeApi.initialize();

  // Initialize AudioPlayerManager singleton
  AudioPlayerManager();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: NavigationService.navigatorKey,
      title: 'Podcast App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          elevation: 2,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
      ),
      builder: (context, child) {
        return Scaffold(
          body: Column(
            children: [
              Expanded(child: child ?? Container()),
              const MiniPlayer(),
            ],
          ),
        );
      },
      home: const LibraryScreen(),
    );
  }
}
