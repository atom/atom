# apm - Atom Package Manager

Discover and install Atom packages.

## Installing

apm is bundled and installed automatically with Atom.

## Building
  * Clone the repository
  * Run `npm install`
  * Run `grunt` to compile the CoffeeScript code
  * Run `grunt test` to run the specs

## Commands

```sh
apm install
```

Run this with no arguments from Atom or an Atom package to build and install
all node module dependencies.

```sh
apm install aural-coding
```

Install the [aural-coding](https://github.com/atom/aural-coding/) package
into `~/.atom/packages`.

```sh
apm available
```

List all the Atom packages available for installation

```sh
apm list
```

List all the Atom packages currently installed.  This will include the packages
that come bundled with Atom.
