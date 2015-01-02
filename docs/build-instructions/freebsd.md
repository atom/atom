# FreeBSD

A RELEASE version of FreeBSD running on amd64 is recommended.

## Prerequisites

```sh
	pkg install node
	pkg install npm
	pkg install libgnome-keyring
	pkg install bash
	ln -s /usr/local/bin/bash /bin/bash # Some dependencies foolishly assume that bash is always available at this location.
	npm config set python /usr/local/bin/python2 -g # to ensure that gyp uses Python 2
```

## Instructions

  ```sh
  git clone https://github.com/atom/atom
  cd atom
  CC=clang CXX=clang++ script/build # CC and CXX are required due to some deps foolishly assuming that everyone uses gcc, and that it's called gcc. Creates application at $TMPDIR/atom-build/Atom
  sudo script/grunt install # Installs command to /usr/local/bin/atom
  ```

## Troubleshooting
