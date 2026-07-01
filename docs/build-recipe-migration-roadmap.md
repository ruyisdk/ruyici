# Build-recipe migration roadmap

> This file is a working roadmap for the packager. It is expected to be
> deleted or rewritten once the migration has settled; do not treat it as
> canonical documentation.
>
> Upstream design and implementation status live in
> `ruyi/docs/build-recipes-design.md` and
> `ruyi/docs/build-recipes-roadmap.md`. This document only covers the
> `ruyici`-side work.

## Goal

Replace the seven `ruyi-build-*` outer shell wrappers with Starlark build
recipes driven by `ruyi admin build-package`, deduplicating the shared
docker-plumbing so that each driver shrinks to a thin recipe plus a
per-driver helper in a small Starlark library. The `*-inner` scripts and
all existing config files (`toolchain-configs/`, `qemu-configs/`,
`llvm-configs/`, `box64-configs/`, `toolchain-patches/`) are not
touched — only the way the container is launched around them changes.

CI, publishing automation, and any `packages-index` changes are out of
scope for this roadmap and will be tackled after the upstream
`ruyi admin publish-package` feature lands.

## Scope of "duplication" being removed

Across the current outer scripts the repeated logic is:

- `source containers/_image_tag_base.sh` + `RUYI_BUILDER_TAG` defaulting
  (7/7 scripts)
- `ensure_dir out/` / `ensure_dir work/` boilerplate (7/7)
- `docker run --rm -ti -v out:/out -v work:/work … IMAGE inner …`
  skeleton (7/7)
- `/tmp/mem` host-side `mktemp -d` bind-mount (4/7)
- `realpath`-mount a config file into `/tmp/config.sh:ro` (qemu, llvm,
  box64)
- Optional source-tarball mount `/tmp/src.tar.xz:ro` (qemu, llvm, box64)
- Byte-identical `die` / `ensure_dir` helpers (7/7)

All of this collapses into one `docker_run(...)` helper plus per-driver
thin wrappers in a shared Starlark library.

## Pilot drivers

`gnu-upstream` and `qemu` are the pilot migrations. They cover the two
major patterns:

- `gnu-upstream` — ctng-style: a three-host matrix
  (`amd64` / `arm64` / `riscv64`) over fixed defconfigs, no source
  tarball, needs the extra `prefix/`, `src/`, `work/`,
  `toolchain-patches/` mounts.
- `qemu` — container-style: arch × flavor matrix (`both` / `system` /
  `user`), needs a mounted config file and an optional source tarball,
  uses the `/tmp/mem` tmpfs.

Since the pilot migrations landed, `gnu-ruyisdk` (previously `gnu-plct`)
has also been migrated. It follows the same ctng-style pattern as
`gnu-upstream` and reuses the `ctng_invocation()` helper unmodified.

The ctng recipes have since been refactored into a versioned layout with
a common backbone. The per-host defconfig files are replaced by a single
seed defconfig (`.defconfig.in`) per toolchain variant; the inner script
appends `CT_CANADIAN` and `CT_HOST` lines at runtime for cross builds
via the `CTNG_HOST_TRIPLET` environment variable.

Other drivers are explicitly deferred:

- `llvm`, `box64`, `dynamorio`, `wlink`, `package-git-repo` wait for a
  follow-up roadmap once the pilots settle.

The remaining ctng-driven configs (`gnu-plct-xthead`,
`gnu-plct-rv64ilp32-elf`, `thead-musl`, `loongarch64-none`) are
deprecated: upstream sources for Xuantie/T-Head have not been updated in
years and are not expected to see rebuilds. Their defconfigs remain in
`toolchain-configs/` for archival reference but no recipe migration is
planned.

## Current layout

