#include "harness_start.bash"

# The "-L" that names a subproject's library directory can be written
# with a "./" in front, with a doubled slash, or as the absolute path
# of the checkout, and as a separate word or glued to the flag.  Each
# of those still names the directory the subproject builds into, so
# each has to give the binary a dependency on the library: asking for
# the binary alone builds the library first, rather than failing to
# link or linking whatever stale copy happened to be lying around.
mkdir -p src sub/src

cat >sub/Configfile <<'EOF2'
LANGUAGES += c
LIBRARIES += libsub.so
SOURCES   += sub.c
EOF2

echo 'int sub(void) { return 3; }' > sub/src/sub.c
echo 'int sub(void); int main(void) { return sub() - 3; }' > src/main.c

for spelling in "-L./sub/lib" "-Lsub//lib" "-L sub/lib" "-L$(pwd)/sub/lib"
do
    rm -rf obj bin sub/obj sub/bin sub/lib Makefile

    cat >Configfile <<EOF2
SUBPROJECTS += sub

LANGUAGES   += c
BINARIES    += main
LINKOPTS    += $spelling
LINKOPTS    += -lsub
SOURCES     += main.c
EOF2

    $PTEST_BINARY $PCONFIGURE_ARGS
    # The dependency is written against the library's own name in the
    # tree, whatever spelling the -L used.
    grep -q "^obj/bin/main/.*/local: sub/lib/libsub.so$" Makefile

    make $MAKE_ARGS -j2 bin/main
    test -f sub/lib/libsub.so
    ./bin/main
done

exit 0
