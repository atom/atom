# apm - Atom Package Manager [![Build Status](https://travis-ci.org/atom/apm.svg?branch=master)](https://travis-ci.org/atom/apm)

Discover and install Atom packages powered by [atom.io](https://atom.io)

You can configure apm via a `~/.atom/.apmrc` file similarly to
[npm config](https://www.npmjs.org/doc/misc/npm-config.html).

## Relation to npm

apm comes with [npm](https://github.com/npm/npm) and spawns `npm` processes to
install Atom packages. The major difference is that `apm` sets multiple command
line arguments to `npm` to ensure that native modules are built against
Chromium's v8 headers instead of node's v8 headers.

The other major difference is that Atom packages are installed to
`~/.atom/packages` instead of a local `node_modules` folder and Atom packages
are published to and installed from GitHub repositories instead of
[npmjs.org](https://www.npmjs.org)

Therefore you can think of `apm` as a simple `npm` wrapper that builds on top
of the many strengths of `npm` but is customized and optimized to be used for
Atom packages.

## Installing

apm is bundled and installed automatically with Atom. You can run the
_Atom > Install Shell Commands_ menu option to install it again if you aren't
able to run it from a terminal.

## Building
  * Clone the repository
  * :penguin: Install `libgnome-keyring-dev` if you are on Linux
  * Run `npm install`
  * Run `grunt` to compile the CoffeeScript code
  * Run `npm test` to run the specs

## Using

Run `apm help` to see all the supported commands and `apm help <command>` to
learn more about a specific command.

The common commands are `apm install <package_name>` to install a new package,
`apm featured` to see all the featured packages, and `apm publish` to publish
a package to [atom.io](https://atom.io).

## Behind a firewall?

If you are behind a firewall and seeing SSL errors when installing packages
you can disable strict SSL by putting the following in your `~/.atom/.apmrc`
file:

```
strict-ssl = false
```

If you are using a proxy you can configure `apm` to use it by setting the
`https-proxy` config in your `~/.atom/.apmrc` file like so:

```
https-proxy = https://9.0.2.1:0
```

You can run `apm config get https-proxy` to verify it has been set correctly.

You can also run `apm config list` to see all the custom config settings.
