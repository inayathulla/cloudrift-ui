import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/providers.dart';
import '../../widgets/glassmorphic_card.dart';

/// Application settings screen for CLI configuration, AWS credentials,
/// scan defaults, and data management.
///
/// Sections:
/// - **Cloudrift CLI**: Binary path and "Test Connection" to verify availability.
/// - **AWS Configuration**: Profile name and region inputs.
/// - **Scan Defaults**: Custom policy directory, fail-on-violation toggle,
///   skip-policies toggle.
/// - **Data**: Clear scan history with confirmation dialog.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _cliPathController = TextEditingController(text: 'cloudrift');
  final _awsProfileController = TextEditingController(text: 'default');
  final _regionController = TextEditingController(text: 'us-east-1');
  final _policyDirController = TextEditingController();
  bool _failOnViolation = false;
  bool _skipPolicies = false;
  String? _cliVersionInfo;
  bool _checkingCli = false;

  @override
  void dispose() {
    _cliPathController.dispose();
    _awsProfileController.dispose();
    _regionController.dispose();
    _policyDirController.dispose();
    super.dispose();
  }

  Future<void> _checkCliAvailability() async {
    setState(() => _checkingCli = true);
    final available =
        await ref.read(scanRepositoryProvider).isCliAvailable();
    final version =
        available ? await ref.read(scanRepositoryProvider).getCliVersion() : null;
    setState(() {
      _checkingCli = false;
      _cliVersionInfo = available
          ? 'Cloudrift CLI found${version != null ? ' ($version)' : ''}'
          : 'Cloudrift CLI not found on PATH';
    });
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Clear Scan History'),
        content: const Text('This will permanently delete all scan history.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.critical,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(scanRepositoryProvider).clearHistory();
      ref.invalidate(scanHistoryProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scan history cleared')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Settings',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 24),

            // Cloudrift CLI section
            GlassmorphicCard(
              accentColor: AppColors.accentBlue,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.terminal, size: 20, color: AppColors.accentBlue),
                      SizedBox(width: 8),
                      Text(
                        'Cloudrift CLI',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _cliPathController,
                    style: const TextStyle(fontSize: 14),
                    decoration: const InputDecoration(
                      labelText: 'CLI Binary Path',
                      hintText: 'cloudrift',
                      prefixIcon: Icon(Icons.folder_outlined, size: 18),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _checkingCli ? null : _checkCliAvailability,
                        icon: _checkingCli
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check, size: 16),
                        label: const Text('Test Connection'),
                      ),
                      if (_cliVersionInfo != null) ...[
                        const SizedBox(width: 16),
                        Icon(
                          _cliVersionInfo!.contains('not found')
                              ? Icons.error
                              : Icons.check_circle,
                          size: 16,
                          color: _cliVersionInfo!.contains('not found')
                              ? AppColors.critical
                              : AppColors.low,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _cliVersionInfo!,
                          style: TextStyle(
                            fontSize: 13,
                            color: _cliVersionInfo!.contains('not found')
                                ? AppColors.critical
                                : AppColors.low,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // AWS Configuration
            GlassmorphicCard(
              accentColor: AppColors.accentPurple,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.cloud_outlined,
                          size: 20, color: AppColors.accentPurple),
                      SizedBox(width: 8),
                      Text(
                        'AWS Configuration',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _awsProfileController,
                          style: const TextStyle(fontSize: 14),
                          decoration: const InputDecoration(
                            labelText: 'AWS Profile',
                            hintText: 'default',
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _regionController,
                          style: const TextStyle(fontSize: 14),
                          decoration: const InputDecoration(
                            labelText: 'Region',
                            hintText: 'us-east-1',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Scan Defaults
            GlassmorphicCard(
              accentColor: AppColors.accentTeal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.tune, size: 20, color: AppColors.accentTeal),
                      SizedBox(width: 8),
                      Text(
                        'Scan Defaults',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _policyDirController,
                    style: const TextStyle(fontSize: 14),
                    decoration: const InputDecoration(
                      labelText: 'Custom Policy Directory',
                      hintText: 'Optional: path to .rego files',
                      prefixIcon: Icon(Icons.folder_outlined, size: 18),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text(
                      'Fail on Violation',
                      style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
                    ),
                    subtitle: const Text(
                      'Exit with error code when violations found',
                      style:
                          TextStyle(fontSize: 12, color: AppColors.textTertiary),
                    ),
                    value: _failOnViolation,
                    onChanged: (v) => setState(() => _failOnViolation = v),
                    activeTrackColor: AppColors.accentBlue,
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    title: const Text(
                      'Skip Policies',
                      style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
                    ),
                    subtitle: const Text(
                      'Run drift detection only',
                      style:
                          TextStyle(fontSize: 12, color: AppColors.textTertiary),
                    ),
                    value: _skipPolicies,
                    onChanged: (v) => setState(() => _skipPolicies = v),
                    activeTrackColor: AppColors.accentBlue,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Data
            GlassmorphicCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.storage_outlined,
                          size: 20, color: AppColors.textSecondary),
                      SizedBox(width: 8),
                      Text(
                        'Data',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _clearHistory,
                        icon: const Icon(Icons.delete_outline,
                            size: 16, color: AppColors.critical),
                        label: const Text(
                          'Clear Scan History',
                          style: TextStyle(color: AppColors.critical),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.critical),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
