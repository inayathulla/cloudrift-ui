# Security Policies

Cloudrift evaluates 49 OPA (Open Policy Agent) security policies across 15 service categories. Each policy checks a specific security best practice against your AWS resources.

![Policies](../assets/screenshots/05_policies.png)

## Severity Levels

| Severity | Count | Meaning |
|----------|-------|---------|
| <span class="severity-critical">CRITICAL</span> | 7 | Immediate security risk — fix now |
| <span class="severity-high">HIGH</span> | 14 | Significant security concern |
| <span class="severity-medium">MEDIUM</span> | 20 | Moderate risk, should be addressed |
| <span class="severity-low">LOW</span> | 8 | Best practice recommendation |

## Policy Catalog

### S3 Storage (9 policies)

??? info "S3-001: S3 Encryption Required — <span class='severity-high'>HIGH</span>"
    All S3 buckets must have server-side encryption enabled to protect data at rest.

??? info "S3-002: S3 KMS Encryption Recommended — <span class='severity-low'>LOW</span>"
    Use AWS KMS for server-side encryption for better key management and auditing.

??? info "S3-003: S3 Block Public ACLs — <span class='severity-high'>HIGH</span>"
    S3 buckets must have `block_public_acls` enabled to prevent public access via ACLs.

??? info "S3-004: S3 Block Public Policy — <span class='severity-high'>HIGH</span>"
    S3 buckets must have `block_public_policy` enabled to prevent public bucket policies.

??? info "S3-005: S3 Ignore Public ACLs — <span class='severity-high'>HIGH</span>"
    S3 buckets must have `ignore_public_acls` enabled to override any public ACLs.

??? info "S3-006: S3 Restrict Public Buckets — <span class='severity-high'>HIGH</span>"
    S3 buckets must have `restrict_public_buckets` enabled.

??? info "S3-007: S3 No Public Read ACL — <span class='severity-critical'>CRITICAL</span>"
    S3 buckets must not use `public-read` ACL. Public read access exposes data to the internet.

??? info "S3-008: S3 No Public Read-Write ACL — <span class='severity-critical'>CRITICAL</span>"
    S3 buckets must not use `public-read-write` ACL. Public write access is a critical risk.

??? info "S3-009: S3 Versioning Recommended — <span class='severity-medium'>MEDIUM</span>"
    Enable versioning for data protection and recovery from accidental deletion.

### EC2 Compute (3 policies)

??? info "EC2-001: EC2 IMDSv2 Required — <span class='severity-medium'>MEDIUM</span>"
    EC2 instances must use Instance Metadata Service v2 (IMDSv2) to prevent SSRF attacks.

??? info "EC2-002: EC2 Root Volume Encryption — <span class='severity-high'>HIGH</span>"
    EC2 instances must encrypt root EBS volumes to protect data at rest.

??? info "EC2-003: EC2 Public IP Warning — <span class='severity-medium'>MEDIUM</span>"
    EC2 instances should avoid public IP addresses unless explicitly required.

### Security Groups (4 policies)

??? info "SG-001: No Unrestricted SSH — <span class='severity-critical'>CRITICAL</span>"
    Security groups must not allow SSH (port 22) from `0.0.0.0/0`.

??? info "SG-002: No Unrestricted RDP — <span class='severity-critical'>CRITICAL</span>"
    Security groups must not allow RDP (port 3389) from `0.0.0.0/0`.

??? info "SG-003: No Unrestricted All Ports — <span class='severity-critical'>CRITICAL</span>"
    Security groups must not allow all ports from `0.0.0.0/0`.

??? info "SG-004: Database Ports Not Public — <span class='severity-high'>HIGH</span>"
    Database ports (3306, 5432, 1433, 27017) must not be open to the internet.

### RDS Databases (5 policies)

??? info "RDS-001: RDS Storage Encryption Required — <span class='severity-high'>HIGH</span>"
    RDS instances must have storage encryption enabled.

??? info "RDS-002: RDS No Public Access — <span class='severity-critical'>CRITICAL</span>"
    RDS instances must have `publicly_accessible` set to false.

??? info "RDS-003: RDS Backup Retention Period — <span class='severity-medium'>MEDIUM</span>"
    RDS backup retention should be at least 7 days.

??? info "RDS-004: RDS Deletion Protection — <span class='severity-medium'>MEDIUM</span>"
    Enable deletion protection to prevent accidental database deletion.

??? info "RDS-005: RDS Multi-AZ Recommended — <span class='severity-low'>LOW</span>"
    Use Multi-AZ deployment for high availability.

### IAM (3 policies)

??? info "IAM-001: No Wildcard IAM Actions — <span class='severity-critical'>CRITICAL</span>"
    IAM policies must not use `*` (wildcard) for actions. Follow the principle of least privilege.

