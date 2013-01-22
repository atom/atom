#!/bin/sh
INSTALLDIR=/usr/share/atom

mkdir -p $INSTALLDIR
cp out/Default/atom $INSTALLDIR
cp -R -t $INSTALLDIR static/*
cp -t $INSTALLDIR lib/32/*
cp -R ../../src $INSTALLDIR
cp -R ../../static $INSTALLDIR
cp -R ../../vendor $INSTALLDIR
cp -R ../../bundles $INSTALLDIR
cp -R ../../themes $INSTALLDIR
mkdir -p $INSTALLDIR/native/v8_extensions
cp -t $INSTALLDIR/native/v8_extensions ../v8_extensions/*.js
coffee -c -o $INSTALLDIR/src/stdlib ../../src/stdlib/require.coffee
ln -sf $INSTALLDIR/atom /usr/local/bin/atom
