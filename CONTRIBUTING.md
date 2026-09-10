# Contributing to NiriShift

Thanks for helping improve NiriShift. This project uses a **PR-first** workflow: never push directly to `main`.

## Quick start

1. Fork [niri-shift](https://github.com/ind4skylivey/niri-shift) on GitHub.
2. Clone your fork and create a branch from `main`.
3. Make your changes and run `bash tests/run.sh`.
4. Open a Pull Request against `main` and fill out the PR template.

## Branch naming

| Prefix | Use for |
|--------|---------|
| `feat/` | New features, backends, settings |
| `fix/` | Bug fixes, recovery, session issues |
| `docs/` | README, CONTRIBUTING, architecture docs |

Example: `feat/sway-backend`, `fix/portal-recovery-timeout`, `docs/recovery-faq`.

## Adding a compositor backend

See [docs/BACKENDS.md](docs/BACKENDS.md) and [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the backend interface. Add `backends/your-compositor.sh` implementing the required functions, then wire it in `install.sh` and tests.

## Questions vs bugs

- **Usage questions** (install, SDDM, keybinds): [GitHub Discussions](https://github.com/ind4skylivey/niri-shift/discussions) (Q&A category).
- **Bugs and feature requests**: open an [issue](https://github.com/ind4skylivey/niri-shift/issues) using the templates.

## Code style

- Bash: match existing `core/common.sh` patterns; keep scripts portable across Arch derivatives.
- Python: follow `lib/scripts/niri-shift-keybind-monitor.py` style.
- No Omarchy dependencies; use `pacman` / `yay` for package hints only.

## License

By contributing, you agree that your contributions are licensed under **GPL-3.0-or-later**, the same license as this project. See [LICENSE](LICENSE).
