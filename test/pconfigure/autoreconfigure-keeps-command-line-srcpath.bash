#include "harness_start.bash"

# "--srcpath DIR" configures a build directory separate from the
# sources, the way "$DIR/configure" does for autoconf.  Under
# AUTORECONFIGURE that build directory's Makefile names the
# Configfiles back in the source directory, so editing one re-runs
# pconfigure -- and that run happens in the build directory, where
# there is no Configfile.  Unless it is told where the sources are
# again it configures an empty project, and the Makefile it writes
# builds nothing at all.

export PATH="$(dirname "$PTEST_BINARY"):$PATH"

mkdir -p source/src build

cat >source/Configfile <<'EOF'
AUTORECONFIGURE  = true
LANGUAGES       += c
BINARIES        += main
SOURCES         += main.c
EOF

echo 'int main(void) { return 0; }' > source/src/main.c

cd build
$PTEST_BINARY $PCONFIGURE_ARGS --srcpath ../source
make $MAKE_ARGS
test -x bin/main
grep -q '^bin/main:' Makefile

sleep 1
echo "# a comment" >> ../source/Configfile

make $MAKE_ARGS > second.log 2>&1
cat second.log
grep -q "^PCONFIGURE$" second.log

grep -q '^bin/main:' Makefile

# And the next edit is still noticed, which it cannot be if the rule
# went with the rest of the project.
grep -q '\$(wildcard ../source/Configfile)' Makefile

exit 0
