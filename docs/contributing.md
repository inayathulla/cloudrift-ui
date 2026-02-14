# Contributing

Contributions to Cloudrift are welcome! This guide covers the process for submitting changes.

## Getting Started

1. Fork the repository on GitHub
2. Clone your fork locally
3. Set up the development environment (see [Local Setup](development/local-setup.md))
4. Create a feature branch from `main`

```bash
git checkout -b feature/my-feature main
```

## Development Workflow

1. Make your changes on the feature branch
2. Run analysis to check for issues:
   ```bash
   flutter analyze
   ```
3. Run tests:
   ```bash
   flutter test
   ```
4. Commit with a descriptive message:
   ```bash
   git commit -m "Add feature description"
   ```
5. Push and open a Pull Request against `main`

## Code Standards

### Dart / Flutter

- Follow the [Dart style guide](https://dart.dev/guides/language/effective-dart/style)
- Use `flutter_lints` rules (configured in `analysis_options.yaml`)
- Run `flutter analyze` before committing — zero issues required
- Use `AppColors` constants, never hardcode color values
- Use `ConsumerWidget` for screens that access Riverpod providers

### Go (API Server)

- Follow standard Go formatting (`gofmt`)
- Keep the API server in a single `main.go` file
- Validate all file paths to prevent directory traversal
- Return errors in `{"error": "message"}` format

### Documentation

- Documentation uses MkDocs with Material theme
- Markdown files live in `docs/`
- Preview locally with `mkdocs serve`
- Build check with `mkdocs build --strict`

## Pull Request Process

1. Ensure `flutter analyze` passes with zero issues
2. Ensure `flutter test` passes
3. Update documentation if adding new features or changing behavior
4. Keep PRs focused — one feature or fix per PR
5. Write a clear PR description explaining what and why

## Commit Convention

Use clear, descriptive commit messages:

```
Add compliance framework scoring to dashboard
Fix scan service selector config path switching
Update Docker image to include Terraform 1.7.5
```

Prefix with the action: `Add`, `Fix`, `Update`, `Remove`, `Refactor`.

## Project Structure

See [Project Structure](development/project-structure.md) for a guide to the codebase layout.

## Reporting Issues

Open an issue on GitHub with:

- Steps to reproduce
- Expected vs actual behavior
- Flutter/OS version (`flutter doctor` output)
- Screenshots if applicable

## License

By contributing, you agree that your contributions will be licensed under the project's MIT License.
