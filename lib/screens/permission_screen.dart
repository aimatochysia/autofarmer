import 'package:flutter/material.dart';

import '../services/auto_clicker_service.dart';

class PermissionScreen extends StatefulWidget {
  final AutoClickerService service;
  final VoidCallback onPermissionsGranted;

  const PermissionScreen({
    super.key,
    required this.service,
    required this.onPermissionsGranted,
  });

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen>
    with WidgetsBindingObserver {
  bool _hasOverlay = false;
  bool _hasAccessibility = false;

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
    final overlay = await widget.service.checkOverlayPermission();
    final accessibility = await widget.service.checkAccessibilityPermission();

    if (!mounted) return;
    setState(() {
      _hasOverlay = overlay;
      _hasAccessibility = accessibility;
    });

    if (_hasOverlay && _hasAccessibility) {
      widget.onPermissionsGranted();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup Required'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AutoFarmer needs the following permissions to work:',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 32),
              _PermissionTile(
                title: 'Draw Over Other Apps',
                description:
                    'Allows AutoFarmer to display the click-point overlay on top of other applications so you can tap target positions.',
                granted: _hasOverlay,
                onRequest: () async {
                  await widget.service.requestOverlayPermission();
                },
              ),
              const SizedBox(height: 16),
              _PermissionTile(
                title: 'Accessibility Service',
                description:
                    'Allows AutoFarmer to perform automated taps on the screen on your behalf.',
                granted: _hasAccessibility,
                onRequest: () async {
                  await widget.service.requestAccessibilityPermission();
                },
              ),
              const Spacer(),
              if (_hasOverlay && _hasAccessibility)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: widget.onPermissionsGranted,
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Continue'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  final String title;
  final String description;
  final bool granted;
  final VoidCallback onRequest;

  const _PermissionTile({
    required this.title,
    required this.description,
    required this.granted,
    required this.onRequest,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              granted ? Icons.check_circle : Icons.cancel,
              color: granted ? Colors.green : theme.colorScheme.error,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                  if (!granted) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: onRequest,
                      child: const Text('Grant Permission'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
