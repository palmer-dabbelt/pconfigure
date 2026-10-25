#include "harness_start.bash"

# A LIBDIR is where libraries are written, and the "mkdir -p" in
# front of each copy is handed that directory as a bare word -- so a
# "-lib" is read by mkdir as a bundle of options and the build stops
# at "invalid option -- 'l'".  Unlike a SRCDIR a "./" in front doesn't
# rescue it, because make takes the "./" back off the library's name
# before the recipe sees it, so both spellings are refused while
# configuring rather than left to fail inside make.
mkdir -p src
echo 'int f(void) { return 0; }' > src/f.c

for dir in -lib ./-lib
do
    rm -rf Makefile obj
    cat >Configfile <<EOF
LANGUAGES  += c
LIBDIR      = $dir
LIBRARIES  += libf.so
SOURCES    += f.c
EOF

    if $PTEST_BINARY $PCONFIGURE_ARGS > configure.out 2>&1
    then
        cat configure.out
        exit 1
    fi
    cat configure.out
    grep -qF "Configfile:2 'LIBDIR = $dir'" configure.out
    grep -qF "LIBDIR names a directory starting with a '-'" configure.out
    grep -qF "'LIBDIR = lib'" configure.out
    test ! -e Makefile
done

# The same line with an ordinary name builds, so what was refused
# above was the '-' and not anything else about it.
sed -i 's@^LIBDIR .*@LIBDIR      = lib@' Configfile
$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test -f lib/libf.so
