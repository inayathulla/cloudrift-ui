# Scan Endpoints

## POST /api/scan

Run an infrastructure drift scan.

### Request

```bash
curl -X POST http://localhost:8080/api/scan \
  -H "Content-Type: application/json" \
  -d '{
    "service": "s3",
    "config_path": "/etc/cloudrift/config/cloudrift.yml"
  }'
```

**Body Parameters:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `service` | string | yes | AWS service to scan (`s3`, `ec2`) |
| `config_path` | string | yes | Path to cloudrift YAML config file |
| `policy_dir` | string | no | Custom OPA policy directory |
| `skip_policies` | bool | no | Skip policy evaluation |

### Response (200)

```json
{
  "scan_summary": {
    "service": "s3",
    "total_resources": 5,
    "drifted_resources": 2,
    "total_violations": 8,
    "scan_duration_ms": 1234
  },
  "resources": [
    {
      "resource_type": "aws_s3_bucket",
      "resource_name": "my-bucket",
      "drift": {
        "added": [],
        "removed": [],
        "changed": [
          {
            "attribute": "versioning.enabled",
            "expected": "true",
            "actual": "false"
          }
        ]
      },
      "violations": [
        {
          "policy_id": "S3-001",
          "policy_name": "S3 Encryption Required",
          "severity": "HIGH",
          "message": "S3 bucket must have server-side encryption enabled"
        }
      ]
    }
  ],
  "compliance": {
    "hipaa": { "score": 85.0, "passing": 19, "total": 22 },
    "gdpr": { "score": 90.0, "passing": 15, "total": 17 },
    "iso_27001": { "score": 78.0, "passing": 25, "total": 32 },
    "pci_dss": { "score": 82.0, "passing": 28, "total": 34 },
    "soc2": { "score": 75.0, "passing": 37, "total": 49 }
  }
}
```

### Error Response (400/500)

```json
{
  "error": "Scan failed (exit code 1): config file not found"
}
```

---

## GET /api/health

Check if the Cloudrift CLI binary is available.

### Request

```bash
curl http://localhost:8080/api/health
```

### Response (200)

```json
{
  "available": true
}
```

If the CLI binary is not found or not executable, `available` will be `false`.

---

## GET /api/version

Get the Cloudrift CLI version string.

### Request

```bash
curl http://localhost:8080/api/version
```

### Response (200)

```json
{
  "version": "cloudrift v1.0.0"
}
```

Returns the output of `cloudrift --version`.
