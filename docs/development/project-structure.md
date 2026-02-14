# Project Structure

## Directory Layout

```
cloudrift-ui/
├── lib/
│   ├── main.dart                          # App entry point
│   ├── core/
│   │   ├── constants/
│   │   │   ├── policy_catalog.dart        # 49 OPA security policies
│   │   │   └── compliance_frameworks.dart # 5 framework definitions
│   │   └── theme/
│   │       ├── app_colors.dart            # Dark theme color palette
│   │       └── app_theme.dart             # ThemeData configuration
│   ├── data/
│   │   ├── datasources/
│   │   │   ├── cli_datasource.dart        # CLI execution (desktop) / HTTP (web)
│   │   │   ├── config_datasource.dart     # YAML config + Terraform operations
│   │   │   └── local_storage_datasource.dart # Hive persistence
│   │   └── models/
│   │       ├── cloudrift_config.dart      # Config YAML model
│   │       ├── scan_result.dart           # Scan output model
│   │       ├── terraform_status.dart      # Terraform availability model
│   │       └── terraform_job.dart         # Async job status model
│   ├── providers/
│   │   └── providers.dart                 # All Riverpod providers
│   └── presentation/
│       ├── router/
│       │   └── app_router.dart            # GoRouter configuration
│       ├── shell/
│       │   └── app_shell.dart             # NavigationRail sidebar
│       ├── screens/
│       │   ├── dashboard/
│       │   │   └── dashboard_screen.dart
│       │   ├── scan/
│       │   │   └── scan_screen.dart
│       │   ├── resource_builder/
│       │   │   └── resource_builder_screen.dart
│       │   ├── resources/
│       │   │   └── resources_screen.dart
│       │   ├── resource_detail/
│       │   │   └── resource_detail_screen.dart
│       │   ├── policies/
│       │   │   └── policies_screen.dart
│       │   ├── compliance/
│       │   │   └── compliance_screen.dart
│       │   └── settings/
│       │       └── settings_screen.dart
│       └── widgets/                       # Shared UI components
├── server/
│   ├── main.go                            # Go API server (14 endpoints)
│   └── go.mod                             # Go module definition
├── assets/
│   └── screenshots/                       # App screenshots for README
├── docs/                                  # MkDocs documentation source
├── Dockerfile                             # 4-stage multi-stage build
├── nginx.conf                             # nginx reverse proxy config
├── supervisord.conf                       # Process manager config
├── pubspec.yaml                           # Flutter dependencies
├── mkdocs.yml                             # Documentation site config
└── README.md
```

## Layer Responsibilities

### `lib/core/`

Constants and theme definitions shared across the entire app.

- **`policy_catalog.dart`** — Defines all 49 policies with ID, name, description, severity, and compliance framework mappings
- **`compliance_frameworks.dart`** — Defines the 5 frameworks (HIPAA, GDPR, ISO 27001, PCI DSS, SOC 2) with their labels and JSON parsing
- **`app_colors.dart`** — 16+ named colors for the dark theme (backgrounds, severities, accents, text hierarchy)
- **`app_theme.dart`** — Assembles colors and Google Fonts into a `ThemeData`

### `lib/data/`

Data access layer — talks to CLI, files, and storage.

- **`cli_datasource.dart`** — Dual-mode: `Process.run` on desktop, HTTP on web. Handles path detection, scan execution, JSON extraction
- **`config_datasource.dart`** — Reads/writes YAML configs. On web, also handles Terraform status, file uploads, and plan generation via HTTP
- **`local_storage_datasource.dart`** — Hive-based persistence for scan history entries
- **Models** — Data classes with `fromJson()` / `toJson()` for serialization

### `lib/providers/`

Riverpod provider definitions connecting data to UI.

- Datasource providers (singletons)
- Repository provider (combines datasources)
- `ScanNotifier` (StateNotifier managing scan lifecycle)
- Derived providers (computed from scan results)

### `lib/presentation/`

Everything the user sees and interacts with.

- **`app_router.dart`** — GoRouter with ShellRoute for persistent sidebar
- **`app_shell.dart`** — NavigationRail with 8 color-coded destinations
- **Screens** — One folder per screen, each with a single `*_screen.dart` file
- **Widgets** — Reusable components (charts, cards, tables, loading states)

### `server/`

Go backend for Docker/web deployment.

- **`main.go`** — Single-file HTTP server with 14 endpoints, CORS, path validation, async job pipeline
