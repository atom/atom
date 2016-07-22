![Atom](https://cloud.githubusercontent.com/assets/72919/2874231/3af1db48-d3dd-11e3-98dc-6066f8bc766f.png)

[![macOS Build Status](https://circleci.com/gh/atom/atom.svg?style=svg)](https://circleci.com/gh/atom/atom) [![Windows Build Status](https://ci.appveyor.com/api/projects/status/1tkktwh654w07eim?svg=true)](https://ci.appveyor.com/project/Atom/atom)
[![Dependency Status](https://david-dm.org/atom/atom.svg)](https://david-dm.org/atom/atom)
[![Join the Atom Community on Slack](http://atom-slack.herokuapp.com/badge.svg)](http://atom-slack.herokuapp.com/)

Atom is a hackable text editor for the 21st century, built on [Electron](https://github.com/atom/electron), and based on everything we love about our favorite editors. We designed it to be deeply customizable, but still approachable using the default configuration.

Visit [atom.io](https://atom.io) to learn more or visit the [Atom forum](https://discuss.atom.io).

Follow [@AtomEditor](https://twitter.com/atomeditor) on Twitter for important
announcements.

This project adheres to the Contributor Covenant [code of conduct](CODE_OF_CONDUCT.md).
By participating, you are expected to uphold this code. Please report unacceptable behavior to atom@github.com.

## Documentation

If you want to read about using Atom or developing packages in Atom, the [Atom Flight Manual](http://flight-manual.atom.io) is free and available online. You can find the source to the manual in [atom/flight-manual.atom.io](https://github.com/atom/flight-manual.atom.io).

The [API reference](https://atom.io/docs/api) for developing packages is also documented on Atom.io.

## Installing

### Prerequisites
- [Git](https://git-scm.com/)

### macOS

Download the latest [Atom release](https://github.com/atom/atom/releases/latest).

Atom will automatically update when a new release is available.

### Windows

Download the latest [AtomSetup.exe installer](https://github.com/atom/atom/releases/latest).

Atom will automatically update when a new release is available.

You can also download an `atom-windows.zip` file from the [releases page](https://github.com/atom/atom/releases/latest).
The `.zip` version will not automatically update.

Using [chocolatey](https://chocolatey.org/)? Run `cinst Atom` to install
the latest version of Atom.

### Debian Linux (Ubuntu)

Currently only a 64-bit version is available.

1. Download `atom-amd64.deb` from the [Atom releases page](https://github.com/atom/atom/releases/latest).
2. Run `sudo dpkg --install atom-amd64.deb` on the downloaded package.
3. Launch Atom using the installed `atom` command.

The Linux version does not currently automatically update so you will need to
repeat these steps to upgrade to future releases.

### Red Hat Linux (Fedora 21 and under, CentOS, Red Hat)

Currently only a 64-bit version is available.

1. Download `atom.x86_64.rpm` from the [Atom releases page](https://github.com/atom/atom/releases/latest).
2. Run `sudo yum localinstall atom.x86_64.rpm` on the downloaded package.
3. Launch Atom using the installed `atom` command.

The Linux version does not currently automatically update so you will need to
repeat these steps to upgrade to future releases.

### Fedora 22+

Currently only a 64-bit version is available.

1. Download `atom.x86_64.rpm` from the [Atom releases page](https://github.com/atom/atom/releases/latest).
2. Run `sudo dnf install ./atom.x86_64.rpm` on the downloaded package.
3. Launch Atom using the installed `atom` command.

The Linux version does not currently automatically update so you will need to
repeat these steps to upgrade to future releases.

### Archive extraction

An archive is available for people who don't want to install `atom` as root.

This version enables you to install multiple Atom versions in parallel. It has been built on Ubuntu 64-bit,
but should be compatible with other Linux distributions.

1. Install dependencies (on Ubuntu): `sudo apt install git gconf2 gconf-service libgtk2.0-0 libudev1 libgcrypt20
libnotify4 libxtst6 libnss3 python gvfs-bin xdg-utils libcap2`
2. Download `atom-amd64.tar.gz` from the [Atom releases page](https://github.com/atom/atom/releases/latest).
3. Run `tar xf atom-amd64.tar.gz` in the directory where you want to extract the Atom folder.
4. Launch Atom using the installed `atom` command from the newly extracted directory.

The Linux version does not currently automatically update so you will need to
repeat these steps to upgrade to future releases.

## Building

* [Linux](docs/build-instructions/linux.md)
* [macOS](docs/build-instructions/macos.md)
* [FreeBSD](docs/build-instructions/freebsd.md)
* [Windows](docs/build-instructions/windows.md)
