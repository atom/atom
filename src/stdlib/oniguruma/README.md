Run `./build.sh` to install

# How do I update libonig.a

1. Download and untar the latest release from http://www.geocities.jp/kosako3/oniguruma/
2. `CCFLAGS="-m32" ./configure && make && sudo make install` # -m32 is required on OS X because node-webkit is 32bit
3. `cp /usr/local/lib/libonig.a oniguruma/src`