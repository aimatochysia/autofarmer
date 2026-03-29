import 'dart:async';

import 'package:flutter/material.dart';

import '../models/click_point.dart';
import '../services/auto_clicker_service.dart';

class HomeScreen extends StatefulWidget {
  final AutoClickerService service;

  const HomeScreen({super.key, required this.service});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<ClickPoint> _clickPoints = [];
  int _delayMs = 250;
  int _randomVarianceMs = 50;
  bool _isRunning = false;
  bool _isPickingPoints = false;
  StreamSubscription<Map<dynamic, dynamic>>? _eventSubscription;

  static const int _minDelay = 250;
  static const int _maxDelay = 10000;

  @override
  void initState() {
    super.initState();
    _listenToEvents();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    if (_isPickingPoints) {
      widget.service.stopOverlay();
    }
    super.dispose();
  }

  void _listenToEvents() {
    _eventSubscription = widget.service.events.listen((event) {
      final type = event['type'] as String?;
      if (type == 'point_added') {
        final x = (event['x'] as num).toDouble();
        final y = (event['y'] as num).toDouble();
        if (mounted) {
          setState(() {
            _clickPoints.add(
              ClickPoint(x: x, y: y, index: _clickPoints.length),
            );
          });
        }
      } else if (type == 'points_cleared') {
        if (mounted) setState(() => _clickPoints.clear());
      } else if (type == 'overlay_done') {
        if (mounted) setState(() => _isPickingPoints = false);
      }
    });
  }

  Future<void> _togglePointPicking() async {
    if (_isPickingPoints) {
      await widget.service.stopOverlay();
      setState(() => _isPickingPoints = false);
    } else {
      await widget.service.startOverlay();
      setState(() => _isPickingPoints = true);
    }
  }

  Future<void> _clearPoints() async {
    if (_isPickingPoints) {
      // Restart overlay to clear drawn circles
      await widget.service.stopOverlay();
      await widget.service.startOverlay();
    }
    setState(() => _clickPoints.clear());
  }

