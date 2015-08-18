# Linux

Ubuntu LTS 12.04 64-bit is the recommended platform.

## Requirements

  * OS with 64-bit or 32-bit architecture
  * C++ toolchain
  * [Git](http://git-scm.com/)
  * [node.js](http://nodejs.org/download/) (0.10.x or 0.12.x) or [io.js](https://iojs.org) (1.x)
  * [npm](https://www.npmjs.com/) v1.4.x (bundled with Node.js)
    * `npm -v` to check the version.
    * `npm config set python /usr/bin/python2 -g` to ensure that gyp uses python2.
      * You might need to run this command as `sudo`, depending on how you have set up [npm](https://github.com/joyent/node/wiki/Installing-Node.js-via-package-manager#ubuntu-mint-elementary-os).
  * development headers for [GNOME Keyring](https://wiki.gnome.org/Projects/GnomeKeyring)


### Installing Node.js from source

As a fail-safe in cases where the available package manager installation method (like via APT, DNF, yum, ZYpp, *etc.*) for Node.js fails, a source installation may be necessary. This installation method requires `make` (3.81+), `gcc` (4.2+), `g++` (4.2+), `python` (2.6/2.7) and a reliable internet connection. Simply run the following from a terminal emulator (where 0.12.5 should be replaced with the latest available Node.js version which may be found [here](http://nodejs.org/dist/latest/)):
```sh
wget -c http://nodejs.org/dist/v0.12.5/node-v0.12.5.tar.gz
tar -xzf node*.tar.gz
cd node*
./configure
make
sudo make install
```

### Ubuntu / Debian

1. Install dependencies other than Node, along with cURL (which will be necessary to install Node). To do this run:

 ```sh
 sudo apt-get install build-essential curl git libgnome-keyring-dev fakeroot
 ```

2. To install [Node.js](https://github.com/joyent/node/wiki/Installing-Node.js-via-package-manager#debian-and-ubuntu-based-linux-distributions), run:

 ```sh
 curl -sL https://deb.nodesource.com/setup_0.12 | sudo bash -
 sudo apt-get install nodejs
 ```
 
 If errors are encountered at this stage or later during the actual source installation of Atom, a **source installation of Node.js** may be required.

 If this step goes without incident, then:
  * Make sure the command `node` is available after Node.js installation (some systems install it as `nodejs`).
  * Use `which node` to check if it is available.
  * Use `sudo update-alternatives --install /usr/bin/node node /usr/bin/nodejs 10` to update it.

### Fedora
```sh
sudo dnf install make gcc gcc-c++ glibc-devel git-core libgnome-keyring-devel
```

Should automatically install most dependencies on Fedora 22+, although on earlier versions of Fedora `dnf` may need to be substituted with `yum`.

After this you need to install the latest stable release of Node.js from source, to do so follow the instructions in the **Installing Node.js from source** section. 

### CentOS / RHEL

* `sudo yum --assumeyes install make gcc gcc-c++ glibc-devel git-core libgnome-keyring-devel rpmdevtools`
* Instructions for [Node.js](https://github.com/joyent/node/wiki/Installing-Node.js-via-package-manager#enterprise-linux-and-fedora).

### Arch

* `sudo pacman -S --needed gconf base-devel git nodejs npm libgnome-keyring python2`
* `export PYTHON=/usr/bin/python2` before building Atom.

### Slackware

* `sbopkg -k -i node -i atom`

### openSUSE
Run:

```sh
sudo zypper install make gcc gcc-c++ glibc-devel git-core libgnome-keyring-devel
```

To install most of the required dependencies. Note how `rpmdevtools` is not listed here, even though it was in previous versions of this file, as it is only required if you are intending on running `script/grunt mkrpm` (to make an RPM package) afterwards. However, in order to install rpmdevtools on openSUSE, you will need to install unstable versions of this software package as they are all that are [available](https://software.opensuse.org/package/rpmdevtools) for openSUSE.

After this you need to install the latest stable release of Node.js from source, to do so follow the instructions in the **Installing Node.js from source** section. 

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

  This will create the atom application at `$TMPDIR/atom-build/Atom`, it will likely take a few minutes at least. Do not get alarmed if you receive this output in the process: 
  
  `child_process: customFds option is deprecated, use stdio instead.`
  
  as it is harmless. 

4. Install the `atom` and `apm` commands to `/usr/local/bin` by executing:

  ```sh
  sudo script/grunt install
  ```

  To use the newly installed Atom, quit and restart all running Atom instances.

5. Upgrading a source installation of Atom, involves running:
  To update a source code installation first update the Atom directory (`~/atom`) by running:

  ```sh
  git checkout --
  ```

  then re-run the last two lines of the installation code:

  ```sh
  script/build
  sudo script/grunt install
  ```

6. *Optionally*, you may generate distributable packages of Atom at `$TMPDIR/atom-build`. Currently, `.deb` and `.rpm` package types are supported. To create a `.deb` package run:

  ```sh
  script/grunt mkdeb
  ```

  To create an `.rpm` package run

  ```sh
  script/grunt mkrpm
  ```

## Advanced Options

### Custom install directory

```sh
sudo script/grunt install --install-dir /install/atom/here
```

### Custom build directory

```sh
script/build --build-dir /build/atom/here
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
