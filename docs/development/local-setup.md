# Local Setup

## Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Flutter | 3.24+ | [flutter.dev](https://flutter.dev/docs/get-started/install) |
| Dart | 3.5+ | Included with Flutter |
| Xcode | 15+ | Mac App Store (macOS desktop builds) |
| Go | 1.24+ | `brew install go` (for CLI) |
| Cloudrift CLI | latest | Build from source (see below) |
| AWS CLI | 2.x | `brew install awscli` (for credential setup) |

## Clone and Run

```bash
# Clone the UI repository
git clone https://github.com/inayathulla/cloudrift-ui.git
cd cloudrift-ui

# Install Flutter dependencies
flutter pub get

# Run on macOS desktop
flutter run -d macos

# Or run on Chrome (web mode — needs API server)
flutter run -d chrome
```

## Build the CLI

The Flutter UI requires the Cloudrift CLI binary for desktop mode:

```bash
# Clone the CLI repository
git clone https://github.com/inayathulla/cloudrift.git
cd cloudrift

# Build the binary
go build -o cloudrift main.go

# Install to GOPATH
cp cloudrift ~/go/bin/cloudrift
```

The UI auto-detects the binary at `~/Developer/startup/cloudrift/cloudrift` or `~/go/bin/cloudrift`.

## Build Commands

```bash
# macOS desktop release
flutter build macos --release

# Web release
flutter build web --release

# Run analysis
flutter analyze

# Run tests
flutter test

# Docker build
docker build -t cloudrift-ui .
```

## IDE Setup

### VS Code

Recommended extensions:

- **Dart** — Dart language support
- **Flutter** — Flutter tools and commands

Launch configuration (`.vscode/launch.json`):

```json
{
  "configurations": [
    {
      "name": "cloudrift-ui (macOS)",
      "type": "dart",
      "request": "launch",
      "program": "lib/main.dart",
      "deviceId": "macos"
    },
    {
      "name": "cloudrift-ui (Chrome)",
      "type": "dart",
      "request": "launch",
      "program": "lib/main.dart",
      "deviceId": "chrome"
    }
  ]
}
```

### IntelliJ / Android Studio

1. Open the project folder
2. IntelliJ auto-detects the Flutter project
3. Select run device: macOS or Chrome
4. Click Run

## Environment

The app uses the system's environment variables for AWS credential resolution. No additional environment configuration is needed for local development.

For Docker development, see the [Deployment](../architecture/deployment.md) guide.
