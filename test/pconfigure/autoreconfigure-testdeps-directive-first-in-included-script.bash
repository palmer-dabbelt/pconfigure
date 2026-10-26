#include "harness_start.bash"

# A "#pconfigure TESTDEPS" line can sit in a file a test pastes in with
# "#include" rather than in the test itself, and pconfigure finds it
# there (see testdeps-directive.bash).  Under AUTORECONFIGURE the test's
# own file is watched for such a line appearing (see
# autoreconfigure-testdeps-directive.bash), and an included file has to
# be watched just the same -- including while it holds no directive at
# all, since the edit that adds the first one is exactly the edit that
# has to be noticed.  Watching only the files a directive was found in
# misses it, and "make check" goes on running the test without waiting
# for the tool it now names.

# The reconfigure rule runs whatever the PATH calls "pconfigure", the
# same as "make reconfigure" does (see autoreconfigure-configfile.bash),
# so the PATH is what has to be pointed at the one under test.
export PATH="$(dirname "$PTEST_BINARY"):$PATH"

mkdir -p src test/uses-tool

cat >Configfile <<'EOC'
AUTORECONFIGURE  = true
LANGUAGES       += c
LANGUAGES       += bash
TESTEXECS       += tool
SOURCES         += tool.c
BINARIES        += uses-tool
SOURCES         += uses-tool.c
TESTSRC         += finds-tool.bash
EOC

echo 'int main(void) { return 0; }' > src/tool.c
echo 'int main(void) { return 0; }' > src/uses-tool.c

echo '#include "helper.bash"' > test/uses-tool/finds-tool.bash
echo 'true' > test/uses-tool/helper.bash

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
if grep -q '^check/uses-tool/finds-tool.bash:.*testexec/tool' Makefile
then
    exit 1
fi

# Only the included file changes: the test that includes it, and every
# Configfile, stay as they were.
sleep 1
{
    echo '#pconfigure TESTDEPS += testexec/tool'
    echo 'true'
} > test/uses-tool/helper.bash

make $MAKE_ARGS > second.log 2>&1 || { cat second.log; exit 1; }
cat second.log
grep -q "^PCONFIGURE$" second.log
grep -q '^check/uses-tool/finds-tool.bash:.*testexec/tool' Makefile
