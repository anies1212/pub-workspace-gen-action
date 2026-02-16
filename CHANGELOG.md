# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-02-17

### Added

- Parallel execution of `build_runner` across pub workspace packages
- Configurable concurrency limit (`concurrency` input)
- Root package support (`include-root` input)
- Built-in caching of generated files (`cache` input)
- Automatic package discovery from `packages/*/pubspec.yaml`
- Per-package log grouping in GitHub Actions UI
- Error annotations for failed packages
- `packages` output with comma-separated list of processed packages
- `cache-hit` output indicating whether generation was skipped
- Bash 3.2+ compatibility (works on macOS runners)

[1.0.0]: https://github.com/anies1212/pub-workspace-gen-action/releases/tag/v1.0.0