```
ruyici/
├── ruyi-build-recipes.toml           # marker, output_dir = "out"
├── lib/
│   ├── images.star                   # port of containers/_image_tag_base.sh
│   ├── docker.star                   # docker_run(image, mounts_rw, mounts_ro, tmpfs, env, extra_docker_args, argv)
│   ├── drivers.star                  # ctng_invocation(...), qemu_invocation(...), llvm_invocation(...)
│   └── paths.star                    # repo_host_path()
├── recipes/
│   ├── ctng/
│   │   ├── ctng-toolchain.star               # common backbone for versioned ctng recipes
│   │   ├── gnu-upstream-0.20260201.0.star     # thin stub (5 lines)
│   │   ├── gnu-upstream-0.20260201.0.toml     # artifact globs
│   │   ├── gnu-upstream-0.20260201.0.defconfig.in  # seed defconfig (no host lines)
│   │   ├── gnu-ruyisdk-0.20260625.0.star      # thin stub (5 lines)
│   │   ├── gnu-ruyisdk-0.20260625.0.toml      # artifact globs
│   │   └── gnu-ruyisdk-0.20260625.0.defconfig.in  # seed defconfig (no host lines)
│   ├── qemu/
│   │   └── upstream-*.star                    # arch / flavor via ctx.var
│   └── llvm/
│       └── {upstream,plct,ruyisdk}-*.star     # host matrix
├── toolchain-configs/                        # deprecated ctng defconfigs (no active rebuilds)
│   ├── gnu-plct-xthead/
│   ├── gnu-plct-rv64ilp32-elf/
│   ├── thead-toolchain-musl.host-*.defconfig
│   └── loongarch64-unknown-none*.defconfig
└── legacy/
    └── ruyi-build-qemu
```

`ruyi-build-ctng` stays at the repo root for the deprecated configs
that still use it; it will move to `legacy/` when those configs are
removed.

## Items

Each item is sized to one reviewable commit. Dependencies are listed in
the last column.

### M0 — this roadmap

Commit this file. No code changes.

### M1 — Layout bootstrap

Adds:

- `ruyi-build-recipes.toml` at the repo root, `format = "v1"`,
  `project.name = "ruyici"`, `project.output_dir = "out"`, no
  `extra_artifact_roots` yet.
- `lib/images.star` — port of `image_tag_pkgbuilder` from
  `containers/_image_tag_base.sh`. One function,
  `pkgbuilder_image_tag(kind, host_arch) -> str`, same tag table as
  today.
- `lib/docker.star` — one function:
  ```
  docker_run(image, mounts_rw=[], mounts_ro=[], tmpfs=[], env={},
             extra_docker_args=[], argv=[]) -> [str]
  ```
  Returns the rendered `docker run …` argv. No I/O, no subprocess.
- `lib/drivers.star` — placeholder module (empty, just
  `RUYI = ruyi_plugin_rev(1)` at top) so that follow-ups only touch
  it by extension.

Acceptance:

- `ruyi admin build-package --help` (upstream B8, not in this repo)
  discovers the marker when pointed at any path inside the repo.
- No existing outer script changes behaviour.
- `ci/lint-shell-scripts.sh` still clean.

Depends on: upstream B1–B9 landing in the symlinked `ruyi/` tree.

### M2 — `gnu-upstream` recipe

Adds:

- `lib/drivers.star`: new `ctng_invocation(ctx, defconfig_path)`
  helper encapsulating the mount set from
  [ruyi-build-ctng](../ruyi-build-ctng) (`out`, `prefix`, `src`,
  `work`, `toolchain-patches`, the inner script, and the defconfig).
  Artifacts: `ctx.artifact(glob = "*-toolchain-*.tar.*")` under the
  default `output_dir`.
- `recipes/ctng/gnu-upstream.star`: loop over
  `("amd64", "arm64", "riscv64")` and register one build per host via
  `RUYI.build.schedule_build(fn, name = host)`, each pointing at
  `toolchain-configs/gnu-upstream/host-<host>.defconfig`.
- Honours `RUYI_BUILDER_TAG`-style override via
  `ctx.var("builder_tag", default = pkgbuilder_image_tag("unified", "amd64"))`.

Acceptance:

- `ruyi admin build-package recipes/ctng/gnu-upstream.star --dry-run`
  prints three `docker run …` argvs. Each argv, after sorting `-v`
  entries, matches the argv produced by
  `./ruyi-build-ctng ./toolchain-configs/gnu-upstream/host-<host>.defconfig`
  run under `set -x`, modulo the `/tmp/mem` tmpfs difference (see
  Notes).
- `ruyi admin build-package recipes/ctng/gnu-upstream.star -n amd64`
  successfully builds on an amd64 developer workstation; artifacts
  land in `out/`; `_ruyi-build-report.*.toml` is written.

