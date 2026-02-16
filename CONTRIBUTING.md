# Contributing

Thank you for your interest in contributing to Pub Workspace Gen Action!

## Getting Started

1. Fork the repository
2. Clone your fork:
   ```bash
   git clone https://github.com/<your-username>/pub-workspace-gen-action.git
   cd pub-workspace-gen-action
   ```
3. Create a feature branch:
   ```bash
   git checkout -b feat/my-feature
   ```

## Development

### Prerequisites

- Bash 3.2+ (macOS default) or 5.x+ (Linux)
- [ShellCheck](https://www.shellcheck.net/) for linting
- Dart SDK or Flutter SDK (for integration tests)

### Project structure

```
.
├── action.yml          # GitHub Action definition
├── scripts/
│   └── run.sh          # Main execution script
├── tests/
│   ├── test_run.sh     # Unit tests
│   └── fixtures/       # Test workspaces
└── .github/
    └── workflows/
        ├── ci.yml      # CI pipeline
        └── release.yml # Release automation
```

### Running tests locally

```bash
# Lint
shellcheck scripts/run.sh

# Unit tests
bash tests/test_run.sh
```

### Code style

- Follow [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- Use `shellcheck` to validate all scripts
- Keep functions focused and under 50 lines
- Add comments for non-obvious logic

## Pull Requests

1. Ensure all tests pass
2. Run `shellcheck` on any modified scripts
3. Update `README.md` if you changed inputs, outputs, or behavior
4. Update `CHANGELOG.md` under `## [Unreleased]`
5. Use descriptive commit messages:
   - `feat: add Windows runner support`
   - `fix: handle packages with spaces in path`
   - `docs: clarify concurrency behavior`
   - `test: add edge case for empty workspace`

## Reporting Issues

When reporting a bug, please include:

- Runner OS (`ubuntu-latest`, `macos-latest`, etc.)
- Dart/Flutter SDK version
- Action version
- Relevant workflow YAML
- Error output

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
