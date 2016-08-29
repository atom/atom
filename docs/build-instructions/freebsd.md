# FreeBSD

FreeBSD -RELEASE 64-bit is the recommended platform.

## Requirements

* FreeBSD
* `pkg install node`
* `pkg install npm`
* `pkg install libgnome-keyring`
* `npm config set python /usr/local/bin/python2 -g` to ensure that gyp uses Python 2

## Instructions

```sh
git clone https://github.com/atom/atom
cd atom
script/bootstrap
script/build
```
