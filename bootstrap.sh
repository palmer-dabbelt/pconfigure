#!/bin/sh

gcc `find src/pconfigure/ -iname "*.c"` -o "bin/pconfigure" || exit $?
./bin/pconfigure || exit $?
make || exit $?
echo "run 'make install' to install this to the system"
