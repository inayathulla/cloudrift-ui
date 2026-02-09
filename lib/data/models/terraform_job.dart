/// Response from `GET /api/terraform/job?id=...`.
class TerraformJobResult {
  final String id;
  final String status;
  final String phase;
  final String error;
  final String planPath;
  final int elapsedSeconds;
  final String output;

  const TerraformJobResult({
    required this.id,
    required this.status,
    required this.phase,
    required this.error,
    required this.planPath,
    required this.elapsedSeconds,
    required this.output,
  });

  bool get isRunning =>
      status == 'pending' ||
      status == 'init' ||
      status == 'plan' ||
      status == 'show';

  bool get isCompleted => status == 'completed';
  bool get isError => status == 'error';

  factory TerraformJobResult.fromJson(Map<String, dynamic> json) {
    return TerraformJobResult(
      id: json['id'] as String? ?? '',
      status: json['status'] as String? ?? '',
      phase: json['phase'] as String? ?? '',
      error: json['error'] as String? ?? '',
      planPath: json['plan_path'] as String? ?? '',
      elapsedSeconds: json['elapsed_s'] as int? ?? 0,
      output: json['output'] as String? ?? '',
    );
  }
}
