#!/bin/sh

mkdir -p bin
gcc -Wall -Werror -pedantic -g `find src/pconfigure/ -iname "*.c"` -lclang -lLLVM-2.8 -L`llvm-config --libdir` -Wl,-R`llvm-config --libdir` -o "bin/pconfigure" || exit $?

./bin/pconfigure || exit $?

make || exit $?

prefix=`cat src/pconfigure/defaults.h  | grep PREFIX | cut -d ' ' -f 2 | cut -d '"' -f 2`
echo "run 'make install' to install this to the system"
echo -e "\tby default it is installed into $prefix"
