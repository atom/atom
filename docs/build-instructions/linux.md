# Linux

Ubuntu LTS 12.04 64-bit is the recommended platform.

## Requirements

  * OS with 64-bit or 32-bit architecture
  * C++ toolchain
  * [Git](http://git-scm.com/)
  * [Node.js](http://nodejs.org/download/) v0.10.x
  * [npm](http://www.npmjs.org/) v1.4.x (bundled with Node.js)
    * `npm -v` to check the version.
    * `npm config set python /usr/bin/python2 -g` to ensure that gyp uses python2.
      * You might need to run this command as `sudo`, depending on how you have set up [npm](https://github.com/joyent/node/wiki/Installing-Node.js-via-package-manager#ubuntu-mint-elementary-os).
  * development headers for [GNOME Keyring](https://wiki.gnome.org/Projects/GnomeKeyring)

### Ubuntu / Debian
* `sudo apt-get install build-essential git libgnome-keyring-dev`
* Instructions for  [Node.js](https://github.com/joyent/node/wiki/Installing-Node.js-via-package-manager#ubuntu-mint-elementary-os).

### Fedora
* `sudo yum --assumeyes install make gcc gcc-c++ glibc-devel git-core libgnome-keyring-devel`
* Instructions for [Node.js](https://github.com/joyent/node/wiki/Installing-Node.js-via-package-manager#fedora).

### Arch
* `sudo pacman -S base-devel git nodejs libgnome-keyring`
* `export PYTHON=/usr/bin/python2` before building Atom.

## Instructions

If you have problems with permissions don't forget to prefix with `sudo`

Create the atom application at `$TMPDIR/atom-build/Atom`:

```sh
script/build
```

Install the `atom` and `apm` commands to `/usr/local/bin`:

```sh
sudo script/grunt install
```

Generate a `.deb` package at `$TMPDIR/atom-build`: (*optional*)

```sh
script/grunt mkdeb
```

Use the newly installed atom by restarting any running atom instances.

## Troubleshooting

### Exception: "TypeError: Unable to watch path"

If you get following error with a big traceback right after Atom starts:

  ```
  TypeError: Unable to watch path
  ```

you have to increase number of watched files by inotify.  For testing if
this is the reason for this error you can issue

  ```sh
  sudo sysctl fs.inotify.max_user_watches=32768
  ```

and restart Atom.  If Atom now works fine, you can make this setting permanent:

  ```sh
  echo 32768 > /proc/sys/fs/inotify/max_user_watches
  ```

See also https://github.com/atom/atom/issues/2082.

### /usr/bin/env: node: No such file or directory

If you get this notice when attempting to `script/build`, you either do not
have Node.js installed, or node isn't identified as Node.js on your machine.
If it's the latter, entering `sudo ln -s /usr/bin/nodejs /usr/bin/node` into
your terminal may fix the issue.

### Linux build error reports in atom/atom
* Use [this search](https://github.com/atom/atom/search?q=label%3Abuild-error+label%3Alinux&type=Issues)
  to get a list of reports about build errors on Linux.
