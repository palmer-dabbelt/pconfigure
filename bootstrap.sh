#!/bin/bash -e

if [[ "$1" == "--verbose" ]]
then
    shift
    set -ex
fi

if [[ "$1" == "--prefix" ]]
then
    if test -f Configfiles/local
    then
        echo "Configfiles/local exists, not overwriting"
        exit 1
    fi

    cat > Configfiles/local <<EOF
PREFIX = $2
LANGUAGES += c
COMPILEOPTS += -DDEFAULT_PREFIX=\"$2\"
EOF

    shift
    shift
fi

SOURCE_PATH="$1"
BOOTSTRAP_DIR=bootstrap_bin

make distclean >& /dev/null || true
mkdir -p $BOOTSTRAP_DIR

#############################################################################
# Manually builds some of the utilities                                     #
#############################################################################
./src/version.h.proc --generate > $BOOTSTRAP_DIR/version.h

gcc --std=gnu99 `find "$SOURCE_PATH"src/pbashc.c -iname "*.c"` \
    -I$BOOTSTRAP_DIR \
    -DLANG_BASH \
    -o "$BOOTSTRAP_DIR/pbashc"

$BOOTSTRAP_DIR/pbashc "$SOURCE_PATH"src/ppkg-config.bash \
    -o $BOOTSTRAP_DIR/ppkg-config

$BOOTSTRAP_DIR/pbashc "$SOURCE_PATH"src/pllvm-config.bash \
    -o $BOOTSTRAP_DIR/pllvm-config

$BOOTSTRAP_DIR/pbashc "$SOURCE_PATH"src/pclean.bash \
    -o $BOOTSTRAP_DIR/pclean

$BOOTSTRAP_DIR/pbashc "$SOURCE_PATH"src/pgcc-config.bash \
    -o $BOOTSTRAP_DIR/pgcc-config

export PATH="$BOOTSTRAP_DIR:$PATH"

# Check for pconfigure's dependencies
talloc="$(ppkg-config --optional --have TALLOC talloc --cflags) $(ppkg-config --optional --have TALLOC talloc --libs)"
clang="$(pllvm-config --optional --have CLANG --cflags) $(pllvm-config --optional --have CLANG --libs)"

# Manually pull in included external libraries where necessary
extrasrc=""
extrahdr=""
if [[ "$(echo "$talloc" | grep HAVE_TALLOC)" == "" ]]
then
    echo "WARN: Using internal talloc"
    extrasrc="$extrasrc src/extern/extern/talloc.c"
    extrahdr="$extrahdr -Isrc/extern/extern/"
fi
if [[ "$(echo "$clang" | grep HAVE_CLANG)" == "" ]]
then
    echo "WARN: Using internal clang"
    extrasrc="$extrasrc src/extern/extern/clang.c"
fi

# Actually build pconfigure here, this is the simple part :)
gcc --std=gnu99 -Wall -Werror -Wno-trampolines -g \
    `find "$SOURCE_PATH"src/pconfigure/ -iname "*.c"` \
    `find "$SOURCE_PATH"src/libpinclude/ -iname "*.c"` \
    $extrasrc $talloc $clang \
    -Isrc/extern/ -Iinclude/ $extrahdr \
    -I$BOOTSTRAP_DIR \
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
prefix=`cat "$SOURCE_PATH"src/pconfigure/context.c | grep PREFIX | head -2 | tail -n1 | cut -d \" -f 2`

dprefix=`cat "$SOURCE_PATH"Configfiles/{local,main} | grep DEFAULT_PREFIX | head -1 | cut -d '=' -f 3`
dprefix=`echo $dprefix`

if [[ "$dprefix" != "" ]]
then
    prefix="$dprefix"
fi

echo "run 'make install' to install this to the system"
echo -e "\tby default it is installed into $prefix"

prefix=`cat "$SOURCE_PATH"Configfiles/{local,main} | grep PREFIX | head -1 | cut -d '=' -f 2`
prefix=`echo $prefix`
if [[ "$prefix" != "" ]]
then
    echo -e "\t(you have it set to install to $prefix)"
fi
