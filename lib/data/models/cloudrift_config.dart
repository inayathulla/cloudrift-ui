/// Represents a `cloudrift-<service>.yml` configuration file.
///
/// Mirrors the YAML structure consumed by the Cloudrift CLI's Viper config.
/// Used for reading/writing configuration from the UI Settings screen.
class CloudriftConfig {
  /// AWS credentials profile name (from `~/.aws/credentials`).
  final String awsProfile;

  /// AWS region to scan (e.g. `us-east-1`).
  final String region;

  /// Path to the Terraform plan JSON file.
  final String planPath;

  /// Optional directory containing custom OPA `.rego` policy files.
  final String? policyDir;

  /// When `true`, the CLI exits with a non-zero code on policy violations.
  final bool failOnViolation;

  /// When `true`, skips OPA policy evaluation and runs drift detection only.
  final bool skipPolicies;

  const CloudriftConfig({
    required this.awsProfile,
    required this.region,
    required this.planPath,
    this.policyDir,
    this.failOnViolation = false,
    this.skipPolicies = false,
  });

  /// Parses from a decoded YAML map.
  factory CloudriftConfig.fromYaml(Map<String, dynamic> yaml) {
    return CloudriftConfig(
      awsProfile: yaml['aws_profile'] as String? ?? 'default',
      region: yaml['region'] as String? ?? 'us-east-1',
      planPath: yaml['plan_path'] as String? ?? '',
      policyDir: yaml['policy_dir'] as String?,
      failOnViolation: yaml['fail_on_violation'] as bool? ?? false,
      skipPolicies: yaml['skip_policies'] as bool? ?? false,
    );
  }

  /// Serializes to YAML string for writing to a cloudrift config file.
  String toYaml() {
    final buffer = StringBuffer();
    buffer.writeln('aws_profile: $awsProfile');
    buffer.writeln('region: $region');
    buffer.writeln('plan_path: $planPath');
    if (policyDir != null) buffer.writeln('policy_dir: $policyDir');
    if (failOnViolation) buffer.writeln('fail_on_violation: true');
    if (skipPolicies) buffer.writeln('skip_policies: true');
    return buffer.toString();
  }
}
