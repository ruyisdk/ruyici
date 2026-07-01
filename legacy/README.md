# Legacy build wrappers

Shell wrappers kept here for ad-hoc, out-of-recipe experimentation.
The inner build scripts for migrated drivers now live alongside their
recipes under `../recipes/<driver>/ruyi-build-*-inner`. The canonical
entry point for a migrated driver is the versioned recipe, invoked via
`ruyi admin build-package`.

Do not extend these scripts -- migrate the remaining drivers instead.
