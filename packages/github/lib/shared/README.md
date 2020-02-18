# Shared code

Modules in this folder are imported by both `bin/` and elsewhere in `lib/`. As a consequence, they can't use features provided by Babel transpilation or import files outside of those that do.
