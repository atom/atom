# Linux

Ubuntu LTS 12.04 64-bit is the recommended platform.

## Requirements

  * OS with 64-bit or 32-bit architecture
  * C++ toolchain
  * git
  * [node.js](http://nodejs.org/download/) v0.10.x
  * [npm](http://www.npmjs.org/) v1.4.x (bundled with node.js)
    * `npm -v` to check the version.
    * `npm config set python /usr/bin/python2 -g` to ensure that gyp uses python2.
      * You might need to run this command as `sudo`, depending on how you have set up [npm](https://github.com/joyent/node/wiki/Installing-Node.js-via-package-manager#ubuntu-mint-elementary-os).
  * libgnome-keyring-dev

### Ubuntu / Debian
* `sudo apt-get install build-essential git libgnome-keyring-dev`
* Instructions for  [node.js](https://github.com/joyent/node/wiki/Installing-Node.js-via-package-manager#ubuntu-mint-elementary-os).

### Fedora
* `sudo yum --assumeyes install make gcc gcc-c++ glibc-devel git-core libgnome-keyring-devel dpkg`
* Instructions for [node.js](https://github.com/joyent/node/wiki/Installing-Node.js-via-package-manager#fedora).

### Arch
* `sudo pacman -S base-devel git nodejs libgnome-keyring`
* `export PYTHON=/usr/bin/python2` before building Atom.

## Instructions

If you have problems with permissions don't forget to prefix with `sudo`

  ```sh
  git clone https://github.com/atom/atom
  cd atom
  script/build # Creates application at $TMPDIR/atom-build/Atom
  sudo script/grunt install # Installs command to /usr/local/bin/atom
  script/grunt mkdeb # Generates a .deb package at $TMPDIR/atom-build, e.g. /tmp/atom-build
  ```
  
To run `atom` and `apm` from a terminal open atom's command palette `ctrl+shift+p` and run `Window: Install Shell Commands`

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
have nodejs installed, or node isn't identified as nodejs on your machine.
If it's the latter, entering `sudo ln -s /usr/bin/nodejs /usr/bin/node` into
your terminal may fix the issue.

### Linux build error reports in atom/atom
* Use [this search](https://github.com/atom/atom/search?q=label%3Abuild-error+label%3Alinux&type=Issues)
  to get a list of reports about build errors on Linux.
