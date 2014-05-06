# apm - Atom Package Manager [![Build Status](https://travis-ci.org/atom/apm.svg?branch=master)](https://travis-ci.org/atom/apm)

Discover and install Atom packages powered by [atom.io](https://atom.io)

## Installing

apm is bundled and installed automatically with Atom.

## Building
  * Clone the repository
  * Run `npm install`
  * Run `grunt` to compile the CoffeeScript code
  * Run `npm test` to run the specs

## Using

Run `apm help` to see all the supported commands and `apm help <command>` to
learn more about a specific command.

The common commands are `apm install <package_name>` to install a new package,
`apm featured` to see all the featured packages, and `apm publish` to publish
a package to [atom.io](https://atom.io).
