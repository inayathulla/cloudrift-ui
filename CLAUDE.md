# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Development Commands

```bash
# Flutter
flutter pub get                    # Install dependencies
flutter run -d macos               # Run desktop app
flutter run -d chrome              # Run web app (needs API server for scans)
flutter build macos --release      # Build macOS release (~44 MB)
flutter build web --release        # Build web SPA → build/web/
flutter analyze                    # Static analysis — must pass with zero issues
flutter test                       # Run tests

# Go API server (for web mode)
cd server && go build -o cloudrift-api main.go
API_PORT=8081 ./cloudrift-api

# Docker (full stack)
docker build -t cloudrift-ui .
docker run -p 8080:80 -v ~/.aws:/root/.aws:ro cloudrift-ui

# Documentation
mkdocs serve                       # Preview docs at localhost:8000
mkdocs build --strict              # Build docs (fails on broken links)
```
## Testing and Documentation
1. Make sure to add inline comments for each file change.
2. Make sure to add test cases for code written.
3. Make sure to test end to end, all scenarios in desktop and web version.
4. Make sure to optimize code.
5. Make sure to update mkdocs and README.md files accordingly.
6. Take screenshots of old and new features.s 
7. Before push or commit, always ask which branch to commit.

## Architecture

**Dual-mode runtime:** The same Flutter codebase runs as macOS desktop or web. `CliDatasource` checks `kIsWeb` and either invokes the Cloudrift CLI binary via `Process.run` (desktop) or calls the Go API server via HTTP (web). Both paths return identical `ScanResult` JSON.

**Layer structure:**
- `lib/core/` — Theme (`AppColors`, `AppTheme`) and constants (49 policy definitions, 5 compliance frameworks)
- `lib/data/datasources/` — CLI execution, Hive local storage, YAML config I/O
- `lib/data/models/` — Immutable data classes with `fromJson()`/`toJson()`
- `lib/data/repositories/` — Orchestrates datasources (scan execution + persistence)
- `lib/providers/providers.dart` — All Riverpod providers in one file
- `lib/presentation/` — Screens, router, shell, shared widgets
- `server/main.go` — Go HTTP server (14 endpoints, standard library only, no external deps)

**State management (Riverpod):** `ScanNotifier` manages the scan lifecycle (idle → running → completed/error). On success, it invalidates `scanHistoryProvider`, which cascades through `latestScanResultProvider` → `resourceSummariesProvider` / `complianceScoreProvider`. All screens use `ref.watch()` to auto-rebuild.

**Navigation:** GoRouter with `ShellRoute` wrapping all screens in `AppShell` (persistent 88px sidebar). All routes use `NoTransitionPage` — no slide/fade animations. Routes: `/dashboard`, `/scan`, `/resource-builder`, `/resources`, `/resources/:resourceId`, `/policies`, `/compliance`, `/settings`.

**Storage:** Hive for scan history persistence. Desktop uses file storage, web uses IndexedDB. Demo data is seeded on first launch.

## Key Conventions

- **Colors:** Always use `AppColors` static constants, never hardcode hex values. The dark theme palette is defined in `lib/core/theme/app_colors.dart`.
- **Screens:** One folder per screen under `lib/presentation/screens/<name>/`. Screen widgets extend `ConsumerWidget` for Riverpod access.
- **Docker:** 4-stage multi-stage build (Go CLI → Go API → Flutter web → nginx:alpine). Runtime uses supervisord to manage nginx (port 80) and the Go API (port 8081). nginx reverse-proxies `/api/*` to the Go server.
- **CLI integration:** Desktop mode auto-detects the CLI binary at `~/Developer/startup/cloudrift/cloudrift`, `~/cloudrift/cloudrift`, `$GOPATH/bin/cloudrift`, or PATH. Configurable in Settings.
- **API path security:** The Go server rejects paths containing `..` to prevent directory traversal.
- **Scan service switching:** Config path auto-updates when switching S3/EC2 in the scan screen (`_switchService()` method).
