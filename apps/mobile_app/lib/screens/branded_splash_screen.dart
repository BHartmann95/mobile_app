import 'dart:async';
import 'package:flutter/material.dart';

class BrandedSplashScreen extends StatefulWidget {
  final Widget nextScreen;
  final String portraitImageAssetPath;
  final String landscapeImageAssetPath;
  final Duration duration;

  const BrandedSplashScreen({
    super.key,
    required this.nextScreen,
    required this.portraitImageAssetPath,
    required this.landscapeImageAssetPath,
    this.duration = const Duration(seconds: 2),
  });

  @override
  State<BrandedSplashScreen> createState() => _BrandedSplashScreenState();
}

class _BrandedSplashScreenState extends State<BrandedSplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(widget.duration, () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => widget.nextScreen),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final orientation = MediaQuery.of(context).orientation;
    final imagePath = orientation == Orientation.portrait
        ? widget.portraitImageAssetPath
        : widget.landscapeImageAssetPath;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox.expand(
        child: Image.asset(
          imagePath,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}