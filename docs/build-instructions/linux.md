# Linux

Ubuntu LTS 12.04 64-bit is the recommended platform.

## Requirements

* OS with 64-bit or 32-bit architecture
* C++11 toolchain
* Git
* Node.js 6.x (we recommend installing it via [nvm](https://github.com/creationix/nvm))
* npm 3.10.x or later (run `npm install -g npm`)
* Ensure node-gyp uses python2 (run `npm config set python /usr/bin/python2 -g`, use `sudo` if you didn't install node via nvm)
* Development headers for [libsecret](https://wiki.gnome.org/Projects/Libsecret).

For more details, scroll down to find how to setup a specific Linux distro.

## Instructions

```sh
git clone https://github.com/atom/atom.git
cd atom
script/build
```

To also install the newly built application, use `--create-debian-package` or `--create-rpm-package` and then install the generated package via the system package manager.

### `script/build` Options

* `--compress-artifacts`: zips the generated application as `out/atom-{arch}.tar.gz`.
* `--create-debian-package`: creates a .deb package as `out/atom-{arch}.deb`
* `--create-rpm-package`: creates a .rpm package as `out/atom-{arch}.rpm`
* `--install[=dir]`: installs the application in `${dir}`; `${dir}` defaults to `/usr/local`.

### Ubuntu / Debian

* Install GNOME headers and other basic prerequisites:

  ```sh
  sudo apt-get install build-essential git libsecret-1-dev fakeroot rpm libx11-dev libxkbfile-dev
  ```

* If `script/build` exits with an error, you may need to install a newer C++ compiler with C++11:

  ```sh
  sudo add-apt-repository ppa:ubuntu-toolchain-r/test
  sudo apt-get update
  sudo apt-get install gcc-5 g++-5
  sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-5 80 --slave /usr/bin/g++ g++ /usr/bin/g++-5
  sudo update-alternatives --config gcc # choose gcc-5 from the list
  ```

### Fedora 22+

* `sudo dnf --assumeyes install make gcc gcc-c++ glibc-devel git-core libsecret-devel rpmdevtools libX11-devel libxkbfile-devel`

### Fedora 21 / CentOS / RHEL

* `sudo yum install -y make gcc gcc-c++ glibc-devel git-core libsecret-devel rpmdevtools`

### Arch

* `sudo pacman -S --needed gconf base-devel git nodejs npm libsecret python2 libx11 libxkbfile`
* `export PYTHON=/usr/bin/python2` before building Atom.

### Slackware

* `sbopkg -k -i node -i atom`

### openSUSE

* `sudo zypper install nodejs nodejs-devel make gcc gcc-c++ glibc-devel git-core libsecret-devel rpmdevtools libX11-devel libxkbfile-devel`


## Troubleshooting

### TypeError: Unable to watch path

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
  echo 32768 | sudo tee -a /proc/sys/fs/inotify/max_user_watches
  ```

See also [#2082](https://github.com/atom/atom/issues/2082).

### /usr/bin/env: node: No such file or directory

If you get this notice when attempting to run any script, you either do not have
Node.js installed, or node isn't identified as Node.js on your machine. If it's
the latter, this might be caused by installing Node.js via the distro package
manager and not nvm, so entering `sudo ln -s /usr/bin/nodejs /usr/bin/node` into
your terminal may fix the issue. On some variants (mostly Debian based distros)
you can use `update-alternatives` too:

```sh
sudo update-alternatives --install /usr/bin/node node /usr/bin/nodejs 1 --slave /usr/bin/js js /usr/bin/nodejs
```

### AttributeError: 'module' object has no attribute 'script_main'

If you get following error with a big traceback while building Atom:

  ```
  sys.exit(gyp.script_main()) AttributeError: 'module' object has no attribute 'script_main' gyp ERR!
  ```

you need to uninstall the system version of gyp.

On Fedora you would do the following:

```sh
sudo yum remove gyp
```

### Linux build error reports in atom/atom
* Use [this search](https://github.com/atom/atom/search?q=label%3Abuild-error+label%3Alinux&type=Issues)
  to get a list of reports about build errors on Linux.