??? info "IAM-002: No Inline Policies on Users — <span class='severity-medium'>MEDIUM</span>"
    Use managed policies instead of inline policies on IAM users for better governance.

??? info "IAM-003: IAM Role Trust Not Too Broad — <span class='severity-high'>HIGH</span>"
    IAM role trust policies should restrict who can assume the role.

### CloudTrail (3 policies)

??? info "CT-001: CloudTrail KMS Encryption — <span class='severity-high'>HIGH</span>"
    CloudTrail logs must be encrypted with AWS KMS.

??? info "CT-002: CloudTrail Log File Validation — <span class='severity-medium'>MEDIUM</span>"
    Enable log file validation to detect tampering.

??? info "CT-003: CloudTrail Multi-Region — <span class='severity-medium'>MEDIUM</span>"
    Enable CloudTrail for all regions.

### KMS (2 policies)

??? info "KMS-001: KMS Key Rotation Enabled — <span class='severity-high'>HIGH</span>"
    Enable automatic key rotation for KMS customer-managed keys.

??? info "KMS-002: KMS Deletion Window Minimum — <span class='severity-medium'>MEDIUM</span>"
    KMS key deletion window should be at least 14 days.

### EBS (2 policies)

??? info "EBS-001: EBS Volume Encryption — <span class='severity-high'>HIGH</span>"
    All EBS volumes must be encrypted.

??? info "EBS-002: EBS Snapshot Encryption — <span class='severity-high'>HIGH</span>"
    All EBS snapshots must be encrypted.

### Lambda (2 policies)

??? info "LAMBDA-001: Lambda X-Ray Tracing — <span class='severity-medium'>MEDIUM</span>"
    Enable X-Ray tracing for Lambda functions for observability.

??? info "LAMBDA-002: Lambda VPC Configuration — <span class='severity-medium'>MEDIUM</span>"
    Lambda functions should run inside a VPC for network isolation.

### ELB/ALB (3 policies)

??? info "ELB-001: ALB Access Logging — <span class='severity-medium'>MEDIUM</span>"
    Enable access logging for Application Load Balancers.

??? info "ELB-002: ALB HTTPS Listener Required — <span class='severity-high'>HIGH</span>"
    ALB listeners must use HTTPS protocol.

??? info "ELB-003: ALB Deletion Protection — <span class='severity-medium'>MEDIUM</span>"
    Enable deletion protection for ALBs.

### CloudWatch Logging (2 policies)

??? info "LOG-001: CloudWatch Log Group KMS Encryption — <span class='severity-medium'>MEDIUM</span>"
    CloudWatch Log Groups should use KMS encryption.

??? info "LOG-002: CloudWatch Log Retention — <span class='severity-medium'>MEDIUM</span>"
    CloudWatch Log Groups should have a retention period configured.

### VPC / Networking (2 policies)

??? info "VPC-001: Default Security Group Restrict All — <span class='severity-high'>HIGH</span>"
    The default security group should restrict all inbound and outbound traffic.

??? info "VPC-002: Subnet No Auto-Assign Public IP — <span class='severity-medium'>MEDIUM</span>"
    Subnets should not auto-assign public IP addresses.

### Secrets Manager (2 policies)

??? info "SECRET-001: Secrets Manager KMS Encryption — <span class='severity-medium'>MEDIUM</span>"
    Secrets should use customer-managed KMS keys for encryption.

??? info "SECRET-002: Secrets Automatic Rotation — <span class='severity-medium'>MEDIUM</span>"
    Secrets should have automatic rotation configured.

### Cost Optimization (3 policies)

??? info "EC2-005: EC2 Large Instance Review — <span class='severity-medium'>MEDIUM</span>"
    Large EC2 instances should be reviewed for right-sizing opportunities.

??? info "COST-002: Very Large Instance Size — <span class='severity-medium'>MEDIUM</span>"
    Very large instance types (xlarge+) should be justified.

??? info "COST-003: Previous Generation Instance — <span class='severity-low'>LOW</span>"
    Migrate from previous-generation instance types to current generation.

### Tagging (4 policies)

??? info "TAG-001: Environment Tag Required — <span class='severity-medium'>MEDIUM</span>"
    All resources must have an `Environment` tag.

??? info "TAG-002: Owner Tag Recommended — <span class='severity-low'>LOW</span>"
    Resources should have an `Owner` tag for accountability.

??? info "TAG-003: Project Tag Recommended — <span class='severity-low'>LOW</span>"
    Resources should have a `Project` tag for cost allocation.

??? info "TAG-004: Name Tag Recommended — <span class='severity-low'>LOW</span>"
    Resources should have a `Name` tag for identification.

## Custom Policies

You can add custom OPA policies by placing `.rego` files in a custom directory and setting `policy_dir` in your config:

```yaml
policy_dir: ./my-policies
```

Or pass it via CLI flag:

```bash
cloudrift scan --policy-dir=./my-policies
```
