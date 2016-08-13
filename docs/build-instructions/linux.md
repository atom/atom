# Linux

Ubuntu LTS 12.04 64-bit is the recommended platform.

## Requirements

  * OS with 64-bit or 32-bit architecture
  * C++11 toolchain
  * [Git](https://git-scm.com/)
  * Node.js (4.x or above) (Can be installed via [nvm](https://github.com/creationix/nvm)).
  * [npm](https://www.npmjs.com/) v3.10.5 or above (automatically bundled with Node.js)
    * `npm -v` to check the version.
    * `npm install -g npm` to upgrade if necessary.
    * `npm config set python /usr/bin/python2 -g` to ensure that gyp uses python2.
      * You might need to run this command as `sudo`, depending on how you have set up [npm](https://github.com/joyent/node/wiki/Installing-Node.js-via-package-manager#ubuntu-mint-elementary-os).
  * development headers for [GNOME Keyring](https://wiki.gnome.org/Projects/GnomeKeyring)

### Ubuntu / Debian

* `sudo apt-get install build-essential git libgnome-keyring-dev fakeroot`
* Install Node.js and npm:
  * Install [nvm](https://github.com/creationix/nvm).
  * Run `nvm install 4` to install Node 4.x.
  * Run `npm install -g npm` to upgrade to the latest npm.
  * You may need to install a newer C++ compiler with C++11 support if script/bootstrap has errors:
    ```sh
    sudo add-apt-repository ppa:ubuntu-toolchain-r/test
    sudo apt-get update
    sudo apt-get install gcc-5 g++-5
    sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-5 80 --slave /usr/bin/g++ g++ /usr/bin/g++-5
    sudo update-alternatives --config gcc # choose gcc-5 from the list
    ```

### Fedora / CentOS / RHEL

* `sudo dnf --assumeyes install make gcc gcc-c++ glibc-devel git-core libgnome-keyring-devel rpmdevtools`
* Instructions for [Node.js](https://nodejs.org/en/download/package-manager/#enterprise-linux-and-fedora).

### Arch

* `sudo pacman -S --needed gconf base-devel git nodejs npm libgnome-keyring python2`
* `export PYTHON=/usr/bin/python2` before building Atom.

### Slackware

* `sbopkg -k -i node -i atom`

### openSUSE

* `sudo zypper install nodejs nodejs-devel make gcc gcc-c++ glibc-devel git-core libgnome-keyring-devel rpmdevtools`

## Instructions

If you have problems with permissions don't forget to prefix with `sudo`

1. Clone the Atom repository:

  ```sh
  git clone https://github.com/atom/atom
  cd atom
  ```

2. Checkout the latest Atom release:

  ```sh
  git fetch -p
  git checkout $(git describe --tags `git rev-list --tags --max-count=1`)
  ```

3. Build Atom:

  ```sh
  script/build
  ```

  This will create the atom application at `out/Atom`.

4. Install the `atom` and `apm` commands to `/usr/local/bin` by executing:

  ```sh
  sudo script/grunt install
  ```

  To use the newly installed Atom, quit and restart all running Atom instances.

5. *Optionally*, you may generate distributable packages of Atom at `out`. Currently, `.deb` and `.rpm` package types are supported, as well as a `.tar.gz` archive. To create a `.deb` package run:

  ```sh
  script/grunt mkdeb
  ```

  To create a `.rpm` package run

  ```sh
  script/grunt mkrpm
  ```

  To create a `.tar.gz` archive run

  ```sh
  script/grunt mktar
  ```

## Advanced Options

### Custom build directory

```sh
script/build --build-dir /build/atom/here
```

### Custom install directory

To install to a custom location from the standard build directory:

```sh
sudo script/grunt install --install-dir /install/atom/here
```

If you customized your build directory as described above:

```sh
sudo script/grunt install --build-dir /build/atom/here --install-dir /install/atom/here
```

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

If you get this notice when attempting to `script/build`, you either do not
have Node.js installed, or node isn't identified as Node.js on your machine.
If it's the latter, entering `sudo ln -s /usr/bin/nodejs /usr/bin/node` into
your terminal may fix the issue.

#### You can also use Alternatives

On some variants (mostly Debian based distros) it's preferable for you to use
Alternatives so that changes to the binary paths can be fixed or altered easily:

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
