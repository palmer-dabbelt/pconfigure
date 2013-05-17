#!/bin/bash

if [[ "$1" == "--verbose" ]]
then
    shift
    set -ex
fi

SOURCE_PATH="$1"
BOOTSTRAP_DIR=bootstrap_bin

make distclean >& /dev/null || true
mkdir -p $BOOTSTRAP_DIR

#############################################################################
# Manually builds some of the utilities                                     #
#############################################################################
gcc --std=gnu99 `find "$SOURCE_PATH"src/pbashc.c -iname "*.c"` \
    -o "$BOOTSTRAP_DIR/pbashc"

$BOOTSTRAP_DIR/pbashc "$SOURCE_PATH"src/ppkg-config.bash \
    -o $BOOTSTRAP_DIR/ppkg-config

$BOOTSTRAP_DIR/pbashc "$SOURCE_PATH"src/pllvm-config.bash \
    -o $BOOTSTRAP_DIR/pllvm-config

$BOOTSTRAP_DIR/pbashc "$SOURCE_PATH"src/pclean.bash \
    -o $BOOTSTRAP_DIR/pclean

export PATH="$BOOTSTRAP_DIR:$PATH"

# Check for pconfigure's dependencies
talloc="$(ppkg-config --optional --have TALLOC talloc --cflags) $(ppkg-config --optional --have TALLOC talloc --libs)"
clang="$(pllvm-config --optional --have CLANG --cflags) $(pllvm-config --optional --have CLANG --libs)"

# Manually pull in included external libraries where necessary
extrasrc=""
if [[ "$(echo "$talloc" | grep HAVE_TALLOC)" == "" ]]
then
    echo "WARN: Using internal talloc"
    extrasrc="$extrasrc src/extern/talloc.c"
fi
if [[ "$(echo "$clang" | grep HAVE_CLANG)" == "" ]]
then
    echo "WARN: Using internal clang"
    extrasrc="$extrasrc src/extern/clang.c"
fi

# Actually build pconfigure here, this is the simple part :)
gcc --std=gnu99 -Wall -Werror -Wno-trampolines -g \
    `find "$SOURCE_PATH"src/pconfigure/ -iname "*.c"` \
    $extrasrc $talloc $clang \
    -DPCONFIGURE_VERSION=\"bootstrap\" \
    -Isrc/extern/ \
    -o "$BOOTSTRAP_DIR/pconfigure" || exit $?

# Runs pconfigure in order to build itself
if [[ "$SOURCE_PATH" != "" ]]
then
    sp="--sourcepath $SOURCE_PATH"
else
    sp=""
fi
env PATH="$BOOTSTRAP_DIR:$PATH" $BOOTSTRAP_DIR/pconfigure $sp
err="$?"
if [[ "$err" != "0" ]]
then
    exit $err
fi

# Actually builds itself
make || exit $?
make all_install || exit $?

# Cleans up from the bootstrap process
rm -rf $BOOTSTRAP_DIR

# Informational messages to the user
prefix=`cat "$SOURCE_PATH"src/pconfigure/context.c | grep prefix | head -1 | cut -d \" -f 2`
echo "run 'make install' to install this to the system"
echo -e "\tby default it is installed into $prefix"

prefix=`cat "$SOURCE_PATH"Configfiles/{local,main} | grep PREFIX | head | cut -d '=' -f 2`
prefix=`echo $prefix`
if [[ "$prefix" != "" ]]
then
    echo -e "\t(you have it set to install to $prefix)"
fi