  Future<void> _toggleAutoClicker() async {
    if (_isRunning) {
      await widget.service.stopAutoClicker();
      setState(() => _isRunning = false);
    } else {
      if (_clickPoints.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add at least one click point first')),
        );
        return;
      }

      // Stop overlay if still picking
      if (_isPickingPoints) {
        await widget.service.stopOverlay();
        setState(() => _isPickingPoints = false);
      }

      await widget.service.startAutoClicker(
        points: _clickPoints.map((p) => p.toMap()).toList(),
        delayMs: _delayMs,
        randomVarianceMs: _randomVarianceMs,
      );
      setState(() => _isRunning = true);
    }
  }

  String _formatDelay(int ms) {
    if (ms < 1000) return '${ms}ms';
    return '${(ms / 1000).toStringAsFixed(ms % 1000 == 0 ? 0 : 1)}s';
  }

  void _showInfoDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How to use AutoFarmer'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _InfoStep(
                number: '1',
                text: 'Tap "Add Points" to open the click overlay.',
              ),
              SizedBox(height: 8),
              _InfoStep(
                number: '2',
                text:
                    'Navigate to any app and tap where you want clicks to happen. Each tap adds a numbered target.',
              ),
              SizedBox(height: 8),
              _InfoStep(
                number: '3',
                text:
                    'Tap the "Done" button in the overlay to finish placing points and return here.',
              ),
              SizedBox(height: 8),
              _InfoStep(
                number: '4',
                text:
                    'Adjust "Delay between clicks" (250 ms – 10 s) and "Random Variance" (±ms added/subtracted to each click).',
              ),
              SizedBox(height: 8),
              _InfoStep(
                number: '5',
                text: 'Tap "Start Auto-Clicker" to begin automated clicking.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('AutoFarmer'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'How to use',
            onPressed: _showInfoDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Status banners
          if (_isRunning)
            _StatusBanner(
              color: Colors.green,
              icon: Icons.play_circle,
              text:
                  'Auto-clicker running · ${_formatDelay(_delayMs)} ± ${_randomVarianceMs}ms',
            ),
          if (_isPickingPoints)
            _StatusBanner(
              color: Colors.blue,
              icon: Icons.touch_app,
              text:
                  'Overlay active – tap anywhere to add click points, then tap "Done"',
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Click Points ──────────────────────────────────────
                _SectionHeader(
                  title: 'Click Points',
                  action: TextButton.icon(
                    onPressed: _isRunning ? null : _clearPoints,
                    icon: const Icon(Icons.clear_all, size: 18),
                    label: const Text('Clear All'),
                  ),
                ),
                const SizedBox(height: 8),
                if (_clickPoints.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.touch_app,
                            size: 48,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No click points added yet',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap "Add Points" below to place targets',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ..._clickPoints.asMap().entries.map((entry) {
                    final i = entry.key;
                    final point = entry.value;
                    return _ClickPointTile(
                      point: point,
                      onDelete: _isRunning
                          ? null
                          : () {
                              setState(() {
                                _clickPoints.removeAt(i);
                                for (var j = i; j < _clickPoints.length; j++) {
                                  _clickPoints[j] =
                                      _clickPoints[j].copyWith(index: j);
                                }
                              });
                            },
                    );
                  }),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _isRunning ? null : _togglePointPicking,
                  icon: Icon(
                    _isPickingPoints
                        ? Icons.stop_circle_outlined
                        : Icons.add_location_alt,
                  ),
                  label: Text(
                    _isPickingPoints ? 'Stop Adding Points' : 'Add Points',
                  ),
                ),

                const SizedBox(height: 28),

                // ── Click Speed ───────────────────────────────────────
                const _SectionHeader(title: 'Click Speed'),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Delay between clicks'),
                            _Badge(
                              label: _formatDelay(_delayMs),
                              color: theme.colorScheme.primaryContainer,
                              textColor:
                                  theme.colorScheme.onPrimaryContainer,
                            ),
                          ],
                        ),
                        Slider(
                          value: _delayMs.toDouble(),
                          min: _minDelay.toDouble(),
                          max: _maxDelay.toDouble(),
                          divisions: (_maxDelay - _minDelay) ~/ 50,
                          label: _formatDelay(_delayMs),
                          onChanged: _isRunning
                              ? null
                              : (v) {
                                  setState(() {
                                    _delayMs = v.round();
                                    if (_randomVarianceMs > _delayMs) {
                                      _randomVarianceMs = _delayMs;
                                    }
                                  });
                                },
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${_minDelay}ms (fastest)',
                              style: const TextStyle(fontSize: 11),
                            ),
                            Text(
                              '${_maxDelay ~/ 1000}s (slowest)',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Random Variance ───────────────────────────────────
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Random Variance'),
                                Text(
                                  'Randomly adds or subtracts ms per click',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color:
                                        theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            _Badge(
                              label: '±${_randomVarianceMs}ms',
                              color: theme.colorScheme.secondaryContainer,
                              textColor:
                                  theme.colorScheme.onSecondaryContainer,
                            ),
                          ],
                        ),
                        Slider(
                          value: _randomVarianceMs.toDouble(),
                          min: 1,
                          max: _delayMs.toDouble(),
                          divisions: 100,
                          label: '±${_randomVarianceMs}ms',
                          onChanged: _isRunning
                              ? null
                              : (v) => setState(
                                    () => _randomVarianceMs = v.round(),
                                  ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('1ms', style: TextStyle(fontSize: 11)),
                            Text(
                              '±${_formatDelay(_delayMs)}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Each click fires after '
                          '${_formatDelay(_delayMs)} ± up to ${_randomVarianceMs}ms',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),

          // ── Start / Stop button ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: _isRunning
                  ? FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      onPressed: _toggleAutoClicker,
                      icon: const Icon(Icons.stop_circle),
                      label: const Text(
                        'Stop Auto-Clicker',
                        style: TextStyle(fontSize: 18),
                      ),
                    )
                  : FilledButton.icon(
                      onPressed:
                          _clickPoints.isEmpty ? null : _toggleAutoClicker,
                      icon: const Icon(Icons.play_circle),
                      label: const Text(
                        'Start Auto-Clicker',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helper widgets ──────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String text;

  const _StatusBanner({
    required this.color,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: color.withOpacity(0.15),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? action;

  const _SectionHeader({required this.title, this.action});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        if (action != null) action!,
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;

  const _Badge({
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
      ),
    );
  }
}

class _ClickPointTile extends StatelessWidget {
  final ClickPoint point;
  final VoidCallback? onDelete;

  const _ClickPointTile({required this.point, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            '${point.index + 1}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text('Point ${point.index + 1}'),
        subtitle: Text(
          'x: ${point.x.toStringAsFixed(0)},  y: ${point.y.toStringAsFixed(0)}',
        ),
        trailing: onDelete != null
            ? IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Remove',
                onPressed: onDelete,
              )
            : null,
      ),
    );
  }
}

class _InfoStep extends StatelessWidget {
  final String number;
  final String text;

  const _InfoStep({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 12,
          child: Text(number, style: const TextStyle(fontSize: 12)),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }
}
