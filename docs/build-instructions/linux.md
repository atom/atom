# Linux

Ubuntu LTS 12.04 64-bit is the recommended platform.

## Requirements

  * OS with 64-bit architecture
  * [node.js](http://nodejs.org/download/) v0.10.x
  * [npm](http://www.npmjs.org/) v1.4.x  
  * libgnome-keyring-dev `sudo apt-get install libgnome-keyring-dev`
  * `npm config set python /usr/bin/python2 -g` to ensure that gyp uses Python 2

## Instructions

  ```sh
  git clone https://github.com/atom/atom
  cd atom
  script/build # Creates application at /tmp/atom-build/Atom
  sudo script/grunt install # Installs command to /usr/local/bin/atom
  script/grunt mkdeb # Generates a .deb package at /tmp/atom-build
  ```

## Troubleshooting

 * On Ubuntu 14.04 LTS when you get error message 
 

  ```sh
  /usr/local/share/atom/atom: error while loading shared libraries: libudev.so.0: cannot open shared object file: No such file or directory
  ```
You can solve this by make a symlink

x64 `sudo ln -sf /lib/x86_64-linux-gnu/libudev.so.1 /lib/x86_64-linux-gnu/libudev.so.0`
