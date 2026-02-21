# File Endpoints

## GET /api/files/plan

Read a Terraform plan JSON file.

### Request

```bash
curl "http://localhost:8080/api/files/plan?path=/etc/cloudrift/examples/terraform-plan.json"
```

**Query Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `path` | string | yes | Path to the plan JSON file |

### Response (200)

Returns the JSON file content with `Content-Type: application/json`.

---

## PUT /api/files/plan

Write a Terraform plan JSON file.

### Request

```bash
curl -X PUT "http://localhost:8080/api/files/plan?path=/etc/cloudrift/examples/my-plan.json" \
  -H "Content-Type: application/json" \
  -d '{"format_version":"1.2","terraform_version":"1.7.5","planned_values":{}}'
```

**Query Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `path` | string | yes | Path to write the plan JSON file |

**Body:** Valid JSON content.

### Response (200)

```json
{
  "status": "ok"
}
```

---

## GET /api/files/list

List available config and plan files.

### Request

```bash
curl http://localhost:8080/api/files/list
```

### Response (200)

```json
{
  "configs": [
    "/etc/cloudrift/config/cloudrift-s3.yml",
    "/etc/cloudrift/config/cloudrift-ec2.yml"
  ],
  "plans": [
    "/etc/cloudrift/examples/terraform-plan.json",
    "/etc/cloudrift/examples/ec2-plan.json"
  ]
}
```

Searches the config and examples directories for `.yml`/`.yaml` and `.json` files.

---

## POST /api/files/upload

Upload a Terraform plan JSON file via multipart form.

### Request

```bash
curl -X POST http://localhost:8080/api/files/upload \
  -F "file=@plan.json"
```

**Multipart Fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `file` | file | yes | JSON plan file to upload |

### Response (200)

```json
{
  "status": "ok",
  "path": "/etc/cloudrift/examples/plan.json",
  "name": "plan.json"
}
```

The file is saved to the examples directory with its original filename.

---

## POST /api/files/generate-plan

Generate a Terraform plan JSON file from form-submitted resource data.

### Request

```bash
curl -X POST http://localhost:8080/api/files/generate-plan \
  -H "Content-Type: application/json" \
  -d '{
    "service": "s3",
    "plan": {
      "resource_type": "aws_s3_bucket",
      "resource_name": "my-bucket",
      "attributes": {
        "bucket": "my-bucket",
        "acl": "private",
        "versioning": { "enabled": true },
        "server_side_encryption_configuration": {
          "rule": {
            "apply_server_side_encryption_by_default": {
              "sse_algorithm": "aws:kms"
            }
          }
        }
      }
    }
  }'
```

**Body Parameters:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `service` | string | yes | AWS service type |
| `plan` | object | yes | Resource definition with type, name, and attributes |

### Response (200)

```json
{
  "status": "ok",
  "plan_path": "/etc/cloudrift/examples/generated-plan.json",
  "config": "/etc/cloudrift/config/cloudrift-s3.yml"
}
```

Generates a valid Terraform plan JSON structure and updates the config file to reference it.
