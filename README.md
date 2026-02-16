# Pub Workspace Gen Action

[![CI](https://github.com/anies1212/pub-workspace-gen-action/actions/workflows/ci.yml/badge.svg)](https://github.com/anies1212/pub-workspace-gen-action/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A GitHub Action that runs `build_runner` across **Dart/Flutter [pub workspaces](https://dart.dev/tools/pub/workspaces)** in parallel, with built-in caching.

## Problem

In a pub workspace monorepo, `build_runner` must be invoked per package. Running them sequentially is slow, and the `--workspace` flag has [known limitations](https://github.com/dart-lang/build/issues/2681) (root package exclusion, conflicting file deletion).

## Solution

```
Root package  → sequential (envied, etc.)
                ↓
pkg_a  ─┐
pkg_b  ─┼→  parallel execution (configurable concurrency)
pkg_c  ─┤
pkg_d  ─┘
                ↓
           cache for next run
```

- **Parallel execution** across all workspace packages
- **Root package support** — runs first, before parallel packages
- **Built-in caching** — skips generation when source files haven't changed
- **Bash 3.2+ compatible** — works on both Ubuntu and macOS runners

## Quick Start

```yaml
steps:
  - uses: actions/checkout@v4
  - uses: subosito/flutter-action@v2
  - run: flutter pub get
  - uses: anies1212/pub-workspace-gen-action@v1
```

## Usage

### With all options

```yaml
steps:
  - uses: actions/checkout@v4
  - uses: subosito/flutter-action@v2
  - run: flutter pub get

  - uses: anies1212/pub-workspace-gen-action@v1
    with:
      working-directory: '.'
      concurrency: 4
      include-root: true
      build-runner-args: '--delete-conflicting-outputs'
      cache: true
```

### In a multi-job workflow (artifact sharing)

Generate once in a setup job, then distribute via artifacts:

```yaml
jobs:
  setup:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - run: flutter pub get

      - uses: anies1212/pub-workspace-gen-action@v1

      - name: Archive generated files
        run: |
          find lib packages \( -name '*.g.dart' -o -name '*.freezed.dart' \) \
            | tar czf /tmp/generated-files.tar.gz -T -

      - uses: actions/upload-artifact@v4
        with:
          name: generated-files
          path: /tmp/generated-files.tar.gz
          retention-days: 1

  test:
    needs: setup
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - run: flutter pub get

      - uses: actions/download-artifact@v4
        with:
          name: generated-files
      - run: tar xzf generated-files.tar.gz

      - run: flutter test
```

## Inputs

| Input | Description | Default |
|-------|-------------|---------|
| `working-directory` | Root directory of the workspace | `.` |
| `concurrency` | Max parallel `build_runner` processes (`0` = unlimited) | `0` |
| `include-root` | Run `build_runner` in the root package before parallel execution | `true` |
| `build-runner-args` | Additional arguments passed to `build_runner` | `--delete-conflicting-outputs` |
| `cache` | Enable caching of generated files | `true` |

## Outputs

| Output | Description |
|--------|-------------|
| `packages` | Comma-separated list of packages that were processed |
| `cache-hit` | `true` if the generated files cache was hit |

## How It Works

### Execution flow

```
1. Cache check (if cache: true)
   ├─ Hit  → restore generated files, skip build_runner
   └─ Miss → continue to generation

2. Root package (if include-root: true)
   └─ dart run build_runner build --delete-conflicting-outputs

3. Workspace packages (parallel)
   ├─ packages/data        ─┐
   ├─ packages/gateway      ─┤
   ├─ packages/use_case     ─┼→ batch execution (concurrency limit)
   ├─ packages/view_model   ─┤
   └─ packages/ui           ─┘

4. Results
   ├─ Logs grouped per package in Actions UI
   └─ Error annotations for failures
```

### Package discovery

The action scans `packages/*/pubspec.yaml` for `build_runner` in dependencies. Packages without `build_runner` are automatically skipped.

### Concurrency

| Value | Behavior |
|-------|----------|
| `0` (default) | All packages run simultaneously |
| `N` | Packages run in batches of N |

Batching ensures compatibility with bash 3.2+ (macOS runners use older bash by default).

### Cache key

When caching is enabled, the cache key is computed from:

- `runner.os`
- `**/pubspec.yaml` — dependency definitions
- `**/pubspec.lock` — exact dependency versions
- `**/lib/**/*.dart` — source files that trigger generation

Cached artifacts: `*.g.dart`, `*.freezed.dart`, and `lib/gen/` directories.

## Requirements

- Dart SDK or Flutter SDK installed and on `PATH`
- `flutter pub get` or `dart pub get` run before this action
- Packages located under `packages/` directory

## Examples

### Flutter monorepo with envied + freezed + riverpod

```yaml
- uses: anies1212/pub-workspace-gen-action@v1
  with:
    include-root: true  # generates env.g.dart in root
    concurrency: 0      # all packages in parallel
```

### Dart-only monorepo

```yaml
- uses: anies1212/pub-workspace-gen-action@v1
  with:
    include-root: false
    build-runner-args: '--delete-conflicting-outputs --verbose'
```

### Subdirectory workspace

```yaml
- uses: anies1212/pub-workspace-gen-action@v1
  with:
    working-directory: 'my-flutter-app'
```

### Limit concurrency on resource-constrained runners

```yaml
- uses: anies1212/pub-workspace-gen-action@v1
  with:
    concurrency: 2
```

## Runner Compatibility

| Runner | Status |
|--------|--------|
| `ubuntu-latest` | Supported |
| `macos-latest` | Supported |
| `windows-latest` | Not supported |

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

[MIT](LICENSE)
