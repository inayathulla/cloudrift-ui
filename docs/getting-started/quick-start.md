# Quick Start

Cloudrift runs in two modes: **Docker** (web browser) or **Desktop** (native macOS app). Both provide the same UI and features.

## Docker (Recommended)

The Docker image bundles the Go CLI, API server, Flutter web app, nginx, and Terraform into a single container.

### Pull and Run

```bash
docker pull inayathulla/cloudrift-ui:latest
docker run -p 8080:80 \
  -v ~/.aws:/root/.aws:ro \
  inayathulla/cloudrift-ui:latest
```

Open [http://localhost:8080](http://localhost:8080) in your browser.

### What's Inside

The Docker image runs three processes via `supervisord`:

| Process | Port | Purpose |
|---------|------|---------|
| nginx | 80 | Serves Flutter web app, proxies `/api/*` |
| cloudrift-api | 8081 | Go REST API wrapping the CLI |
| terraform | — | Available for Resource Builder operations |

### Verify It's Working

```bash
# Health check
curl http://localhost:8080/api/health
# → {"available":true}

# CLI version
curl http://localhost:8080/api/version
# → {"version":"cloudrift v1.0.0"}
```

---

## Desktop (macOS)

The desktop app calls the Cloudrift CLI binary directly via `Process.run`.

### Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Flutter | 3.24+ | [flutter.dev](https://flutter.dev/docs/get-started/install) |
| Xcode | 15+ | Mac App Store |
| Go | 1.24+ | `brew install go` |
| Cloudrift CLI | latest | See below |

### Build the CLI

```bash
git clone https://github.com/inayathulla/cloudrift.git
cd cloudrift
go build -o cloudrift main.go
cp cloudrift ~/go/bin/cloudrift
```

### Run the Desktop App

```bash
git clone https://github.com/inayathulla/cloudrift-ui.git
cd cloudrift-ui
flutter pub get
flutter run -d macos
```

### Build a Release

```bash
flutter build macos --release
# Output: build/macos/Build/Products/Release/cloudrift_ui.app (~44 MB)
```

The app auto-detects the CLI binary at these locations (in order):

1. `~/Developer/startup/cloudrift/cloudrift`
2. `~/cloudrift/cloudrift`
3. Sibling directory to `cloudrift-ui`
4. `$GOPATH/bin/cloudrift`
5. `cloudrift` on `$PATH`

You can also set the path manually in **Settings**.

---

## First Scan

Once running (Docker or Desktop):

1. Navigate to the **Scan** screen
2. Select a service (S3 or EC2)
3. Verify the config path points to a valid `cloudrift-<service>.yml`
4. Click **Run Scan**

The scan will detect drift between your live AWS resources and your Terraform plan file, then evaluate all 49 security policies.

!!! tip "Need a sample config?"
    The Docker image includes example configs at `/etc/cloudrift/config/` and example plan files at `/etc/cloudrift/examples/`.
