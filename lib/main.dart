import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/permission_screen.dart';
import 'services/auto_clicker_service.dart';

void main() {
  runApp(const AutoFarmerApp());
}

class AutoFarmerApp extends StatelessWidget {
  const AutoFarmerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AutoFarmer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6200EE),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const _AppInitializer(),
    );
  }
}

class _AppInitializer extends StatefulWidget {
  const _AppInitializer();

  @override
  State<_AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<_AppInitializer>
    with WidgetsBindingObserver {
  bool _checking = true;
  bool _hasAllPermissions = false;
  final AutoClickerService _service = AutoClickerService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    final hasOverlay = await _service.checkOverlayPermission();
    final hasAccessibility = await _service.checkAccessibilityPermission();

    if (!mounted) return;
    setState(() {
      _hasAllPermissions = hasOverlay && hasAccessibility;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_hasAllPermissions) {
      return PermissionScreen(
        service: _service,
        onPermissionsGranted: () => setState(() => _hasAllPermissions = true),
      );
    }

    return HomeScreen(service: _service);
  }
}
