#!/bin/bash

# Builds every file into pconfigure
gcc --std=gnu99 -Wall -Werror -Wno-trampolines -g `find src/pconfigure/ -iname "*.c"` -L`llvm-config --libdir` -Wl,-R`llvm-config --libdir` -I`llvm-config --includedir` `llvm-config --libs core` -lclang `pkg-config talloc --libs` -o "pconfigure" || exit $?

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
make bin/pbashc
export PATH="./bin:$PATH"
make || exit $?

# Informational messages to the user
prefix=`cat src/pconfigure/context.c | grep prefix | head -1 | cut -d \" -f 2`
echo "run 'make install' to install this to the system"
echo -e "\tby default it is installed into $prefix"

prefix=`cat Configfile* | grep PREFIX | head | cut -d '=' -f 2`
prefix=`echo $prefix`
if [[ "$prefix" != "" ]]
then
    echo -e "\t(you have it set to install to $prefix)"
fi