import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/datasources/config_datasource.dart';
import '../../../data/models/cloudrift_config.dart';
import '../../../data/models/file_list_result.dart';
import '../../../providers/providers.dart';
import '../../widgets/glassmorphic_card.dart';

/// Application settings screen for CLI configuration, AWS credentials,
/// scan defaults, and data management.
///
/// On web, also shows a config file editor backed by the Go API server.
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

  // Preserved from loaded config (managed by Builder, not editable here)
  String _currentPlanPath = '';

  // Web config editor state
  bool _configLoaded = false;
  bool _loadingConfig = false;
  bool _savingConfig = false;
  String? _configMessage;
  bool _configMessageIsError = false;
  String _selectedConfigPath = 'config/cloudrift-s3.yml';
  List<FileEntry> _availableConfigs = [];

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _loadFileList();
    } else {
      // On desktop, use the CLI's detected config path
      _selectedConfigPath =
          ref.read(cliDatasourceProvider).defaultConfigPath;
    }
    _loadConfigFromApi();
  }

  @override
  void dispose() {
    _cliPathController.dispose();
    _awsProfileController.dispose();
    _regionController.dispose();
    _policyDirController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // CLI check
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Clear history
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Web: config file operations
  // ---------------------------------------------------------------------------

  Future<void> _loadFileList() async {
    try {
      final result = await ref.read(configDatasourceProvider).listFiles();
      setState(() {
        _availableConfigs = result.configs;
      });
    } catch (_) {}
  }

  Future<void> _loadConfigFromApi() async {
    setState(() {
      _loadingConfig = true;
      _configMessage = null;
    });
    try {
      final config =
          await ref.read(configDatasourceProvider).loadConfig(_selectedConfigPath);
      setState(() {
        _awsProfileController.text = config.awsProfile;
        _regionController.text = config.region;
        _currentPlanPath = config.planPath;
        _policyDirController.text = config.policyDir ?? '';
        _failOnViolation = config.failOnViolation;
        _skipPolicies = config.skipPolicies;
        _loadingConfig = false;
        _configLoaded = true;
      });
    } on ConfigException catch (e) {
      setState(() {
        _loadingConfig = false;
        _configMessage = e.message;
        _configMessageIsError = true;
      });
    }
  }

  Future<void> _saveConfigToApi() async {
    setState(() {
      _savingConfig = true;
      _configMessage = null;
    });
    try {
      final config = CloudriftConfig(
        awsProfile: _awsProfileController.text,
        region: _regionController.text,
        planPath: _currentPlanPath,
        policyDir:
            _policyDirController.text.isEmpty ? null : _policyDirController.text,
        failOnViolation: _failOnViolation,
        skipPolicies: _skipPolicies,
      );
      await ref
          .read(configDatasourceProvider)
          .saveConfig(_selectedConfigPath, config);
      setState(() {
        _savingConfig = false;
        _configMessage = 'Saved successfully';
        _configMessageIsError = false;
      });
    } on ConfigException catch (e) {
      setState(() {
        _savingConfig = false;
        _configMessage = e.message;
        _configMessageIsError = true;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

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

            // Config File Editor (web) or AWS Configuration (desktop)
            if (kIsWeb) _buildConfigEditorCard() else _buildDesktopAwsCard(),
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
                  SwitchListTile(
                    title: const Text(
                      'Fail on Violation',
                      style:
                          TextStyle(fontSize: 14, color: AppColors.textPrimary),
                    ),
                    subtitle: const Text(
                      'Exit with error code when violations found',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textTertiary),
                    ),
                    value: _failOnViolation,
                    onChanged: (v) => setState(() => _failOnViolation = v),
                    activeTrackColor: AppColors.accentBlue,
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    title: const Text(
                      'Skip Policies',
                      style:
                          TextStyle(fontSize: 14, color: AppColors.textPrimary),
                    ),
                    subtitle: const Text(
                      'Run drift detection only',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textTertiary),
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

  // ---------------------------------------------------------------------------
  // Desktop AWS Configuration card
  // ---------------------------------------------------------------------------

  Widget _buildDesktopAwsCard() {
    return GlassmorphicCard(
      accentColor: AppColors.accentPurple,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.settings_outlined,
                  size: 20, color: AppColors.accentPurple),
              const SizedBox(width: 8),
              const Text(
                'Config File',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                _selectedConfigPath,
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loadingConfig)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else ...[
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
            const SizedBox(height: 12),
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
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: (_savingConfig || !_configLoaded)
                      ? null
                      : _saveConfigToApi,
                  icon: _savingConfig
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save, size: 16),
                  label: const Text('Save Config'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _loadingConfig ? null : _loadConfigFromApi,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Reload'),
                ),
                if (_configMessage != null) ...[
                  const SizedBox(width: 16),
                  Icon(
                    _configMessageIsError
                        ? Icons.error
                        : Icons.check_circle,
                    size: 16,
                    color: _configMessageIsError
                        ? AppColors.critical
                        : AppColors.low,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      _configMessage!,
                      style: TextStyle(
                        fontSize: 13,
                        color: _configMessageIsError
                            ? AppColors.critical
                            : AppColors.low,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Web Config File Editor card
  // ---------------------------------------------------------------------------

  Widget _buildConfigEditorCard() {
    return GlassmorphicCard(
      accentColor: AppColors.accentPurple,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.settings_outlined,
                  size: 20, color: AppColors.accentPurple),
              const SizedBox(width: 8),
              const Text(
                'Config File',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              if (_availableConfigs.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _availableConfigs
                              .any((f) => f.path == _selectedConfigPath)
                          ? _selectedConfigPath
                          : _availableConfigs.first.path,
                      dropdownColor: AppColors.cardBackground,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textPrimary),
                      items: _availableConfigs
                          .map((f) => DropdownMenuItem(
                                value: f.path,
                                child: Text(f.name),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _selectedConfigPath = v);
                          _loadConfigFromApi();
                        }
                      },
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loadingConfig)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else ...[
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
            const SizedBox(height: 12),
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
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: (_savingConfig || !_configLoaded) ? null : _saveConfigToApi,
                  icon: _savingConfig
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save, size: 16),
                  label: const Text('Save Config'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _loadingConfig ? null : _loadConfigFromApi,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Reload'),
                ),
                if (_configMessage != null) ...[
                  const SizedBox(width: 16),
                  Icon(
                    _configMessageIsError
                        ? Icons.error
                        : Icons.check_circle,
                    size: 16,
                    color: _configMessageIsError
                        ? AppColors.critical
                        : AppColors.low,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      _configMessage!,
                      style: TextStyle(
                        fontSize: 13,
                        color: _configMessageIsError
                            ? AppColors.critical
                            : AppColors.low,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
