import 'package:flutter/material.dart';
import 'screens/app_entry.dart';
import 'screens/branded_splash_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: BrandedSplashScreen(
        portraitImageAssetPath: 'assets/images/splash/studio_splash_portrait.png',
        landscapeImageAssetPath: 'assets/images/splash/studio_splash_landscape.png',
        nextScreen: AppEntry(),
      ),
    );
  }
}