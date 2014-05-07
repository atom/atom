![Atom](https://cloud.githubusercontent.com/assets/72919/2874231/3af1db48-d3dd-11e3-98dc-6066f8bc766f.png)

Atom is a hackable text editor for the 21st century.

Atom is open source and built on top of [atom-shell](http://github.com/atom/atom-shell).

Atom is designed to be customizable, but also usable without needing to edit a config file.

Atom is modern, approachable, and hackable to the core.

Visit [atom.io](http://atom.io) to learn more.

## Installing

Download the latest [Atom release](https://github.com/atom/atom/releases/latest).

Atom will automatically update when a new release is available.

## Building


### OS X Requirements
  * OS X 10.8 or later
  * [node.js](http://nodejs.org/download/) v0.10.x
  * Command Line Tools for [Xcode](https://developer.apple.com/xcode/downloads/) (run `xcode-select --install` to install)

  ```sh
  git clone https://github.com/atom/atom
  cd atom
  script/build # Creates application at /Applications/Atom.app
  ```

### Linux Requirements
  * Ubuntu LTS 12.04 64-bit is the recommended platform
  * OS with 64-bit architecture
  * [node.js](http://nodejs.org/download/) v0.10.x
  * [npm](http://www.npmjs.org/) v1.4.x
  * `sudo apt-get install libgnome-keyring-dev`
  * `npm config set python /usr/bin/python2 -g` to ensure that gyp uses Python 2

  ```sh
  git clone https://github.com/atom/atom
  cd atom
  script/build # Creates application at /tmp/atom-build/Atom
  sudo script/grunt install # Installs command to /usr/local/bin/atom
  script/grunt mkdeb # Generates a .deb package at /tmp/atom-build
  ```

### Windows Requirements
  * Windows 7 or later
  * [Visual C++ 2010 SP1 Express](http://www.visualstudio.com/en-us/downloads/download-visual-studio-vs#DownloadFamilies_4)
  * [node.js - 32bit](http://nodejs.org/download/) v0.10.x
  * [Python 2.7.x](http://www.python.org/download/)
  * [GitHub for Windows](http://windows.github.com/)
  * [Git for Windows](http://git-scm.com/download/win)
    * Select the option **Use Git from the Windows Command Prompt** when installing (Git needs to be in your `PATH`)
  * Clone [atom/atom](https://github.com/atom/atom/) to `C:\Users\<user>\github\atom\`
  * Add `C:\Python27;C:\Program Files\nodejs;C:\Users\<user>\github\atom\node_modules\`
    to your PATH
  * Open the Windows GitHub shell

  ```bat
  cd C:\Users\<user>\github\atom
  script\build
  ```

## Developing
Check out the [guides](https://atom.io/docs/latest) and the [API reference](https://atom.io/docs/api).
