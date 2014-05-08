* [Linux instructions](#linux)
* [OS X instructions](#os-x)
* [Windows instructions](#windows)

# Linux

Ubuntu LTS 12.04 64-bit is the recommended platform.

#### Requirements

  * OS with 64-bit architecture
  * [node.js](http://nodejs.org/download/) v0.10.x
  * [npm](http://www.npmjs.org/) v1.4.x  
  * libgnome-keyring-dev `sudo apt-get install libgnome-keyring-dev`
  * `npm config set python /usr/bin/python2 -g` to ensure that gyp uses Python 2

#### Instructions

  ```sh
  git clone https://github.com/atom/atom
  cd atom
  script/build # Creates application at /tmp/atom-build/Atom
  sudo script/grunt install # Installs command to /usr/local/bin/atom
  script/grunt mkdeb # Generates a .deb package at /tmp/atom-build
  ```

# OS X

#### Requirements

  * OS X 10.8 or later
  * [node.js](http://nodejs.org/download/) v0.10.x
  * Command Line Tools for [Xcode](https://developer.apple.com/xcode/downloads/) (run `xcode-select --install` to install)

#### Instructions

  ```sh
  git clone https://github.com/atom/atom
  cd atom
  script/build # Creates application at /Applications/Atom.app
  ```

# Windows

#### Requirements

  * Windows 7 or later
  * [Visual C++ 2010 SP1 Express](http://www.visualstudio.com/en-us/downloads/download-visual-studio-vs#DownloadFamilies_4)
  * [node.js - 32bit](http://nodejs.org/download/) v0.10.x
  * [Python 2.7.x](http://www.python.org/download/)
  * [GitHub for Windows](http://windows.github.com/)
  * [Git for Windows](http://git-scm.com/download/win)
    * Select the option **Use Git from the Windows Command Prompt** when installing (Git needs to be in your `PATH`)  
  * Add `C:\Python27;C:\Program Files\nodejs;C:\Users\<user>\github\atom\node_modules\`
    to your PATH

#### Instructions

  ```bat
  cd C:\Users\<user>\github
  git clone https://github.com/atom/atom/
  cd atom
  script\build
  ```
