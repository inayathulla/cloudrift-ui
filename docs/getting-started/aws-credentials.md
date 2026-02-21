# AWS Credentials

Cloudrift needs read-only AWS access to scan your infrastructure. It uses the standard AWS credential chain.

## Credential Resolution Order

1. **Environment variables** — `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`
2. **Shared credentials file** — `~/.aws/credentials` (profile from `aws_profile` in config)
3. **AWS config file** — `~/.aws/config`
4. **EC2 instance role** — IAM role attached to the instance
5. **ECS task role** — IAM role attached to the ECS task

## Docker Setup

Mount your AWS credentials into the container:

```bash
docker run -p 8080:80 \
  -v ~/.aws:/root/.aws:ro \
  inayathulla/cloudrift-ui:latest
```

!!! warning "Read-only mount"
    Always use `:ro` to mount credentials read-only. Cloudrift never writes to your credentials file.

### Using Environment Variables

```bash
docker run -p 8080:80 \
  -e AWS_ACCESS_KEY_ID=AKIA... \
  -e AWS_SECRET_ACCESS_KEY=... \
  -e AWS_DEFAULT_REGION=us-east-1 \
  inayathulla/cloudrift-ui:latest
```

### Using a Named Profile

```bash
docker run -p 8080:80 \
  -v ~/.aws:/root/.aws:ro \
  -e AWS_PROFILE=production \
  inayathulla/cloudrift-ui:latest
```

Then set `aws_profile: production` in your `cloudrift-s3.yml`.

## Desktop Setup

The desktop app inherits your shell environment. If `aws` CLI works, Cloudrift will too.

```bash
# Verify credentials
aws sts get-caller-identity
```

## Required IAM Permissions

Cloudrift needs **read-only** access to the services you're scanning:

### S3 Scanning

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetBucketEncryption",
        "s3:GetBucketVersioning",
        "s3:GetBucketPublicAccessBlock",
        "s3:GetBucketAcl",
        "s3:GetBucketTagging",
        "s3:ListAllMyBuckets"
      ],
      "Resource": "*"
    }
  ]
}
```

### EC2 Scanning

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeInstances",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeVolumes",
        "ec2:DescribeSubnets",
        "ec2:DescribeVpcs"
      ],
      "Resource": "*"
    }
  ]
}
```

### IAM Scanning

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "iam:GetRole",
        "iam:ListRoles",
        "iam:ListRolePolicies",
        "iam:ListAttachedRolePolicies",
        "iam:GetUser",
        "iam:ListUsers",
        "iam:ListUserPolicies",
        "iam:ListAttachedUserPolicies",
        "iam:GetPolicy",
        "iam:GetPolicyVersion",
        "iam:ListPolicies",
        "iam:GetGroup",
        "iam:ListGroups",
        "iam:ListGroupPolicies",
        "iam:ListAttachedGroupPolicies",
        "iam:ListGroupsForUser"
      ],
      "Resource": "*"
    }
  ]
}
```

!!! tip "Use AWS managed policies"
    For quick setup, attach `ReadOnlyAccess` or the service-specific read-only policies like `AmazonS3ReadOnlyAccess`, `AmazonEC2ReadOnlyAccess`, and `IAMReadOnlyAccess`.

## Troubleshooting

### "NoCredentialProviders" Error

The CLI cannot find valid AWS credentials.

1. Check that `~/.aws/credentials` exists and contains the profile
2. For Docker, verify the volume mount: `docker exec <container> cat /root/.aws/credentials`
3. Try setting credentials via environment variables

### "ExpiredToken" Error

Your AWS session token has expired.

```bash
# Refresh SSO credentials
aws sso login --profile your-profile

# Or refresh STS credentials
aws sts get-session-token
```

### "AccessDenied" Error

Your IAM user/role lacks the required permissions. Check the IAM permissions section above and verify your policy allows the necessary `Describe*` and `Get*` actions.

### Docker-Specific Issues

If scans work on desktop but fail in Docker:

1. Verify the mount: `docker exec <container> ls -la /root/.aws/`
2. Check the profile exists: `docker exec <container> cat /root/.aws/credentials`
3. Test from inside the container: `docker exec <container> cloudrift scan --help`
