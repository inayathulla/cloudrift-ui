# Resource Builder

The Resource Builder generates Terraform plan JSON files that Cloudrift uses for drift detection. Three input modes are available.

![Resource Builder](../assets/screenshots/03_resource_builder.png)

## Modes

### Terraform Mode

Run `terraform plan` directly from the UI.

1. Upload your `.tf` and `.tfvars` files
2. Cloudrift runs `terraform init` → `terraform plan` → `terraform show -json`
3. The resulting plan JSON is saved and ready for scanning

This mode requires Terraform to be available:

- **Docker**: Terraform 1.7.5 is pre-installed in the container
- **Desktop**: Install Terraform separately (`brew install terraform`)

The Terraform pipeline runs asynchronously with three phases:

| Phase | Timeout | Description |
|-------|---------|-------------|
| `init` | 10 min | Downloads providers and initializes backend |
| `plan` | 10 min | Creates the execution plan |
| `show` | 5 min | Converts binary plan to JSON |

You can poll the job status to see progress and phase transitions.

### Manual Mode

Build a plan JSON structure using a form-based editor:

1. Select the AWS service type
2. Fill in resource attributes (name, region, settings)
3. The builder generates a valid Terraform plan JSON

This is useful when you don't have Terraform files but want to define your expected infrastructure state.

#### Supported Services

| Service | Resource Types |
|---------|---------------|
| **S3** | Buckets (encryption, versioning, public access, ACLs, tags) |
| **EC2** | Instances (AMI, type, subnet, security groups, tags) |
| **IAM** | Roles, Users, Policies, Groups (trust policies, attached policies, members, tags) |

### Upload Mode

Upload an existing Terraform plan JSON file:

1. Click the upload area or drag and drop
2. The file is validated and saved
3. The config is updated to point to the uploaded file

Generate plan files from the command line:

```bash
terraform plan -out=tfplan
terraform show -json tfplan > plan.json
```

## Web API Integration

In Docker/web mode, the Resource Builder uses these API endpoints:

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/terraform/status` | GET | Check Terraform availability |
| `/api/terraform/upload` | POST | Upload .tf/.tfvars files |
| `/api/terraform/plan` | POST | Start async plan job |
| `/api/terraform/job?id=` | GET | Poll job status |
| `/api/files/upload` | POST | Upload plan JSON |
| `/api/files/generate-plan` | POST | Generate plan from form data |

See the [Terraform Endpoints](../api/terraform-endpoints.md) documentation for full API details.
