# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

MKPM is a minimalist package manager for GNU Make. It lets Makefiles share reusable modules ("packages") across projects/organizations, resolved either from a local workspace or a remote OCI-compatible registry (via ORAS). The entire package manager is implemented as pure GNU Make (`Makefile`, `bootstrap.mk`, `introspect.mk`, `plugins/*`) — there is no compiled binary and no other language runtime involved. Shell (`sh`, `curl`, `tar`, `oras`) is only invoked from within `$(shell ...)` / recipe lines for things Make itself can't do.

Requires GNU Make >= 4.3 (checked via the `grouped-target` feature) and only supports linux/darwin on amd64/arm64 — both are enforced with `$(error ...)` near the top of `Makefile`.

## Commands

Run the whole test suite from the project root:
```bash
./run-tests.sh
```
This just execs the vendored `test/bats/bin/bats` against `test/`. On macOS it switches `$MAKE` to `gmake` automatically (requires `brew install make`).

Run a single test file:
```bash
test/bats/bin/bats test/mkpm-load.bats
```

Run a single test by name (bats `-f` filters by test description):
```bash
test/bats/bin/bats -f "loads a local pkg" test/mkpm-load.bats
```

If `test/bats/bin/bats` is missing, the git submodules (bats-core + bats-support/assert/file) haven't been checked out:
```bash
git submodule update --init --recursive
```

Exercise a single make function directly (see "Introspection" below), e.g.:
```bash
make -C test/fixtures/functions expand-_mkpm_pkg_main
make expand-_mkpm_split A1=name@version
make print-_mkpm_loaded_pkgs
```

Common end-user mkpm targets (run from a directory with a `Makefile`/`mkpkg` produced by mkpm), useful when manually reproducing what a bats test does:
```bash
make mkpm-init name=<pkg>      # scaffold mkpkg + .gitignore entries
make mkpm-pack                 # tar the package per mkpkg's main/assets into <name>@<version>.tgz
make mkpm-publish               # pack + push to the configured registry
make mkpm-semver-bump ver=1.2.3 # or mkpm-semver-major / -minor / -patch
```

## Architecture

### The bootstrap/self-download pattern
Every mkpm-enabled project's `Makefile` starts with a small, copy-pasted `## mkpm bootstrap ... ## /mkpm bootstrap` block (see `bootstrap.mk`'s `mkpm_bootstrap_tpl`, and the copies in `example/Makefile`, `test/fixtures/*/Makefile`). That block:
1. Errors out if Make is too old.
2. Reads `mkpm_dir=` from `.mkpmrc.local` (falls back to `.mkpmrc`) — if set, it `include`s the real `Makefile` from that local checkout (this is how mkpm's own repo, and the `example/` and `registry/` dogfood projects, point at the in-repo copy instead of downloading).
3. Otherwise, downloads the real `Makefile` from GitHub and includes it.

`bootstrap.mk` itself is the tiny file end users actually `curl`; running `make -f bootstrap.mk install` interactively asks for a registry (GHCR or another ORAS-compliant registry), writes `.mkpmrc`, and writes the bootstrap template above as the project's `Makefile`.

### Config files
- `.mkpmrc` — committed, per-project config (`reg=`, `plugins=`, `mkpm_dir=`, `ws=`, ...).
- `.mkpmrc.local` — gitignored, personal overrides (registry credentials, a local `mkpm_dir` pointing at a dev checkout of mkpm itself, etc). Always takes precedence over `.mkpmrc` (`_mkpm_mkpmrc_get` in `introspect.mk` checks `.local` first).
- `mkpkg` — per-package metadata file (`name=`, `version=`, `main=`, `assets=`), read/written with `_mkpm_mkpkg_get` / `_mkpm_mkpkg_set`. All these files are simple `key=value` line formats parsed with `$(file <...)` + `$(filter key=%,...)`, not a real parser — see `_mkpm_sanitize_config_contents` for the whitespace-around-`=` normalization.

### Package loading (`$(call mkpm_load,<name>[@<version>])`)
Defined in `introspect.mk` (`mkpm_load` → `_mkpm_load_local_pkg` / `_mkpm_load_remote_pkg`):
- Skips loading if the package name is already in `_mkpm_loaded_pkgs` (loaded-once guarantee, tested in `mkpm-load.bats`).
- If a workspace is configured (`ws=` in `.mkpmrc`) and the package directory exists there, it's `include`d directly from the workspace (`_mkpm_load_local_pkg`) and its declared `templates` are copied into `CURDIR` if not already present. A separate `files` list is packed alongside `main`/`templates` but never copied on local load — just shipped as-is for the consumer to use in place.
- Otherwise it's treated as remote: the versioned `.tgz` is fetched via `mkpm_download` (implemented by a registry plugin) into `.mkpkgs/<name@version>/` and unpacked/`include`d from there.

### Namespacing for sub-make invocations
When Make is invoked with `-C <dir>` (detected as `$(CURDIR) != $(PWD)`), `_mkpm_target_ns` is set to the target directory's basename and prefixes help output — this is what lets a monorepo-style parent project (see `registry/monorepo`) fan out `make <target>` across several sub-packages while keeping `make help` output attributable to each one.

### Plugins
`plugins=` in `.mkpmrc` is a space-separated list. A `+name` entry is a bundled plugin fetched from this repo's `plugins/` directory (or `$(mkpm_dir)/plugins` when self-hosted); a bare `name` is a custom plugin fetched into `.mkpm_plugins/`. Plugins are the *only* supported way to implement the registry backend: `mkpm_publish` and `mkpm_download` are `$(error ...)` stubs in the core `Makefile` until a plugin (or the user) overrides them. The bundled `mkpm-oras` plugin (`plugins/mkpm-oras`) implements both on top of the `oras` CLI, auto-installing it if missing. Plugins can also inject extra help output via an optional `help_hook`.

### Introspection (`introspect.mk`)
Because the "codebase" is Make functions (`define ... endef`) rather than shell scripts or a compiled language, there's a generic set of meta-targets for testing them directly, without writing one throwaway target per function:
- `print-FOO` — FOO's fully expanded value.
- `value-FOO` — FOO's raw/unexpanded body (for eyeballing a `define` template).
- `expand-FOO` — what `$(call FOO,a1,a2,...)` produces (args passed as `A1=`..`A6=` since `$(call)` splits on commas syntactically, so this avoids comma-in-argument issues).

Almost every bats test in `test/*.bats` drives the core Makefile through these targets (or through real targets like `mkpm-pack`) against small throwaway fixture projects in `test/fixtures/`, rather than mocking anything.

### Repo-local dogfooding
`example/` and `registry/` are themselves mkpm projects that point `mkpm_dir` at this repo's own checkout instead of downloading a release — useful for manually verifying end-to-end behavior (workspace loading, monorepo namespacing, the ORAS plugin) against the current working tree. `registry/` in particular is a set of real deployment recipes (Docker, docker-compose, a Docker network, ORAS, a Postgres kit) that consume mkpm as a monorepo of sub-packages.

## Notes
- CI (`.github/workflows/test.yml`) is currently fully commented out/disabled.
- `dist/0.0.1/` exists but is currently empty — not part of the active build path.
