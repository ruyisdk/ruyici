# CI scripts of RuyiSDK

![GitHub License](https://img.shields.io/github/license/ruyisdk/ruyici)

For now, a collection of scripts used to produce official RuyiSDK builds for
various packages. Eventually this will become the "source package repository"
of the official RuyiSDK software repository.

## Building packages

Packages whose build has been migrated to the
[`ruyi admin build-package`](./ruyi/docs/build-recipes-design.md) workflow
are driven by recipes under [`recipes/`](./recipes/). Each recipe is a
small Starlark file that declares one or more scheduled builds:

```
ruyi admin build-package ./recipes/ctng/gnu-upstream.star
ruyi admin build-package ./recipes/qemu/upstream-20250908.star \
    -v src=/path/to/qemu-10.0.4.tar.xz
```

`--dry-run` prints the rendered `docker run` argv without executing
anything. `-n <name>` restricts execution to one scheduled build
(e.g. `-n amd64` for the gnu-upstream matrix). See
[`docs/build-recipe-migration-roadmap.md`](./docs/build-recipe-migration-roadmap.md)
for the per-driver migration status.

Drivers that have not been migrated yet are still invoked via the
`ruyi-build-*` shell wrappers at the repo root; see their individual
usage lines. Wrappers that have been superseded by a recipe have been
moved under [`legacy/`](./legacy/) and remain only for manual
debugging.

## Contributing

We welcome contributions to RuyiSDK! Please see our [contribution guidelines](./CONTRIBUTING.md) ([中文](./CONTRIBUTING.zh.md)) for details on how to get started.

## License

Copyright &copy; Institute of Software, Chinese Academy of Sciences (ISCAS).
All rights reserved.

The code content of this repository is licensed under the [Apache 2.0 license](./LICENSE-Apache.txt).

All trademarks referenced herein are property of their respective holders.
