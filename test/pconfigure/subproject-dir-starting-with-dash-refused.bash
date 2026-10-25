#include "harness_start.bash"

# A subproject's paths are written from the top as its directory
# followed by the rest, so a subproject checked out as "-dep" has every
# path start with "-dep/" -- and the first recipe to pass one as a bare
# word, the "mkdir -p" in front of each compile, read it as a bundle
# of options and stopped with "mkdir: invalid option -- 'd'".  The
# line is refused while configuring instead.  "./-dep" is no way
# around it, because the directory is normalized before any path is
# built from it, so that spelling is refused as well.
mkdir -p ./-dep/src
echo 'int main(void) { return 0; }' > ./-dep/src/main.c

cat >./-dep/Configfile <<EOF
LANGUAGES += c
BINARIES  += depmain
SOURCES   += main.c
EOF

for dir in -dep ./-dep
do
    rm -rf Makefile obj
    cat >Configfile <<EOF
LANGUAGES   += c
SUBPROJECTS += $dir
EOF

    if $PTEST_BINARY $PCONFIGURE_ARGS > configure.out 2>&1
    then
        cat configure.out
        exit 1
    fi
    cat configure.out
    grep -qF "Configfile:2 'SUBPROJECTS += $dir'" configure.out
    grep -qF "SUBPROJECTS names a directory starting with a '-'" configure.out
    test ! -e Makefile
done

# The same tree under an ordinary name builds, so what was refused
# above was the '-' and not anything about the tree.
mv ./-dep dep
sed -i 's@^SUBPROJECTS .*@SUBPROJECTS += dep@' Configfile
$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
./dep/bin/depmain
