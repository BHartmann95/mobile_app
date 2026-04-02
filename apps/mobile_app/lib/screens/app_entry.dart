import 'package:flutter/material.dart';
import '../models/screen.dart';
import '../services/storage_service.dart';
import 'pairing_screen.dart';
import 'screen_list_screen.dart';

class AppEntry extends StatefulWidget {
  const AppEntry({super.key});

  @override
  State<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<AppEntry> {
  bool isLoading = true;
  List<ScreenDevice> screens = [];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final storage = StorageService();
    final loadedScreens = await storage.loadScreens();

    if (!mounted) return;

    setState(() {
      screens = loadedScreens;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (screens.isEmpty) {
      return PairingScreen(
        onPairedComplete: loadData,
      );
    }

    return const ScreenListScreen();
  }
}