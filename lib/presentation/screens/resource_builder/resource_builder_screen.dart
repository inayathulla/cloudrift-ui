import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/datasources/config_datasource.dart';
import '../../../data/models/plan_builder.dart';
import '../../../data/models/terraform_job.dart';
import '../../../data/models/terraform_status.dart';
import '../../../providers/providers.dart';
import '../../widgets/glassmorphic_card.dart';

/// Visual resource builder that generates plan.json from form data,
/// eliminating the need for Terraform to run scans.
class ResourceBuilderScreen extends ConsumerStatefulWidget {
  const ResourceBuilderScreen({super.key});

  @override
  ConsumerState<ResourceBuilderScreen> createState() =>
      _ResourceBuilderScreenState();
}

class _ResourceBuilderScreenState
    extends ConsumerState<ResourceBuilderScreen> {
  // Mode: 'terraform' or 'manual'
  String _mode = 'manual';

  // Manual mode state
  String _selectedService = 's3';
  List<S3ResourceDef> _s3Resources = [];
  List<EC2ResourceDef> _ec2Resources = [];
  bool _saving = false;
  bool _loading = false;
  String? _message;
  bool _messageIsError = false;

  // Terraform mode state
  bool _tfChecking = true;
  TerraformStatus? _tfStatus;
  bool _tfUploading = false;
  TerraformJobResult? _tfJobResult;
  Timer? _tfPollTimer;
  bool _tfShowOutput = false;

  // Upload mode state
  bool _uploadingPlan = false;
  String? _uploadedPlanPath;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _loadExistingPlan();
      _checkTerraformStatus();
    }
  }

  @override
  void dispose() {
    _tfPollTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkTerraformStatus() async {
    try {
      final ds = ref.read(configDatasourceProvider);
      final status = await ds.getTerraformStatus();
      setState(() {
        _tfStatus = status;
        _tfChecking = false;
        // Default to terraform tab if terraform is available and has files
        if (status.available && status.hasFiles) {
          _mode = 'terraform';
        }
      });
    } catch (_) {
      setState(() => _tfChecking = false);
    }
  }

  Future<void> _loadExistingPlan() async {
    setState(() => _loading = true);
    try {
      final ds = ref.read(configDatasourceProvider);
      final json = await ds.loadPlanJson('examples/generated-plan.json');
      final plan = jsonDecode(json) as Map<String, dynamic>;
      final s3 = PlanBuilder.parseS3Plan(plan);
      final ec2 = PlanBuilder.parseEC2Plan(plan);
      setState(() {
        if (s3.isNotEmpty) {
          _s3Resources = s3;
          _selectedService = 's3';
        }
        if (ec2.isNotEmpty) {
          _ec2Resources = ec2;
          if (s3.isEmpty) _selectedService = 'ec2';
        }
      });
    } catch (_) {
      // No existing plan — start fresh
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _generateAndSave() async {
    final resources = _selectedService == 's3' ? _s3Resources : _ec2Resources;
    if (resources.isEmpty) {
      setState(() {
        _message = 'Add at least one resource before generating.';
        _messageIsError = true;
      });
      return;
    }

    // Validate required fields
    if (_selectedService == 's3') {
      final emptyBucket = _s3Resources.any((r) => r.bucket.trim().isEmpty);
      if (emptyBucket) {
        setState(() {
          _message = 'All S3 buckets must have a name.';
          _messageIsError = true;
        });
        return;
      }
    } else {
      final emptyAmi = _ec2Resources.any((r) => r.ami.trim().isEmpty);
      if (emptyAmi) {
        setState(() {
          _message = 'All EC2 instances must have an AMI ID.';
          _messageIsError = true;
        });
        return;
      }
    }

    setState(() {
      _saving = true;
      _message = null;
    });

    try {
      final planJson = _selectedService == 's3'
          ? PlanBuilder.generateS3Plan(_s3Resources)
          : PlanBuilder.generateEC2Plan(_ec2Resources);

      if (kIsWeb) {
        final ds = ref.read(configDatasourceProvider);
        final result = await ds.generatePlan(_selectedService, planJson);
        setState(() {
          _message =
              'Plan saved to ${result['plan_path']} — config updated: ${result['config']}';
          _messageIsError = false;
        });
      } else {
        // Desktop: just show the JSON
        _showJsonPreview(planJson);
      }
    } on ConfigException catch (e) {
      setState(() {
        _message = e.message;
        _messageIsError = true;
      });
    } catch (e) {
      setState(() {
        _message = 'Failed: $e';
        _messageIsError = true;
      });
    } finally {
      setState(() => _saving = false);
    }
  }

  void _showJsonPreview(Map<String, dynamic> planJson) {
    final pretty =
        const JsonEncoder.withIndent('  ').convert(planJson);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Generated Plan JSON',
            style: TextStyle(color: AppColors.textPrimary)),
        content: SizedBox(
          width: 600,
          height: 400,
          child: SingleChildScrollView(
            child: SelectableText(
              pretty,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Terraform methods
  // ---------------------------------------------------------------------------

  Future<void> _uploadTfFiles() async {
    setState(() => _tfUploading = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['tf', 'tfvars'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _tfUploading = false);
        return;
      }

      final files = <String, List<int>>{};
      for (final f in result.files) {
        if (f.bytes != null && f.name.isNotEmpty) {
          files[f.name] = f.bytes!;
        }
      }

      final ds = ref.read(configDatasourceProvider);
      await ds.uploadTerraformFiles(files);
      await _checkTerraformStatus();
      setState(() {
        _message = 'Uploaded ${files.length} file(s)';
        _messageIsError = false;
      });
    } on ConfigException catch (e) {
      setState(() {
        _message = e.message;
        _messageIsError = true;
      });
    } catch (e) {
      setState(() {
        _message = 'Upload failed: $e';
        _messageIsError = true;
      });
    } finally {
      setState(() => _tfUploading = false);
    }
  }

  Future<void> _startTerraformPlan() async {
    setState(() {
      _tfJobResult = null;
      _message = null;
    });

    try {
      final ds = ref.read(configDatasourceProvider);
      final jobId = await ds.startTerraformPlan();
      _startPolling(jobId);
    } on ConfigException catch (e) {
      setState(() {
        _message = e.message;
        _messageIsError = true;
      });
    }
  }

  void _startPolling(String jobId) {
    _tfPollTimer?.cancel();
    _tfPollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        final ds = ref.read(configDatasourceProvider);
        final result = await ds.getTerraformJobStatus(jobId);
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() => _tfJobResult = result);

        if (!result.isRunning) {
          timer.cancel();
          if (result.isCompleted) {
            setState(() {
              _message =
                  'Plan generated: ${result.planPath} — config updated';
              _messageIsError = false;
            });
            _checkTerraformStatus();
          } else if (result.isError) {
            setState(() {
              _message = result.error;
              _messageIsError = true;
            });
          }
        }
      } catch (_) {
        // Silently retry on network errors during polling
      }
    });
  }

  void _showPlanPreviewFromApi() async {
    try {
      final ds = ref.read(configDatasourceProvider);
      final jsonStr =
          await ds.loadPlanJson('examples/terraform-plan.json');
      final plan = jsonDecode(jsonStr) as Map<String, dynamic>;
      _showJsonPreview(plan);
    } on ConfigException catch (e) {
      setState(() {
        _message = e.message;
        _messageIsError = true;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Upload mode methods
  // ---------------------------------------------------------------------------

  Future<void> _uploadPlanJson() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    setState(() {
      _uploadingPlan = true;
      _message = null;
    });
    try {
      final ds = ref.read(configDatasourceProvider);
      final savedPath = await ds.uploadPlanFile(file.name, file.bytes!);
      setState(() {
        _uploadingPlan = false;
        _uploadedPlanPath = savedPath;
        _message = 'Plan uploaded: $savedPath — config updated';
        _messageIsError = false;
      });
    } on ConfigException catch (e) {
      setState(() {
        _uploadingPlan = false;
        _message = e.message;
        _messageIsError = true;
      });
    }
  }

  void _showUploadedPlanPreview() async {
    if (_uploadedPlanPath == null) return;
    try {
      final ds = ref.read(configDatasourceProvider);
      final jsonStr = await ds.loadPlanJson(_uploadedPlanPath!);
      final plan = jsonDecode(jsonStr) as Map<String, dynamic>;
      _showJsonPreview(plan);
    } on ConfigException catch (e) {
      setState(() {
        _message = e.message;
        _messageIsError = true;
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Resource Builder',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Generate plan.json from Terraform files or manual resource forms',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Mode selector: Terraform | Manual
                  if (kIsWeb) ...[
                    _buildModeSelector(),
                    const SizedBox(height: 20),
                  ],

                  // Terraform mode
                  if (_mode == 'terraform' && kIsWeb) _buildTerraformSection(),

                  // Upload mode
                  if (_mode == 'upload' && kIsWeb) _buildUploadSection(),

                  // Manual mode
                  if (_mode == 'manual') ...[
                    _buildServiceTabs(),
                    const SizedBox(height: 20),
                    if (_selectedService == 's3') _buildS3Section(),
                    if (_selectedService == 'ec2') _buildEC2Section(),
                    const SizedBox(height: 24),
                    _buildActionBar(),
                  ],

                  // Status message (shared)
                  if (_message != null) ...[
                    const SizedBox(height: 16),
                    GlassmorphicCard(
                      accentColor: _messageIsError
                          ? AppColors.critical
                          : AppColors.low,
                      child: Row(
                        children: [
                          Icon(
                            _messageIsError
                                ? Icons.error
                                : Icons.check_circle,
                            color: _messageIsError
                                ? AppColors.critical
                                : AppColors.low,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _message!,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildModeSelector() {
    return Row(
      children: [
        _ServiceChip(
          label: 'Terraform',
          icon: Icons.code_outlined,
          selected: _mode == 'terraform',
          onTap: () => setState(() => _mode = 'terraform'),
        ),
        const SizedBox(width: 8),
        _ServiceChip(
          label: 'Manual',
          icon: Icons.edit_note_outlined,
          selected: _mode == 'manual',
          onTap: () => setState(() => _mode = 'manual'),
        ),
        const SizedBox(width: 8),
        _ServiceChip(
          label: 'Upload',
          icon: Icons.upload_file_outlined,
          selected: _mode == 'upload',
          onTap: () => setState(() => _mode = 'upload'),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Upload section
  // ---------------------------------------------------------------------------

  Widget _buildUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlassmorphicCard(
          accentColor: AppColors.accentBlue,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.upload_file,
                      color: AppColors.accentBlue, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Upload Existing Plan',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Upload a plan.json file generated externally (e.g. from terraform show -json). '
                'The file will be saved and the config updated automatically.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _uploadingPlan ? null : _uploadPlanJson,
                    icon: _uploadingPlan
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.file_open, size: 18),
                    label: Text(
                        _uploadingPlan ? 'Uploading...' : 'Select plan.json'),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Result card after successful upload
        if (_uploadedPlanPath != null) ...[
          const SizedBox(height: 16),
          GlassmorphicCard(
            accentColor: AppColors.low,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: AppColors.low, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Plan uploaded: $_uploadedPlanPath',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _showUploadedPlanPreview,
                      icon: const Icon(Icons.code, size: 18),
                      label: const Text('Preview JSON'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => context.go('/scan'),
                      icon: const Icon(Icons.radar, size: 18),
                      label: const Text('Run Scan'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Terraform section
  // ---------------------------------------------------------------------------

  Widget _buildTerraformSection() {
    if (_tfChecking) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final status = _tfStatus;
    if (status == null || !status.available) {
      return GlassmorphicCard(
        accentColor: AppColors.high,
        child: Row(
          children: [
            const Icon(Icons.warning_amber, color: AppColors.high, size: 20),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Terraform is not installed in this environment. Use the Manual tab to define resources.',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status card
        GlassmorphicCard(
          accentColor: AppColors.accentTeal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: AppColors.accentTeal, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Terraform v${status.version}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (status.initialized) ...[
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.low.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('Initialized',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.low)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              if (status.tfFiles.isEmpty)
                const Text(
                  'No .tf files found. Upload Terraform files or mount a volume.',
                  style:
                      TextStyle(fontSize: 13, color: AppColors.textSecondary),
                )
              else ...[
                const Text('.tf files:',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: status.tfFiles.map((f) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(f,
                          style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              color: AppColors.textPrimary)),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Upload + Generate buttons
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _tfUploading ? null : _uploadTfFiles,
              icon: _tfUploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file, size: 18),
              label: Text(_tfUploading ? 'Uploading...' : 'Upload .tf Files'),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: (!status.hasFiles ||
                      (_tfJobResult != null && _tfJobResult!.isRunning))
                  ? null
                  : _startTerraformPlan,
              icon: (_tfJobResult != null && _tfJobResult!.isRunning)
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.play_arrow, size: 18),
              label: const Text('Generate Plan from Terraform'),
            ),
          ],
        ),

        // Progress card
        if (_tfJobResult != null && _tfJobResult!.isRunning) ...[
          const SizedBox(height: 16),
          GlassmorphicCard(
            accentColor: AppColors.accentPurple,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.accentPurple),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _tfJobResult!.phase,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_tfJobResult!.elapsedSeconds}s',
                      style: const TextStyle(
                        fontSize: 13,
                        fontFamily: 'monospace',
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
                if (_tfShowOutput && _tfJobResult!.output.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    height: 200,
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        _tfJobResult!.output,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () =>
                      setState(() => _tfShowOutput = !_tfShowOutput),
                  child: Text(
                    _tfShowOutput ? 'Hide output' : 'Show output',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.accentBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Completed result card
        if (_tfJobResult != null && _tfJobResult!.isCompleted) ...[
          const SizedBox(height: 16),
          GlassmorphicCard(
            accentColor: AppColors.low,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: AppColors.low, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Plan generated: ${_tfJobResult!.planPath}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _showPlanPreviewFromApi,
                      icon: const Icon(Icons.code, size: 18),
                      label: const Text('Preview JSON'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => context.go('/scan'),
                      icon: const Icon(Icons.radar, size: 18),
                      label: const Text('Run Scan'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],

        // Error result card with output
        if (_tfJobResult != null && _tfJobResult!.isError) ...[
          const SizedBox(height: 16),
          GlassmorphicCard(
            accentColor: AppColors.critical,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.error,
                        color: AppColors.critical, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _tfJobResult!.error,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_tfJobResult!.output.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () =>
                        setState(() => _tfShowOutput = !_tfShowOutput),
                    child: Text(
                      _tfShowOutput ? 'Hide output' : 'Show full output',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.accentBlue,
                      ),
                    ),
                  ),
                  if (_tfShowOutput) ...[
                    const SizedBox(height: 8),
                    Container(
                      height: 200,
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          _tfJobResult!.output,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildServiceTabs() {
    return Row(
      children: [
        _ServiceChip(
          label: 'S3',
          icon: Icons.cloud_outlined,
          selected: _selectedService == 's3',
          onTap: () => setState(() => _selectedService = 's3'),
        ),
        const SizedBox(width: 8),
        _ServiceChip(
          label: 'EC2',
          icon: Icons.computer_outlined,
          selected: _selectedService == 'ec2',
          onTap: () => setState(() => _selectedService = 'ec2'),
        ),
      ],
    );
  }

  Widget _buildActionBar() {
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: _saving ? null : _generateAndSave,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.save, size: 18),
          label:
              Text(_saving ? 'Saving...' : 'Generate & Save Plan'),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: () {
            final planJson = _selectedService == 's3'
                ? PlanBuilder.generateS3Plan(_s3Resources)
                : PlanBuilder.generateEC2Plan(_ec2Resources);
            _showJsonPreview(planJson);
          },
          icon: const Icon(Icons.code, size: 18),
          label: const Text('Preview JSON'),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // S3 Section
  // ---------------------------------------------------------------------------

  Widget _buildS3Section() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._s3Resources.asMap().entries.map(
              (entry) => _S3ResourceCard(
                key: ValueKey('s3-${entry.key}'),
                index: entry.key,
                resource: entry.value,
                onChanged: (r) =>
                    setState(() => _s3Resources[entry.key] = r),
                onDelete: () =>
                    setState(() => _s3Resources.removeAt(entry.key)),
              ),
            ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () =>
              setState(() => _s3Resources.add(S3ResourceDef())),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add S3 Bucket'),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // EC2 Section
  // ---------------------------------------------------------------------------

  Widget _buildEC2Section() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._ec2Resources.asMap().entries.map(
              (entry) => _EC2ResourceCard(
                key: ValueKey('ec2-${entry.key}'),
                index: entry.key,
                resource: entry.value,
                onChanged: (r) =>
                    setState(() => _ec2Resources[entry.key] = r),
                onDelete: () =>
                    setState(() => _ec2Resources.removeAt(entry.key)),
              ),
            ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () =>
              setState(() => _ec2Resources.add(EC2ResourceDef())),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add EC2 Instance'),
        ),
      ],
    );
  }
}

// =============================================================================
// S3 Resource Card
// =============================================================================

class _S3ResourceCard extends StatefulWidget {
  final int index;
  final S3ResourceDef resource;
  final ValueChanged<S3ResourceDef> onChanged;
  final VoidCallback onDelete;

  const _S3ResourceCard({
    super.key,
    required this.index,
    required this.resource,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  State<_S3ResourceCard> createState() => _S3ResourceCardState();
}

class _S3ResourceCardState extends State<_S3ResourceCard> {
  late TextEditingController _bucketCtrl;
  late TextEditingController _logBucketCtrl;
  late TextEditingController _logPrefixCtrl;
  bool _expanded = true;

  // Tag editing
  late TextEditingController _tagKeyCtrl;
  late TextEditingController _tagValCtrl;

  @override
  void initState() {
    super.initState();
    _bucketCtrl = TextEditingController(text: widget.resource.bucket);
    _logBucketCtrl =
        TextEditingController(text: widget.resource.loggingTargetBucket);
    _logPrefixCtrl =
        TextEditingController(text: widget.resource.loggingTargetPrefix);
    _tagKeyCtrl = TextEditingController();
    _tagValCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _bucketCtrl.dispose();
    _logBucketCtrl.dispose();
    _logPrefixCtrl.dispose();
    _tagKeyCtrl.dispose();
    _tagValCtrl.dispose();
    super.dispose();
  }

  S3ResourceDef get r => widget.resource;

  void _update(void Function(S3ResourceDef) mutate) {
    mutate(r);
    widget.onChanged(r);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassmorphicCard(
        accentColor: AppColors.accentBlue,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Icon(
                    _expanded
                        ? Icons.expand_more
                        : Icons.chevron_right,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _expanded = !_expanded),
                    child: Text(
                      r.bucket.isEmpty
                          ? 'S3 Bucket #${widget.index + 1}'
                          : r.bucket,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: AppColors.critical),
                  onPressed: widget.onDelete,
                  tooltip: 'Remove',
                ),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: 16),
              // Row 1: Bucket + ACL
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _field(
                      'Bucket Name',
                      _bucketCtrl,
                      (v) => _update((r) => r.bucket = v),
                      hint: 'my-app-bucket',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _dropdown(
                      'ACL',
                      r.acl,
                      ['private', 'public-read', 'public-read-write',
                       'authenticated-read', 'log-delivery-write'],
                      (v) => _update((r) => r.acl = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Row 2: Encryption + Versioning
              Row(
                children: [
                  Expanded(
                    child: _dropdown(
                      'Encryption',
                      r.sseAlgorithm,
                      ['AES256', 'aws:kms'],
                      (v) => _update((r) => r.sseAlgorithm = v),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _toggle(
                      'Versioning',
                      r.versioningEnabled,
                      (v) => _update((r) => r.versioningEnabled = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Public Access Block
              const Text('Public Access Block',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _compactToggle('Block Public ACLs', r.blockPublicAcls,
                      (v) => _update((r) => r.blockPublicAcls = v)),
                  _compactToggle('Ignore Public ACLs', r.ignorePublicAcls,
                      (v) => _update((r) => r.ignorePublicAcls = v)),
                  _compactToggle('Block Public Policy', r.blockPublicPolicy,
                      (v) => _update((r) => r.blockPublicPolicy = v)),
                  _compactToggle(
                      'Restrict Public Buckets',
                      r.restrictPublicBuckets,
                      (v) => _update((r) => r.restrictPublicBuckets = v)),
                ],
              ),
              const SizedBox(height: 16),
              // Logging
              Row(
                children: [
                  Expanded(
                    child: _field(
                      'Logging Target Bucket',
                      _logBucketCtrl,
                      (v) => _update((r) => r.loggingTargetBucket = v),
                      hint: 'Optional',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _field(
                      'Logging Prefix',
                      _logPrefixCtrl,
                      (v) => _update((r) => r.loggingTargetPrefix = v),
                      hint: 'Optional',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Tags
              _buildTagsSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTagsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tags',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        ...r.tags.entries.map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('${e.key}: ${e.value}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textPrimary)),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => _update((r) => r.tags.remove(e.key)),
                  child: const Icon(Icons.close,
                      size: 14, color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            SizedBox(
              width: 120,
              child: TextField(
                controller: _tagKeyCtrl,
                style: const TextStyle(fontSize: 12),
                decoration: const InputDecoration(
                  hintText: 'Key',
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 120,
              child: TextField(
                controller: _tagValCtrl,
                style: const TextStyle(fontSize: 12),
                decoration: const InputDecoration(
                  hintText: 'Value',
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.add_circle_outline,
                  size: 18, color: AppColors.accentBlue),
              onPressed: () {
                final k = _tagKeyCtrl.text.trim();
                final v = _tagValCtrl.text.trim();
                if (k.isNotEmpty) {
                  _update((r) => r.tags[k] = v);
                  _tagKeyCtrl.clear();
                  _tagValCtrl.clear();
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Reusable form helpers
  // ---------------------------------------------------------------------------

  Widget _field(String label, TextEditingController ctrl,
      ValueChanged<String> onChanged,
      {String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }

  Widget _dropdown(String label, String value, List<String> items,
      ValueChanged<String> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: items.contains(value) ? value : items.first,
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
          decoration: const InputDecoration(
            isDense: true,
            contentPadding:
                EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          dropdownColor: AppColors.surfaceElevated,
        ),
      ],
    );
  }

  Widget _toggle(
      String label, bool value, ValueChanged<bool> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        Switch(
          value: value,
          onChanged: (v) {
            setState(() => onChanged(v));
          },
          activeThumbColor: AppColors.accentBlue,
        ),
      ],
    );
  }

  Widget _compactToggle(
      String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 24,
          width: 36,
          child: FittedBox(
            child: Switch(
              value: value,
              onChanged: (v) {
                setState(() => onChanged(v));
              },
              activeThumbColor: AppColors.accentBlue,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}

// =============================================================================
// EC2 Resource Card
// =============================================================================

class _EC2ResourceCard extends StatefulWidget {
  final int index;
  final EC2ResourceDef resource;
  final ValueChanged<EC2ResourceDef> onChanged;
  final VoidCallback onDelete;

  const _EC2ResourceCard({
    super.key,
    required this.index,
    required this.resource,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  State<_EC2ResourceCard> createState() => _EC2ResourceCardState();
}

class _EC2ResourceCardState extends State<_EC2ResourceCard> {
  late TextEditingController _addressCtrl;
  late TextEditingController _amiCtrl;
  late TextEditingController _subnetCtrl;
  late TextEditingController _azCtrl;
  late TextEditingController _keyNameCtrl;
  late TextEditingController _iamProfileCtrl;
  late TextEditingController _sgCtrl;
  late TextEditingController _tagKeyCtrl;
  late TextEditingController _tagValCtrl;
  bool _expanded = true;

  @override
  void initState() {
    super.initState();
    _addressCtrl = TextEditingController(text: widget.resource.address);
    _amiCtrl = TextEditingController(text: widget.resource.ami);
    _subnetCtrl = TextEditingController(text: widget.resource.subnetId);
    _azCtrl = TextEditingController(text: widget.resource.availabilityZone);
    _keyNameCtrl = TextEditingController(text: widget.resource.keyName);
    _iamProfileCtrl =
        TextEditingController(text: widget.resource.iamInstanceProfile);
    _sgCtrl = TextEditingController();
    _tagKeyCtrl = TextEditingController();
    _tagValCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    _amiCtrl.dispose();
    _subnetCtrl.dispose();
    _azCtrl.dispose();
    _keyNameCtrl.dispose();
    _iamProfileCtrl.dispose();
    _sgCtrl.dispose();
    _tagKeyCtrl.dispose();
    _tagValCtrl.dispose();
    super.dispose();
  }

  EC2ResourceDef get r => widget.resource;

  void _update(void Function(EC2ResourceDef) mutate) {
    mutate(r);
    widget.onChanged(r);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassmorphicCard(
        accentColor: AppColors.accentPurple,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Icon(
                    _expanded
                        ? Icons.expand_more
                        : Icons.chevron_right,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _expanded = !_expanded),
                    child: Text(
                      r.address.isEmpty
                          ? 'EC2 Instance #${widget.index + 1}'
                          : r.address,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: AppColors.critical),
                  onPressed: widget.onDelete,
                  tooltip: 'Remove',
                ),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: 16),
              // Row 1: Address + Instance Type
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _field(
                      'Terraform Address',
                      _addressCtrl,
                      (v) => _update((r) => r.address = v),
                      hint: 'aws_instance.web_server',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _dropdown(
                      'Instance Type',
                      r.instanceType,
                      [
                        't3.nano', 't3.micro', 't3.small', 't3.medium',
                        't3.large', 't3.xlarge',
                        'm5.large', 'm5.xlarge', 'm5.2xlarge',
                        'c5.large', 'c5.xlarge',
                        'r5.large', 'r5.xlarge',
                      ],
                      (v) => _update((r) => r.instanceType = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Row 2: AMI + Subnet
              Row(
                children: [
                  Expanded(
                    child: _field(
                      'AMI ID',
                      _amiCtrl,
                      (v) => _update((r) => r.ami = v),
                      hint: 'ami-0abcdef1234567890',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _field(
                      'Subnet ID',
                      _subnetCtrl,
                      (v) => _update((r) => r.subnetId = v),
                      hint: 'Optional',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Row 3: AZ + Key Name
              Row(
                children: [
                  Expanded(
                    child: _field(
                      'Availability Zone',
                      _azCtrl,
                      (v) => _update((r) => r.availabilityZone = v),
                      hint: 'Optional',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _field(
                      'Key Name',
                      _keyNameCtrl,
                      (v) => _update((r) => r.keyName = v),
                      hint: 'Optional',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // IAM Profile
              _field(
                'IAM Instance Profile',
                _iamProfileCtrl,
                (v) => _update((r) => r.iamInstanceProfile = v),
                hint: 'Optional',
              ),
              const SizedBox(height: 16),
              // Toggles row
              Wrap(
                spacing: 24,
                runSpacing: 8,
                children: [
                  _compactToggle('EBS Optimized', r.ebsOptimized,
                      (v) => _update((r) => r.ebsOptimized = v)),
                  _compactToggle('Monitoring', r.monitoring,
                      (v) => _update((r) => r.monitoring = v)),
                ],
              ),
              const SizedBox(height: 16),
              // Root Volume
              const Text('Root Volume',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _dropdown(
                      'Type',
                      r.rootVolumeType,
                      ['gp2', 'gp3', 'io1', 'io2', 'st1', 'sc1'],
                      (v) => _update((r) => r.rootVolumeType = v),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Size (GB)',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: TextEditingController(
                              text: r.rootVolumeSize.toString()),
                          keyboardType: TextInputType.number,
                          onChanged: (v) {
                            final n = int.tryParse(v);
                            if (n != null) _update((r) => r.rootVolumeSize = n);
                          },
                          style: const TextStyle(fontSize: 14),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _compactToggle(
                      'Encrypted',
                      r.rootVolumeEncrypted,
                      (v) => _update((r) => r.rootVolumeEncrypted = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Security Groups
              _buildSecurityGroupsSection(),
              const SizedBox(height: 16),
              // Tags
              _buildTagsSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityGroupsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Security Group IDs',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: r.securityGroupIds.asMap().entries.map((e) {
            return Chip(
              label: Text(e.value,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textPrimary)),
              backgroundColor: AppColors.surfaceElevated,
              deleteIcon: const Icon(Icons.close, size: 14),
              onDeleted: () =>
                  _update((r) => r.securityGroupIds.removeAt(e.key)),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            );
          }).toList(),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            SizedBox(
              width: 200,
              child: TextField(
                controller: _sgCtrl,
                style: const TextStyle(fontSize: 12),
                decoration: const InputDecoration(
                  hintText: 'sg-0123456789abcdef0',
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.add_circle_outline,
                  size: 18, color: AppColors.accentBlue),
              onPressed: () {
                final v = _sgCtrl.text.trim();
                if (v.isNotEmpty) {
                  _update((r) => r.securityGroupIds.add(v));
                  _sgCtrl.clear();
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTagsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tags',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        ...r.tags.entries.map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('${e.key}: ${e.value}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textPrimary)),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => _update((r) => r.tags.remove(e.key)),
                  child: const Icon(Icons.close,
                      size: 14, color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            SizedBox(
              width: 120,
              child: TextField(
                controller: _tagKeyCtrl,
                style: const TextStyle(fontSize: 12),
                decoration: const InputDecoration(
                  hintText: 'Key',
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 120,
              child: TextField(
                controller: _tagValCtrl,
                style: const TextStyle(fontSize: 12),
                decoration: const InputDecoration(
                  hintText: 'Value',
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.add_circle_outline,
                  size: 18, color: AppColors.accentBlue),
              onPressed: () {
                final k = _tagKeyCtrl.text.trim();
                final v = _tagValCtrl.text.trim();
                if (k.isNotEmpty) {
                  _update((r) => r.tags[k] = v);
                  _tagKeyCtrl.clear();
                  _tagValCtrl.clear();
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Reusable form helpers
  // ---------------------------------------------------------------------------

  Widget _field(String label, TextEditingController ctrl,
      ValueChanged<String> onChanged,
      {String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }

  Widget _dropdown(String label, String value, List<String> items,
      ValueChanged<String> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: items.contains(value) ? value : items.first,
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
          decoration: const InputDecoration(
            isDense: true,
            contentPadding:
                EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          dropdownColor: AppColors.surfaceElevated,
        ),
      ],
    );
  }

  Widget _compactToggle(
      String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 24,
          width: 36,
          child: FittedBox(
            child: Switch(
              value: value,
              onChanged: (v) {
                setState(() => onChanged(v));
              },
              activeThumbColor: AppColors.accentBlue,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}

// =============================================================================
// Service Chip (reused from scan screen pattern)
// =============================================================================

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
              color:
                  selected ? AppColors.accentBlue : AppColors.textSecondary,
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
