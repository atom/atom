# Linux

Arcus supports most common distributions built on top of either apt or yum. This includes:
* Ubuntu
* Mint
* Debian
* Fedora

### Ubuntu / Debian

* `sudo apt-get install build-essential git libgnome-keyring-dev`

### Fedora

* `sudo yum --assumeyes install make gcc gcc-c++ glibc-devel git-core libgnome-keyring-devel`

## Instructions

If you have problems with permissions don't forget to prefix with `sudo`

From the cloned repository directory:

 1. Setup:

 	Run the install script with
 	```sh
	$ ./setup.sh
	```

## Troubleshooting

### /usr/bin/env: node: No such file or directory

If you get this notice when attempting to `script/build`, you either do not
have Node.js installed, or node isn't identified as Node.js on your machine.
If it's the latter, entering `sudo ln -s /usr/bin/nodejs /usr/bin/node` into
your terminal may fix the issue.

### Linux build error reports in atom/atom
Arcus is built on top of atom, if you have any issues with the install script, they may well be answered by the atom debugging page 
* Use [this search](https://github.com/atom/atom/search?q=label%3Abuild-error+label%3Alinux&type=Issues)
  to get a list of reports about build errors on Linux.
