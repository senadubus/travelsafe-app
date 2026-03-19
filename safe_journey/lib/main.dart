import 'package:flutter/material.dart';
import 'package:safe_journey/features/map/presentations/crime_map_page.dart';
import 'features/map/presentations/map_screen.dart';

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
      home: const CrimeMapPage(),
    );
  }
}