Depends on: M1.

### M3 — `qemu/upstream-20250908` recipe

Adds:

- `lib/drivers.star`: new
  `qemu_invocation(ctx, config_path, arch, flavor, src_tarball = None)`
  helper modelling [ruyi-build-qemu](../ruyi-build-qemu). Uses
  `docker_run(tmpfs = ["/tmp/mem"])` — a behavioural change from the
  current `mktemp -d` + bind-mount; see Notes.
  Artifacts are flavor-conditional:
  - `both` or `system` → `qemu-system-<arch>.*.tar.zst`
  - `both` or `user`   → `qemu-user-<arch>.*.tar.zst`
- `recipes/qemu/upstream-20250908.star`: reads `arch` (default
  `amd64`), `flavor` (default `both`) and `src` (path to
  `qemu-10.0.4.tar.xz`, required) via `ctx.var`, registers a single
  build pointing at `qemu-configs/upstream-20250908.sh`.

Acceptance:

- `ruyi admin build-package recipes/qemu/upstream-20250908.star --dry-run -v src=./qemu-10.0.4.tar.xz`
  prints an argv equivalent to
  `./ruyi-build-qemu ./qemu-configs/upstream-20250908.sh amd64 both ./qemu-10.0.4.tar.xz`
  under `set -x`, modulo the tmpfs difference.
- End-to-end run produces the expected system + user tarballs in `out/`.

Depends on: M1.

### M4 — `qemu/upstream-20240128` recipe

Same as M3 but pointed at `qemu-configs/upstream-20240128.sh`. Trivial
once M3 lands; split out so M3 can be reviewed on its own.

Depends on: M3.

### M5 — Retire the migrated legacy wrappers

- `git mv ruyi-build-qemu legacy/ruyi-build-qemu`. `ruyi-build-ctng`
  stays because the remaining non-migrated `gnu-plct-xthead`,
  `gnu-plct-rv64ilp32-elf`, `thead-musl`, and `loongarch64-none`
  configs still use it.
- Update [README.md](../README.md) to point packagers at
  `ruyi admin build-package recipes/qemu/*.star` for qemu and
  `recipes/ctng/gnu-upstream.star` / `recipes/ctng/gnu-ruyisdk.star`
  for the upstream and ruyisdk toolchains, and note that the
  remaining `ruyi-build-*` scripts are still the entry point for
  their respective drivers until they are migrated in a follow-up
  roadmap.
- Add a one-line `legacy/README.md` explaining the directory only
  exists for manual debugging of drivers whose recipe form is
  already canonical.

Depends on: M2, M3, M4.

### M6 — Versioned ctng recipe layout and deduplication

Adds:

- `ruyi-build-ctng-inner`: reads optional `CTNG_HOST_TRIPLET` env var.
  When set, appends `CT_CANADIAN=y` and `CT_HOST="<triplet>"` to the
  seed defconfig before invoking ct-ng. Backward-compatible when unset.
- `lib/drivers.star` (`ctng_invocation`): new `host_triplet` parameter
  forwarded as the `CTNG_HOST_TRIPLET` env var.
- `recipes/ctng/ctng-toolchain.star`: common backbone. By convention
  loads ``<name>.toml`` for artifact globs, mounts
  ``<name>.defconfig.in`` as the seed defconfig, and registers one
  scheduled build per host via the caller's RUYI object.

Effect: per-variant defconfig surface shrinks from 3 host-specific
files to 1 seed file. Per-host differences (2 lines) are handled at
runtime by the inner script.

Depends on: M2.

### M7 — `gnu-upstream` versioned recipe

Adds:

- `recipes/ctng/gnu-upstream-0.20260201.0.star` — thin stub (5 lines).
- `recipes/ctng/gnu-upstream-0.20260201.0.toml` — artifact globs per host.
- `recipes/ctng/gnu-upstream-0.20260201.0.defconfig.in` — seed defconfig
  (amd64 variant with host-specific lines omitted).

Removes:

- `recipes/ctng/gnu-upstream.star` — replaced by versioned recipe.
- `toolchain-configs/gnu-upstream/` — 3 per-host defconfigs no longer
  needed.

