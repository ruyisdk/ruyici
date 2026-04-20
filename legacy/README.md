# Legacy build wrappers

Shell wrappers kept here for ad-hoc, out-of-recipe experimentation
against the corresponding `*-inner` scripts (which remain at the repo
root). The canonical entry point for a package whose wrapper lives in
this directory is the matching recipe under
`../recipes/<driver>/<config>.star`, invoked via
`ruyi admin build-package`.

Do not extend these scripts — migrate the remaining drivers instead.
