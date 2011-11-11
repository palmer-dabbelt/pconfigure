#!/bin/bash

# Builds every file into pconfigure
gcc --std=gnu99 -Wall -DDEBUG_RETURNS -g `find src/pconfigure/ -iname "*.c"` -L`llvm-config --libdir` -Wl,-R`llvm-config --libdir` -I`llvm-config --includedir` `llvm-config --libs core` -lclang -o "pconfigure" || exit $?

# Runs pconfigure in order to build itself
#valgrind --leak-check=full --show-reachable=yes ./pconfigure
./pconfigure
err="$?"
if [[ "$err" != "0" ]]
then
    exit $err
fi
rm pconfigure

# Actually builds itself
make || exit $?

# Informational messages to the user
prefix=`cat src/pconfigure/defaults.h  | grep PREFIX | cut -d ' ' -f 2 | cut -d '"' -f 2`
echo "run 'make install' to install this to the system"
echo -e "\tby default it is installed into $prefix"
