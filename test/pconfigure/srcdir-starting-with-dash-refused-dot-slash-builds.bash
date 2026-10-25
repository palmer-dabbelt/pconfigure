#include "harness_start.bash"

# A directory may start with a '-', but every path pconfigure writes
# for a source is the SRCDIR with the name pasted on, and that path
# reaches the compile line as a bare word: "-c -src/main.c" is a
# compiler being handed an option and no input.  It used to configure
# without a word and then fail inside make, so the line is refused
# while configuring, and the "./-src" the refusal suggests is checked
# to really build, in both C and C++ since each writes its own
# compile line.
mkdir -p ./-src
echo 'int main(void) { return 0; }' > ./-src/main.c
echo 'int main(void) { return 0; }' > ./-src/other.c++

for lang in c c++
do
    rm -rf Makefile obj bin
    source=main.c
    if [ "$lang" = c++ ]
    then
        source=other.c++
    fi

    cat >Configfile <<EOF
LANGUAGES += $lang
SRCDIR     = -src

BINARIES  += main
SOURCES   += $source
EOF

    if $PTEST_BINARY $PCONFIGURE_ARGS > configure.out 2>&1
    then
        cat configure.out
        exit 1
    fi
    cat configure.out
    grep -qF "Configfile:2 'SRCDIR = -src'" configure.out
    grep -qF "SRCDIR names a directory starting with a '-'" configure.out
    grep -qF "'SRCDIR = ./-src'" configure.out
    test ! -e Makefile

    cat >Configfile <<EOF
LANGUAGES += $lang
SRCDIR     = ./-src

BINARIES  += main
SOURCES   += $source
EOF

    $PTEST_BINARY $PCONFIGURE_ARGS
    make $MAKE_ARGS
    ./bin/main
done
