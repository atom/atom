# FreeBSD

FreeBSD -RELEASE 64-bit is the recommended platform.

## Requirements

  * FreeBSD
  * `pkg install node012`
  * `pkg install npm012`
  * `pkg install libgnome-keyring`
  * `npm config set python /usr/local/bin/python2 -g` to ensure that gyp uses Python 2

## Instructions

  ```sh
  git clone https://github.com/atom/atom
  cd atom
  script/build # Creates application at $TMPDIR/atom-build/Atom
  sudo script/grunt install # Installs command to /usr/local/bin/atom
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
