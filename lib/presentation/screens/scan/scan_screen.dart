import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/providers.dart';
import '../../widgets/glassmorphic_card.dart';

/// Scan configuration and execution screen.
///
/// Provides service selection (S3/EC2), config file path input, and a
/// "Run Scan" button that invokes the Cloudrift CLI via [ScanNotifier].
/// Shows real-time elapsed time during scans, success/error banners on
/// completion, and a sortable history table of past scan results.
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  String _selectedService = 's3';
  late final TextEditingController _configPathController;
  Timer? _elapsedTimer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    final defaultPath = ref.read(cliDatasourceProvider).defaultConfigPath;
    _configPathController = TextEditingController(text: defaultPath);
  }

  @override
  void dispose() {
    _configPathController.dispose();
    _elapsedTimer?.cancel();
    super.dispose();
  }

  void _startScan() {
    _elapsed = Duration.zero;
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsed += const Duration(seconds: 1));
    });

    ref.read(scanStateProvider.notifier).runScan(
          configPath: _configPathController.text,
          service: _selectedService,
        );
  }

  @override
  Widget build(BuildContext context) {
    final scanState = ref.watch(scanStateProvider);
    final history = ref.watch(scanHistoryProvider);

    ref.listen<ScanState>(scanStateProvider, (prev, next) {
      if (next.status == ScanStatus.completed ||
          next.status == ScanStatus.error) {
        _elapsedTimer?.cancel();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Scan',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 24),

            // Scan Configuration Panel
            GlassmorphicCard(
              accentColor: AppColors.accentBlue,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Scan Configuration',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      // Service selector
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Service',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _ServiceChip(
                                  label: 'S3',
                                  icon: Icons.cloud_outlined,
                                  selected: _selectedService == 's3',
                                  onTap: () =>
                                      setState(() => _selectedService = 's3'),
                                ),
                                const SizedBox(width: 8),
                                _ServiceChip(
                                  label: 'EC2',
                                  icon: Icons.computer_outlined,
                                  selected: _selectedService == 'ec2',
                                  onTap: () =>
                                      setState(() => _selectedService = 'ec2'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Config path
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Config Path',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _configPathController,
                              style: const TextStyle(fontSize: 14),
                              decoration: const InputDecoration(
                                hintText: 'Path to cloudrift.yml',
                                prefixIcon:
                                    Icon(Icons.description_outlined, size: 18),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: scanState.status == ScanStatus.running
                            ? null
                            : _startScan,
                        icon: scanState.status == ScanStatus.running
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.radar, size: 18),
                        label: Text(scanState.status == ScanStatus.running
                            ? 'Scanning...'
                            : 'Run Scan'),
                      ),
                      if (scanState.status == ScanStatus.running) ...[
                        const SizedBox(width: 16),
                        Text(
                          _formatDuration(_elapsed),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textTertiary,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Scan result status
            if (scanState.status == ScanStatus.completed &&
                scanState.result != null) ...[
              const SizedBox(height: 16),
              GlassmorphicCard(
                accentColor: AppColors.low,
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: AppColors.low, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      'Scan completed: ${scanState.result!.driftCount} drifts found in ${scanState.result!.totalResources} resources',
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 14),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => context.go('/resources'),
                      child: const Text('View Results'),
                    ),
                  ],
                ),
              ),
            ],

            if (scanState.status == ScanStatus.error) ...[
              const SizedBox(height: 16),
              GlassmorphicCard(
                accentColor: AppColors.critical,
                child: Row(
                  children: [
                    const Icon(Icons.error,
                        color: AppColors.critical, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        scanState.error ?? 'Unknown error',
                        style: const TextStyle(
                            color: AppColors.textPrimary, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Scan History
            const Text(
              'Scan History',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            if (history.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(48),
                  child: Text(
                    'No scans yet',
                    style: TextStyle(color: AppColors.textTertiary),
                  ),
                ),
              )
            else
              GlassmorphicCard(
                padding: EdgeInsets.zero,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 700;
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: constraints.maxWidth,
                          ),
                          child: DataTable(
                            columnSpacing: isWide ? 24 : 16,
                            headingRowColor:
                                WidgetStateProperty.all(AppColors.surfaceElevated),
                            columns: [
                              const DataColumn(label: Text('Timestamp')),
                              const DataColumn(label: Text('Service')),
                              if (isWide)
                                const DataColumn(label: Text('Region')),
                              const DataColumn(label: Text('Resources'), numeric: true),
                              const DataColumn(label: Text('Drifts'), numeric: true),
                              const DataColumn(label: Text('Violations'), numeric: true),
                              if (isWide)
                                const DataColumn(label: Text('Duration')),
                              const DataColumn(label: Text('Status')),
                            ],
                            rows: history.take(20).map((entry) {
                              final ts = DateFormat('MMM d, HH:mm')
                                  .format(entry.timestamp);
                              return DataRow(
                                cells: [
                                  DataCell(Text(ts)),
                                  DataCell(_serviceLabel(entry.service)),
                                  if (isWide)
                                    DataCell(Text(entry.region)),
                                  DataCell(Text('${entry.totalResources}')),
                                  DataCell(Text(
                                    '${entry.driftCount}',
                                    style: TextStyle(
                                      color: entry.driftCount > 0
                                          ? AppColors.high
                                          : AppColors.textPrimary,
                                      fontWeight: entry.driftCount > 0
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  )),
                                  DataCell(Text(
                                    '${entry.policyViolations}',
                                    style: TextStyle(
                                      color: entry.policyViolations > 0
                                          ? AppColors.critical
                                          : AppColors.textPrimary,
                                      fontWeight: entry.policyViolations > 0
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  )),
                                  if (isWide)
                                    DataCell(Text(_formatMs(entry.scanDurationMs))),
                                  DataCell(_statusChip(entry.status)),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _serviceLabel(String service) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.accentBlue.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        service.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.accentBlue,
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    final color = status == 'completed' ? AppColors.low : AppColors.critical;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _formatMs(int ms) {
    final totalSeconds = ms / 1000;
    if (totalSeconds < 60) {
      return '${totalSeconds.toStringAsFixed(1)}s';
    }
    final mins = totalSeconds ~/ 60;
    final secs = (totalSeconds % 60).toStringAsFixed(1);
    return '${mins}m ${secs}s';
  }
}

class _ServiceChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ServiceChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accentBlue.withValues(alpha: 0.15)
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.accentBlue : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? AppColors.accentBlue : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color:
                    selected ? AppColors.accentBlue : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
