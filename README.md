<h1 align="center">Cloudrift UI</h1>

<p align="center">
  <strong>Security dashboard for Cloudrift — Desktop & Web</strong><br>
  Visualize infrastructure drift, policy violations, and compliance posture
</p>

<p align="center">
  <a href="https://github.com/inayathulla/cloudrift"><img src="https://img.shields.io/badge/Powered_by-Cloudrift_CLI-blue?style=flat-square" alt="Powered by Cloudrift CLI"></a>
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&style=flat-square" alt="Flutter"></a>
  <a href="https://hub.docker.com/r/inayathulla/cloudrift-ui"><img src="https://img.shields.io/badge/Docker_Hub-inayathulla%2Fcloudrift--ui-2496ED?logo=docker&style=flat-square" alt="Docker Hub"></a>
  <a href="https://inayathulla.github.io/cloudrift-ui/"><img src="https://img.shields.io/badge/Docs-MkDocs-blue?logo=readthedocs&style=flat-square" alt="Documentation"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-Apache_2.0-blue?style=flat-square" alt="License"></a>
</p>

<p align="center">
  <img src="assets/screenshots/01_dashboard.png" alt="Cloudrift UI Dashboard" width="800">
</p>

---

**Cloudrift UI** is a cross-platform dashboard for the [Cloudrift](https://github.com/inayathulla/cloudrift) infrastructure governance CLI. It runs **two ways**:

| Mode | How it works |
|------|-------------|
| **Web via Docker** | One command deploys a full-stack container with Flutter web app, Go API server, nginx, and Terraform |
| **Native Desktop** | Runs directly on macOS, Linux, or Windows with the Cloudrift CLI binary — no server needed |

Both modes share the same codebase, the same 7 screens, and full feature parity.

## Documentation

**[inayathulla.github.io/cloudrift-ui](https://inayathulla.github.io/cloudrift-ui/)** — Getting started, API reference, architecture, development guides, and more.

## Features

| Feature | Description |
|---------|-------------|
| **Real-time Scanning** | Invoke scans for S3, EC2, IAM (or all at once) with per-service config selection |
| **Drift Visualization** | Three-column diff viewer: Attribute / Expected (Terraform) / Actual (AWS) |
| **49 OPA Policies** | Severity filters, framework badges, and remediation guidance |
| **Compliance Frameworks** | HIPAA, GDPR, ISO 27001, PCI DSS, SOC 2 mapping with per-framework compliance rings |
| **Resource Builder** | Three modes: Terraform (auto-generate plan.json), Manual (S3/EC2/IAM forms), Upload (drag & drop) |
| **Interactive Dashboard** | Clickable KPI cards, drift trends, severity breakdown, top failing policies |
| **Scan History** | Persistent history with trend charts and human-readable durations |
| **Docker / Web** | One-command Docker deployment with nginx + Go backend + Terraform built in |

## Screenshots

<details>
<summary>Scan & History</summary>
<img src="assets/screenshots/02_scan.png" alt="Scan & History" width="800">
</details>

<details>
<summary>Resource Builder — Terraform, Manual & Upload</summary>
<img src="assets/screenshots/03_resource_builder.png" alt="Resource Builder" width="800">
</details>

<details>
<summary>Resource Explorer</summary>
<img src="assets/screenshots/04_resources.png" alt="Resources" width="800">
</details>

<details>
<summary>Policy Dashboard — 49 OPA Policies</summary>
<img src="assets/screenshots/05_policies.png" alt="Policies" width="800">
</details>

<details>
<summary>Compliance Scoring</summary>
<img src="assets/screenshots/06_compliance.png" alt="Compliance" width="800">
</details>

<details>
<summary>Settings</summary>
<img src="assets/screenshots/07_settings.png" alt="Settings" width="800">
</details>

## Quick Start — Docker (Recommended)

```bash
# Pull and run
docker run -d -p 8080:80 \
  -v ~/.aws:/root/.aws:ro \
  --name cloudrift-ui \
  inayathulla/cloudrift-ui:latest

# Open in browser
open http://localhost:8080
```

Or build from source:

```bash
docker build -t cloudrift-ui .
docker run -d -p 8080:80 -v ~/.aws:/root/.aws:ro --name cloudrift-ui cloudrift-ui:latest
```

> **Note:** The `-v ~/.aws:/root/.aws:ro` mount is required for scans and Terraform to authenticate with AWS.

## Quick Start — Desktop

```bash
# Prerequisites: Flutter 3.x, Cloudrift CLI, AWS credentials

git clone https://github.com/inayathulla/cloudrift-ui.git
cd cloudrift-ui
flutter pub get
flutter run -d macos    # or -d linux / -d windows
```

The desktop app auto-detects the Cloudrift CLI binary from common paths or system PATH. Override in **Settings**.

## Architecture

```
                         Cloudrift UI
    ┌────────────────────────────────────────────────────┐
    │              Flutter (Desktop + Web)                │
    │                                                    │
    │   Dashboard / Scan / Builder / Resources /         │
    │   Policies / Compliance / Settings                 │
    │                       |                            │
    │              Riverpod Providers                    │
    │                       |                            │
    │              CLI Datasource (kIsWeb?)               │
    └──────────┬────────────────────────┬────────────────┘
               |                        |
       Desktop Mode               Web / Docker Mode
               |                        |
      Process.run() on             HTTP to Go API
      Cloudrift binary             server (:8081)
                                        |
                                   nginx (:80)
                                   reverse proxy
```

| Layer | Technology |
|-------|-----------|
| **Frontend** | Flutter 3.x, Riverpod, GoRouter, fl_chart |
| **Backend** | Go net/http server (web mode only) |
| **Storage** | Hive (scan history, settings) |
| **Container** | Docker multi-stage build, nginx, supervisord |

See the [Architecture docs](https://inayathulla.github.io/cloudrift-ui/architecture/overview/) for data flow, state management, and deployment details.

## Development

```bash
flutter pub get                    # Install dependencies
flutter run -d macos               # Run desktop app
flutter run -d chrome              # Run web app
flutter analyze                    # Static analysis (must pass clean)
flutter test                       # Run tests
```

```bash
# Go API server (for web mode)
cd server && go build -o cloudrift-api main.go
API_PORT=8081 ./cloudrift-api
```

See the [Development docs](https://inayathulla.github.io/cloudrift-ui/development/local-setup/) for project structure, adding screens, and testing.

## Related Projects

| Project | Description |
|---------|-------------|
| [**Cloudrift CLI**](https://github.com/inayathulla/cloudrift) | Go CLI for infrastructure drift detection and OPA policy evaluation |

## Contributing

```bash
git clone https://github.com/inayathulla/cloudrift-ui.git
cd cloudrift-ui
flutter pub get
flutter test && flutter analyze
```

See the [Contributing guide](https://inayathulla.github.io/cloudrift-ui/contributing/) for details.

## Connect

- **Cloudrift CLI:** [github.com/inayathulla/cloudrift](https://github.com/inayathulla/cloudrift)
- **Issues & Features:** [GitHub Issues](https://github.com/inayathulla/cloudrift-ui/issues)
- **Email:** [inayathulla2020@gmail.com](mailto:inayathulla2020@gmail.com)
- **LinkedIn:** [Inayathulla Khan Lavani](https://www.linkedin.com/in/inayathullakhan)

## License

[Apache License 2.0](LICENSE)
