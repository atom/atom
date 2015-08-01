# FreeBSD

FreeBSD -RELEASE 64-bit is the recommended platform.

## Requirements

  * FreeBSD
  * `pkg install node`
  * `pkg install npm`
  * `pkg install libgnome-keyring`
  * `npm config set python /usr/local/bin/python2 -g` to ensure that gyp uses Python 2

## Instructions

If you have problems with permissions don't forget to prefix with `sudo`

1. Clone the Atom repository:

  ```sh
  git clone https://github.com/atom/atom
  cd atom
  ```

2. Build Atom:

  ```sh
  script/build
  ```

  This will create the atom application at `$TMPDIR/atom-build/Atom`.

4. Install the `atom` command to `/usr/local/bin/atom` by executing:

  ```sh
  sudo script/grunt install
  ```

To use the newly installed Atom, quit and restart all running Atom instances.

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
