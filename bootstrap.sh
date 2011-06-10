#!/bin/sh

gcc `find src/ -iname "*.c"` -o "bin/pconfigure"
./bin/pconfigure
make
echo "run 'make install' to install this to the system"
