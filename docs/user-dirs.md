# User Directories by OS

Different OSes have different locations for config files, cache files
etc. Wherever Atom docs mention [AtomConfDir](#config-directory), use the
directory relevant to your OS.

### Config Directory  

- Mac OS X: `~/.atom`
- Linux: `$XDG_CONFIG_HOME/atom` (which defaults to `~/.config/atom`)
- Windows: `APPDATA + /Atom` (which defaults to
  `C:/Users/<username>/AppData/Local/Atom`)

### Cache Directory  

The build process uses `~/.atom` as a cache on all platforms.
