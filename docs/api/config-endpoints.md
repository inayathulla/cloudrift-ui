# Config Endpoints

## GET /api/config

Read a cloudrift YAML configuration file.

### Request

```bash
curl "http://localhost:8080/api/config?path=/etc/cloudrift/config/cloudrift-s3.yml"
```

**Query Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `path` | string | yes | Absolute path to the config file |

### Response (200)

Returns the raw YAML content as `text/plain`:

```yaml
aws_profile: default
region: us-east-1
plan_path: ./examples/terraform-plan.json
```

### Error Response (400)

```json
{
  "error": "path parameter is required"
}
```

### Error Response (404)

```json
{
  "error": "config file not found"
}
```

---

## PUT /api/config

Write a cloudrift YAML configuration file.

### Request

```bash
curl -X PUT "http://localhost:8080/api/config?path=/etc/cloudrift/config/cloudrift-s3.yml" \
  -d 'aws_profile: production
region: eu-west-1
plan_path: /etc/cloudrift/examples/terraform-plan.json'
```

**Query Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `path` | string | yes | Absolute path to write the config file |

**Body:** Raw YAML content (Content-Type is not enforced).

### Response (200)

```json
{
  "status": "ok"
}
```

### Error Response (400)

```json
{
  "error": "path contains invalid characters"
}
```

!!! warning "Path validation"
    Paths containing `..` are rejected to prevent directory traversal attacks.
