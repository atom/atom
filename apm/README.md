# apm - Atom Package Manager

[![OS X Build Status](https://travis-ci.org/atom/apm.svg?branch=master)](https://travis-ci.org/atom/apm)
[![Windows Build Status](https://ci.appveyor.com/api/projects/status/j6ixw374a397ugkb/branch/master?svg=true)](https://ci.appveyor.com/project/Atom/apm/branch/master)
[![Dependency Status](https://david-dm.org/atom/apm.svg)](https://david-dm.org/atom/apm)

Discover and install Atom packages powered by [atom.io](https://atom.io)

You can configure apm by using the `apm config` command line option (recommended) or by manually editing the `~/.atom/.apmrc` file as per the [npm config](https://docs.npmjs.com/misc/config).

## Relation to npm

apm comes with [npm](https://github.com/npm/npm) and spawns `npm` processes to install Atom packages. The major difference is that `apm` sets multiple command line arguments to `npm` to ensure that native modules are built against Chromium's v8 headers instead of node's v8 headers.

The other major difference is that Atom packages are installed to `~/.atom/packages` instead of a local `node_modules` folder and Atom packages are published to and installed from GitHub repositories instead of [npmjs.com](https://www.npmjs.com/)

Therefore you can think of `apm` as a simple `npm` wrapper that builds on top of the many strengths of `npm` but is customized and optimized to be used for Atom packages.

## Installing

apm is bundled and installed automatically with Atom. You can run the _Atom > Install Shell Commands_ menu option to install it again if you aren't able to run it from a terminal (Mac OS X only).

## Building

  * Clone the repository
  * :penguin: Install `libgnome-keyring-dev` if you are on Linux
  * Run `npm install`; this will install the dependencies with your built-in version of Node/npm, and then rebuild them with the bundled versions.
  * Run `./bin/npm run build` to compile the CoffeeScript code (or `.\bin\npm.cmd run build` on Windows)
  * Run `./bin/npm test` to run the specs (or `.\bin\npm.cmd test` on Windows)

### Why `bin/npm` / `bin\npm.cmd`?

apm includes npm, and spawns it for various processes. It also comes with a bundled version of Node, and this script ensures that npm uses the right version of Node for things like running the tests. If you're using the same version of Node as is listed in `BUNDLED_NODE_VERSION`, you can skip using this script.

## Using

Run `apm help` to see all the supported commands and `apm help <command>` to
learn more about a specific command.

The common commands are `apm install <package_name>` to install a new package,
`apm featured` to see all the featured packages, and `apm publish` to publish
a package to [atom.io](https://atom.io).

## Behind a firewall?

If you are behind a firewall and seeing SSL errors when installing packages
you can disable strict SSL by running:

```
apm config set strict-ssl false
```

## Using a proxy?

If you are using a HTTP(S) proxy you can configure `apm` to use it by running:

```
apm config set https-proxy https://9.0.2.1:0
```

You can run `apm config get https-proxy` to verify it has been set correctly.

## Viewing configuration

You can also run `apm config list` to see all the custom config settings.
