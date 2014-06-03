# Linux

Ubuntu LTS 12.04 64-bit is the recommended platform.

## Requirements

  * OS with 64-bit architecture
  * [node.js](http://nodejs.org/download/) v0.10.x
  * [npm](http://www.npmjs.org/) v1.4.x  
  * libgnome-keyring-dev `sudo apt-get install libgnome-keyring-dev` (refer to your distribution's manual on how to install packages if you are not on Debian or Ubuntu-based systems)
  * `npm config set python /usr/bin/python2 -g` to ensure that gyp uses Python 2


## Instructions

  ```sh
  git clone https://github.com/atom/atom
  cd atom
  script/build # Creates application at $TMPDIR/atom-build/Atom
  sudo script/grunt install # Installs command to /usr/local/bin/atom
  script/grunt mkdeb # Generates a .deb package at $TMPDIR/atom-build
  ```


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

### Linux build error reports in atom/atom
* Use [this search](https://github.com/atom/atom/search?q=label%3Abuild-error+label%3Alinux&type=Issues) to get a list of reports about build errors on Linux.
