#!/bin/bash -e

# An option's argument can be given in the next word or after an '=',
# because both spellings are common enough that guessing which one a
# script takes is a coin flip, and the wrong guess fails in a way that
# says nothing about the option.  Reading them in a loop also drops the
# rule that the options had to appear in the order they happen to be
# written here, which nothing ever said out loud.
while [[ "$1" == --* ]]
do
    option="${1%%=*}"

    # --verbose is the only option that takes no argument, so it is the
    # only one that must not eat the word after it.
    if [[ "$option" == "--verbose" ]]
    then
        shift
        set -ex
        continue
    fi

    case "$1" in
    *=*)
        argument="${1#*=}"
        shift
        ;;
    *)
        argument="$2"
        shift
        shift
        ;;
    esac

    case "$option" in
    --prefix)
        if test -f Configfiles/local
        then
            echo "Configfiles/local exists, not overwriting"
            exit 1
        fi

        cat > Configfiles/local <<EOF
PREFIX = $argument
LANGUAGES += c
EOF
        ;;
    --cc)
        CC="$argument"
        ;;
    --cxx)
        CXX="$argument"
        ;;
    --cflags)
        CFLAGS="$argument"
        ;;
    --cxxflags)
        CXXFLAGS="$argument"
        ;;
    *)
        # An option this script doesn't know used to fall through to
        # SOURCE_PATH, so a typo quietly became the directory the
        # sources were read from and came back as a path with the
        # option glued onto the front of it.
        echo "$0: unrecognized option '$option'" >&2
        echo "  the options are --verbose, --prefix, --cc, --cxx, --cflags and --cxxflags" >&2
        echo "  an argument goes in the next word or after an '=': --prefix /usr/local" >&2
        exit 1
        ;;
    esac
done

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

export CC
export CXX

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
$CXX -x c++ --std=c++0x -Wall -Werror -g $CXXFLAGS \
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

# Regenerate the Makefile with the freshly-built pconfigure.  pconfigure now
# bakes the absolute path of its own helper tools (pbashc, phc, ptest, ...)
# into the Makefile, resolved relative to the running pconfigure binary.  The
# Makefile generated above points those at $BOOTSTRAP_DIR, which is about to be
# removed, so rewrite it to point at the just-built bin/ instead.
env PATH="$BOOTSTRAP_DIR:$PATH" ./bin/pconfigure $sp || exit $?

# Cleans up from the bootstrap process
rm -rf $BOOTSTRAP_DIR

# Informational messages to the user
prefix=`grep 'prefix("' "$SOURCE_PATH"src/libpconfigure/context.c++ | head -1 | cut -d '"' -f 2`

echo "run 'make install' to install this to the system"
echo -e "\tby default it is installed into $prefix"

prefix=`cat "$SOURCE_PATH"Configfiles/{local,main} | grep PREFIX | head -1 | cut -d '=' -f 2`
prefix=`echo $prefix`
if [[ "$prefix" != "" ]]
then
    echo -e "\t(you have it set to install to $prefix)"
fi
