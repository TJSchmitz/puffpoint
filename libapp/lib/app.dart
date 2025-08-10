import 'package:flutter/material.dart';
import 'router.dart';

class PuffPointApp extends StatelessWidget {
  const PuffPointApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'puffpoint',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      routerConfig: appRouter,
    );
  }
}
