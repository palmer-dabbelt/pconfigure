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

if [[ "$CC" == "" ]]
then
  CC="gcc"
fi
if [[ "$CXX" == "" ]]
then
  CXX="g++"
fi

#############################################################################
# Manually builds some of the utilities                                     #
#############################################################################
"$SOURCE_PATH"src/version.h.proc --generate > $BOOTSTRAP_DIR/version.h

$CC --std=gnu99 \
    `find "$SOURCE_PATH"src/pbashc.c -iname "*.c"` \
    `find "$SOURCE_PATH"src/libpinclude/ -iname "*.c"` \
    -I$BOOTSTRAP_DIR -I"$SOURCE_PATH"src/libpinclude \
    -DLANG_BASH \
    -o "$BOOTSTRAP_DIR/pbashc"

$BOOTSTRAP_DIR/pbashc "$SOURCE_PATH"src/phc.bash \
    -o $BOOTSTRAP_DIR/phc

$BOOTSTRAP_DIR/pbashc "$SOURCE_PATH"src/ppkg-config.bash \
    -o $BOOTSTRAP_DIR/ppkg-config

$BOOTSTRAP_DIR/pbashc "$SOURCE_PATH"src/pllvm-config.bash \
    -o $BOOTSTRAP_DIR/pllvm-config

$BOOTSTRAP_DIR/pbashc "$SOURCE_PATH"src/pclean.bash \
    -o $BOOTSTRAP_DIR/pclean

$BOOTSTRAP_DIR/pbashc "$SOURCE_PATH"src/pgcc-config.bash \
    -o $BOOTSTRAP_DIR/pgcc-config

export PATH="$BOOTSTRAP_DIR:$PATH"

# Actually build pconfigure here, this is the simple part :)
$CXX -x c++ --std=c++0x -Wall -Werror -g $CFLAGS \
    `find "$SOURCE_PATH"src/libpconfigure/ -iname "*.c++"` \
    `find "$SOURCE_PATH"src/libmakefile/ -iname "*.c++"` \
    `find "$SOURCE_PATH"src/libpinclude/ -iname "*.c"` \
    `find "$SOURCE_PATH"src/libpinclude/ -iname "*.c++"` \
    "$SOURCE_PATH"src/pconfigure++.c++ \
    -I"$SOURCE_PATH"src/libpinclude -I"$SOURCE_PATH"src \
    -I$BOOTSTRAP_DIR \
    -D__PCONFIGURE__LIBEXEC=\"$BOOTSTRAP_DIR/../libexec\" \
    -o "$BOOTSTRAP_DIR/pconfigure" || exit $?

# Runs pconfigure in order to build itself
if [[ "$SOURCE_PATH" != "" ]]
then
    sp="--srcpath $SOURCE_PATH"
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
