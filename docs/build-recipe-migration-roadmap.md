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

Other drivers are explicitly deferred:

- `gnu-plct` needs a manual rebrand / source-branch check before each
  build; not a fit for a declarative recipe yet.
- `llvm`, `box64`, `dynamorio`, `wlink`, `package-git-repo` wait for a
  follow-up roadmap once the pilots settle.

## Target layout (after pilots land)

```
ruyici/
├── ruyi-build-recipes.toml           # marker, output_dir = "out"
├── lib/
│   ├── images.star                   # port of containers/_image_tag_base.sh
│   ├── docker.star                   # docker_run(image, mounts_rw, mounts_ro, tmpfs, env, extra_docker_args, argv)
│   └── drivers.star                  # ctng_invocation(...), qemu_invocation(...)
├── recipes/
│   ├── ctng/
│   │   └── gnu-upstream.star         # host ∈ {amd64, arm64, riscv64}
│   └── qemu/
│       ├── upstream-20240128.star    # arch / flavor via ctx.var
│       └── upstream-20250908.star
└── legacy/                           # only populated at the end of the pilots
    ├── ruyi-build-qemu
    └── (gnu-upstream has no dedicated outer wrapper; ruyi-build-ctng stays)
```

`ruyi-build-ctng` and the other outer wrappers stay at the repo root
until their own drivers are migrated in a follow-up roadmap.

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
  stays because the non-pilot `gnu-plct*` configs still use it.
- Update [README.md](../README.md) to point packagers at
  `ruyi admin build-package recipes/qemu/*.star` for qemu and
  `recipes/ctng/gnu-upstream.star` for the upstream toolchain, and
  note that the remaining `ruyi-build-*` scripts are still the entry
  point for their respective drivers until they are migrated in a
  follow-up roadmap.
- Add a one-line `legacy/README.md` explaining the directory only
  exists for manual debugging of drivers whose recipe form is
  already canonical.

Depends on: M2, M3, M4.

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

- Migration of `gnu-plct`, `gnu-plct-xthead`, `gnu-plct-rv64ilp32-elf`,
  `thead-musl`, `loongarch64-none`, `llvm`, `box64`, `dynamorio`,
  `wlink`, `package-git-repo`.
- Any change to `ci/` or `.github/workflows/`. CI migration waits until
  after publishing is automated upstream.
- Any change to `*-inner` scripts, `containers/`, or config files.
- Builder-image digest pinning.
- Moving `ruyi-build-ctng` into `legacy/` (happens when the remaining
  ctng-driven recipes are migrated).

## Commit-mapping summary

| # | Size | Touches | Depends on |
|---|---|---|---|
| M0 | S | `docs/` | — |
| M1 | M | `ruyi-build-recipes.toml`, `lib/` | upstream B1–B9 |
| M2 | M | `lib/drivers.star`, `recipes/ctng/` | M1 |
| M3 | M | `lib/drivers.star`, `recipes/qemu/` | M1 |
| M4 | S | `recipes/qemu/` | M3 |
| M5 | S | `legacy/`, `README.md` | M2, M3, M4 |
