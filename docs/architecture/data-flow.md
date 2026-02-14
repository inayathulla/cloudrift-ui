# Data Flow

Cloudrift has two distinct data flow paths depending on whether it's running as a desktop app or in Docker.

## Desktop Data Flow

```mermaid
sequenceDiagram
    participant UI as Flutter UI
    participant DS as CliDatasource
    participant CLI as cloudrift binary
    participant AWS as AWS APIs

    UI->>DS: runScan(service, config)
    DS->>CLI: Process.run("cloudrift scan --format=json")
    CLI->>AWS: DescribeInstances / ListBuckets
    AWS-->>CLI: Resource data
    CLI-->>DS: JSON stdout
    DS-->>UI: ScanResult
    UI->>UI: Update providers & render
```

**Desktop path details:**

1. User clicks "Run Scan" on the Scan screen
2. `ScanNotifier` calls `ScanRepository.runScan()`
3. `ScanRepository` calls `CliDatasource.runScan()`
4. `CliDatasource._runScanDesktop()` invokes `Process.run` with the CLI binary
5. CLI args: `scan --config=<path> --service=<svc> --format=json --no-emoji`
6. Working directory is set to the CLI repo folder
7. CLI queries AWS APIs and evaluates OPA policies
8. JSON output is parsed from stdout using `_extractJson()`
9. `ScanResult.fromJson()` deserializes the response
10. `ScanNotifier` updates state → all dependent providers recompute

## Web Data Flow

```mermaid
sequenceDiagram
    participant Browser as Flutter Web
    participant Nginx as nginx :80
    participant API as Go API :8081
    participant CLI as cloudrift binary
    participant AWS as AWS APIs

    Browser->>Nginx: POST /api/scan
    Nginx->>API: Proxy to :8081
    API->>CLI: exec.Command("cloudrift scan")
    CLI->>AWS: DescribeInstances / ListBuckets
    AWS-->>CLI: Resource data
    CLI-->>API: JSON stdout
    API-->>Nginx: JSON response
    Nginx-->>Browser: JSON response
    Browser->>Browser: Update providers & render
```

**Web path details:**

1. Same UI trigger, but `kIsWeb` is `true`
2. `CliDatasource._runScanWeb()` sends HTTP POST to `/api/scan`
3. nginx proxies the request to the Go API on port 8081
4. Go API executes the CLI binary as a subprocess
5. CLI output is captured and returned as JSON
6. Response flows back through nginx to the browser
7. Same `ScanResult.fromJson()` deserialization

## Terraform Data Flow (Web Only)

```mermaid
sequenceDiagram
    participant Browser as Flutter Web
    participant API as Go API
    participant TF as Terraform

    Browser->>API: POST /api/terraform/upload (files)
    API-->>Browser: {uploaded: [...]}

    Browser->>API: POST /api/terraform/plan
    API-->>Browser: {job_id: "abc123"}

    loop Poll every 2s
        Browser->>API: GET /api/terraform/job?id=abc123
        API-->>Browser: {status: "running", phase: "init"}
    end

    API->>TF: terraform init
    TF-->>API: Success
    API->>TF: terraform plan -out=tfplan
    TF-->>API: Success
    API->>TF: terraform show -json tfplan
    TF-->>API: Plan JSON

    Browser->>API: GET /api/terraform/job?id=abc123
    API-->>Browser: {status: "completed", plan_path: "..."}
```

## State Flow

```mermaid
graph LR
    ScanNotifier -->|invalidates| ScanHistory
    ScanHistory -->|watched by| LatestResult
    LatestResult -->|watched by| ResourceSummaries
    LatestResult -->|watched by| ComplianceScore
    ResourceSummaries -->|renders| Dashboard
    ComplianceScore -->|renders| Dashboard
    ResourceSummaries -->|renders| Resources
    ComplianceScore -->|renders| Compliance
```

All derived providers use Riverpod's `watch` mechanism. When `ScanNotifier` completes a scan, it invalidates `scanHistoryProvider`, which triggers a cascade of recomputations through all dependent providers. The UI rebuilds automatically.