Acceptance: `ruyi admin build-package recipes/ctng/gnu-upstream-0.20260201.0.star --dry-run`
prints three docker argvs matching the old recipe's argv, with:
- One seed defconfig mount (not three per-host files)
- `-e CTNG_HOST_TRIPLET=aarch64-linux-gnu` on arm64 build
- `-e CTNG_HOST_TRIPLET=riscv64-linux-gnu` on riscv64 build

Depends on: M6.

### M8 — `gnu-ruyisdk` versioned recipe

Adds:

- `recipes/ctng/gnu-ruyisdk-0.20260625.0.star` — thin stub (5 lines).
- `recipes/ctng/gnu-ruyisdk-0.20260625.0.toml` — artifact globs per host.
- `recipes/ctng/gnu-ruyisdk-0.20260625.0.defconfig.in` — seed defconfig.

Removes:

- `recipes/ctng/gnu-ruyisdk.star` — replaced by versioned recipe.
- `toolchain-configs/gnu-ruyisdk/` — 3 per-host defconfigs no longer
  needed.

Depends on: M6.

### M9 — Deprecate remaining ctng configs

The remaining ctng-driven configs (`gnu-plct-xthead`,
`gnu-plct-rv64ilp32-elf`, `thead-toolchain-musl`, `loongarch64-*`)
are deprecated. Xuantie/T-Head upstream sources have not been updated
in over 2 years; these are not expected to see rebuilds. The
`gnu-plct` branding is retired (already renamed to `gnu-ruyisdk` in
the package index).

No recipe migration is planned for these configs. The defconfigs
remain in `toolchain-configs/` for archival reference only.
`ruyi-build-ctng` stays at the repo root for any manual rebuilds.

## Notes / known deltas from the current scripts

- **`/tmp/mem` becomes a real `--tmpfs`.** The current outer scripts
  bind-mount a host `mktemp -d`. With `docker_run(tmpfs=["/tmp/mem"])`
  the container sees an actual tmpfs. This is the intended direction
  and matches the upstream design example, but the pilot runs should
  confirm that nothing in `ruyi-build-qemu-inner` (or any other inner
  script touching `/tmp/mem`) assumes on-disk semantics.
- **`RUYI_BUILDER_TAG` env override** becomes `-v builder_tag=...`
  on the `ruyi admin build-package` command line.
- **`--user root` dynamorio workaround** is not on the pilot path; it
  will be carried over via a `extra_docker_args` parameter when that
  driver is migrated.
- **`wlink`'s host-side `git describe`** is deliberately deferred —
  the cleanest fix is to move the version-derivation step into the
  inner script (the `rust-musl` image already has git), but that is a
  separate change.

## Deferred (explicitly not on this roadmap)

- Migration of `gnu-plct-xthead`, `gnu-plct-rv64ilp32-elf`,
  `thead-musl`, `loongarch64-none` — deprecated, no active rebuild
  expected; defconfigs remain for archival reference.
- Migration of `llvm`, `box64`, `dynamorio`, `wlink`,
  `package-git-repo` — wait for follow-up roadmap.
- Any change to `ci/` or `.github/workflows/`. CI migration waits until
  after publishing is automated upstream.
- Any change to `containers/`.
- Builder-image digest pinning.
- Moving `ruyi-build-ctng` into `legacy/` (happens when the remaining
  deprecated ctng configs are removed).

## Commit-mapping summary

| # | Size | Touches | Depends on |
|---|---|---|---|
| M0 | S | `docs/` | — |
| M1 | M | `ruyi-build-recipes.toml`, `lib/` | upstream B1–B9 |
| M2 | M | `lib/drivers.star`, `recipes/ctng/` | M1 |
| M3 | M | `lib/drivers.star`, `recipes/qemu/` | M1 |
| M4 | S | `recipes/qemu/` | M3 |
| M5 | S | `legacy/`, `README.md` | M2, M3, M4 |
| M6 | M | `ruyi-build-ctng-inner`, `lib/drivers.star`, `recipes/ctng/ctng-toolchain.star` | M2 |
| M7 | M | `recipes/ctng/gnu-upstream-0.20260201.0.*` (+ removal of old) | M6 |
| M8 | M | `recipes/ctng/gnu-ruyisdk-0.20260625.0.*` (+ removal of old) | M6 |
| M9 | S | `docs/` (deprecation note) | M7, M8 |
