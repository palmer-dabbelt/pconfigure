test "$(uname -s)" == "Darwin" && exit 0
#include "harness_start.bash"

# A shared library linked with no soname isn't relocatable: a consumer
# linked against it (with no soname to prefer) records whatever path
# "-l" happened to resolve to at link time as its NEEDED entry -- here
# that would be the literal, build-tree-relative "lib/libgreet.so" --
# rather than the library's own name.  ld.so treats any NEEDED entry
# that contains a '/' as a path to open directly rather than a name to
# search DT_RUNPATH for, so the moment the two files move anywhere
# else together, keeping the very same relative layout between them,
# the load fails: DT_RUNPATH is never even consulted.  languages/cxx.c++
# already avoids this on Mach-O with -install_name; this is the ELF
# side of the same fix, with -soname.
mkdir -p src

cat >Configfile <<EOF
LANGUAGES += c

LIBRARIES += libgreet.so
SOURCES   += greet.c

BINARIES  += hello
DEPLIBS   += greet
SOURCES   += hello.c
EOF

cat >src/greet.c <<EOF
int greet(void) { return 0; }
EOF

cat >src/hello.c <<EOF
int greet(void);
int main(void) { return greet(); }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS

##############################################################################
# The NEEDED entry names the library, not a path to it                      #
##############################################################################
readelf -d bin/hello > hello.dynamic
cat hello.dynamic
grep -q '(NEEDED).*\[libgreet\.so\]' hello.dynamic
if grep -q '(NEEDED).*\[.*/.*\]' hello.dynamic
then
    echo "a NEEDED entry contains a '/' -- it's a path, not a name" >&2
    exit 1
fi

# And the library itself carries that same name as its SONAME, which
# is what a *different* consumer, linked later and elsewhere, would
# come to depend on matching.
readelf -d lib/libgreet.so > libgreet.dynamic
cat libgreet.dynamic
grep -q '(SONAME).*\[libgreet\.so\]' libgreet.dynamic

##############################################################################
# ... which is what makes the pair relocatable together                     #
##############################################################################
# Moving bin/hello and lib/libgreet.so anywhere else, preserving only
# their relative layout (DT_RUNPATH is $ORIGIN/../lib), has to still
# work -- that's the entire point of a name instead of a path.
mkdir -p elsewhere/bin elsewhere/lib
cp bin/hello elsewhere/bin/hello
cp lib/libgreet.so elsewhere/lib/libgreet.so
(cd elsewhere/bin && ./hello)

exit 0
