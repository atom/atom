![Atom](https://cloud.githubusercontent.com/assets/72919/2874231/3af1db48-d3dd-11e3-98dc-6066f8bc766f.png)

Atom is a hackable text editor for the 21st century, built on [atom-shell](https://github.com/atom/atom-shell), and based on everything we love about our favorite editors. We designed it to be deeply customizable, but still approachable using the default configuration.

Visit [atom.io](https://atom.io) to learn more or visit the [Atom forum](https://discuss.atom.io).

Visit [issue #3684](https://github.com/atom/atom/issues/3684) to learn more
about the Atom 1.0 roadmap.

## Documentation

If you want to read about using Atom or developing packages in Atom, the [Atom Flight Manual](https://atom.io/docs/latest/) is free and available online, along with ePub, PDF, and mobi versions. You can find the source to the manual in [atom/docs](https://github.com/atom/docs).

The [API reference](https://atom.io/docs/api) for developing packages is also documented on Atom.io.


## Installing

### OS X

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

### Red Hat Linux (Fedora, CentOS, Red Hat)

Currently only a 64-bit version is available.

1. Download `atom.x86_64.rpm` from the [Atom releases page](https://github.com/atom/atom/releases/latest).
2. Run `sudo yum localinstall atom.x86_64.rpm` on the downloaded package.
3. Launch Atom using the installed `atom` command.

The Linux version does not currently automatically update so you will need to
repeat these steps to upgrade to future releases.

## Building

* [Linux](docs/build-instructions/linux.md)
* [OS X](docs/build-instructions/os-x.md)
* [FreeBSD](docs/build-instructions/freebsd.md)
* [Windows](docs/build-instructions/windows.md)
