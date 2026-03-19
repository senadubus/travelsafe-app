import 'package:flutter/material.dart';
import 'features/heatmap/home_shell_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TravelSafeApp());
}

class TravelSafeApp extends StatelessWidget {
  const TravelSafeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TravelSafe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(),
      home: const HomeShellPage(),
    );
  }
}
