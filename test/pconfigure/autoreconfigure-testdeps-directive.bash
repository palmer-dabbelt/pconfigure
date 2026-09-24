#include "harness_start.bash"

# AUTORECONFIGURE watches every Configfile* name a project could have (see
# autoreconfigure-configfile.bash) and every CONFIG_DEPS a Configfile wrote
# (see config-deps.bash) -- but a "#pconfigure TESTDEPS" line lives in a
# test's own source, read by process_directives() rather than by anything
# that walks Configfiles, and nothing adds that source to the list
# reconfigure_on() writes into Makefile.pconfigure's own prerequisites.
#
# So the one file a TESTDEPS directive can be written in is also the one
# AUTORECONFIGURE was never told to watch: a test growing a "#pconfigure
# TESTDEPS" line is exactly the kind of edit AUTORECONFIGURE exists to
# notice, and it is the one kind it misses.  Without a rebuilt Makefile the
# stub still doesn't wait on the tool it now names, so it can run -- and
# report a verdict -- before that tool exists, or without noticing an edit
# to it.

# The rule below runs whatever the PATH calls "pconfigure", the same
# as "make reconfigure" does (see autoreconfigure-configfile.bash), so
# the PATH is what has to be pointed at the one under test.
export PATH="$(dirname "$PTEST_BINARY"):$PATH"

mkdir -p src test/uses-tool

cat >Configfile <<'CONFIGFILE'
AUTORECONFIGURE = true
LANGUAGES   += c
LANGUAGES   += bash

TESTEXECS   += tool
SOURCES     += tool.c

BINARIES    += uses-tool
SOURCES     += uses-tool.c
TESTSRC     += finds-tool.bash
CONFIGFILE

cat >src/tool.c <<'SOURCE'
  #include <stdio.h>
int main(void) { printf("tool\n"); return 0; }
SOURCE

cat >src/uses-tool.c <<'SOURCE'
int main(void) { return 0; }
SOURCE

# No "#pconfigure TESTDEPS" line yet -- that's the edit below.
cat >test/uses-tool/finds-tool.bash <<'SOURCE'
true
SOURCE

$PTEST_BINARY $PCONFIGURE_ARGS

# Nothing waits on the tool yet, which is the state before the edit this
# test is about.
if grep -q "^check/uses-tool/finds-tool.bash:.*testexec/tool" Makefile
then
    exit 1
fi

##############################################################################
# The edit AUTORECONFIGURE is supposed to notice                             #
##############################################################################
# No Configfile changed, so this is the whole of the claim: a test file
# growing a "#pconfigure TESTDEPS" line is a change to what "make check" has
# to build before that test runs, same as a Configfile naming a new
# TESTDEPS is -- and AUTORECONFIGURE exists so nobody has to run pconfigure
# by hand to make either one true.
sleep 1
{
    echo '#pconfigure TESTDEPS += testexec/tool'
    cat test/uses-tool/finds-tool.bash
} > test/uses-tool/finds-tool.bash.new
mv test/uses-tool/finds-tool.bash.new test/uses-tool/finds-tool.bash

make $MAKE_ARGS > second.log 2>&1
cat second.log

# The bug: without a reconfigure here, the rule below still doesn't name
# the tool, and "make check" builds the stub's check rule exactly as it
# stood at the last pconfigure -- which never waited on the tool at all.
grep -q "^PCONFIGURE$" second.log
grep -q "^check/uses-tool/finds-tool.bash:.*testexec/tool" Makefile

exit 0
