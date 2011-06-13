#!/bin/sh

gcc `find src/pconfigure/ -iname "*.c"` -o "bin/pconfigure" || exit $?
./bin/pconfigure || exit $?
make || exit $?
prefix=`cat src/pconfigure/defaults.h  | grep PREFIX | cut -d ' ' -f 2 | cut -d '"' -f 2`
echo "run 'make install' to install this to the system"
echo -e "\tby default it is installed into $prefix"
