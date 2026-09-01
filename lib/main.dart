import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import 'screens/library_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  pdfrxFlutterInitialize();
  runApp(const LectorAcademicoApp());
}

class LectorAcademicoApp extends StatelessWidget {
  const LectorAcademicoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Lector Académico',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const LibraryScreen(),
    );
  }
}
