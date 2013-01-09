## Installing Packages (Partially Implemented)

To install a package, clone it into the `~/.atom/packages` directory.
If you want to disable a package without removing it from the packages
directory, insert its name into `config.core.disabledPackages`:

config.cson:
```coffeescript
core:
  disabledPackages: [
    "fuzzy-finder",
    "tree-view"
  ]
```
