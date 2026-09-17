#include "harness_start.bash"

# CONFIG_DEPS: what a Configfile that ENUMERATES something depends on.
#
# The reconfigure rule watches every file a run looked for lines in,
# which is exactly right for a Configfile somebody edits and blind to
# a Configfile that reads a DIRECTORY.  An executable one that globs a
# directory of tests and prints a TESTSRC line for each has an input
# nothing in that list can see: the directory itself.  Nothing in it
# is a Configfile, so nothing opens it, so adding a test changed no
# watched file -- the makefile was not rewritten, and the test sat on
# disk without being in the build, which reads as coverage and is not.
#
# A directory is the useful thing to name, because its mtime moves
# when an entry is added or removed and for nothing else.  A file
# works too, and is tested here, but a file could already say that it
# had changed; only a directory can say something appeared next to it.

# The rule runs whatever the PATH calls "pconfigure", the same as
# "make reconfigure" does, so the PATH is what has to be pointed at
# the one under test.
export PATH="$(dirname "$PTEST_BINARY"):$PATH"

# $1 is the directory to build in, and $2 says where the CONFIG_DEPS
# line goes -- which is the point of the second and third trees.  The
# two spellings have to mean the same thing, because they are the same
# line by the time the parser sees it: "containing" writes it beside
# the CONFIG that pulls the family in, "printed" has the family's own
# executable emit it, so the dependency sits next to the glob it
# describes rather than in the file that merely asked for it.  "none"
# is the control.
tree() {
    mkdir -p "$1/src" "$1/tests" "$1/Configfiles"

    # An "if" rather than a "test ... && echo": under the harness's
    # "set -e" an AND-list that ends false is a failed command, and
    # these are the last thing in their block for two of the three
    # trees -- so the shorter spelling would abort the control run
    # before it measured anything.
    if [ "$2" = "containing" ]; then
        in_configfile="CONFIG_DEPS    += tests"
    else
        in_configfile=""
    fi
    if [ "$2" = "printed" ]; then
        # Printed BEFORE the enumeration, which is the form the command
        # is meant to support: a family says what it reads, then reads it.
        in_family='echo "CONFIG_DEPS += tests"'
    else
        in_family=""
    fi

    (
        cd "$1"
        cat > Configfile <<CONFIGFILE
AUTORECONFIGURE = true
LANGUAGES      += bash
LANGUAGES      += c++
BINARIES       += top
SOURCES        += top.c++
CONFIG         += tests
$in_configfile
CONFIGFILE

        cat > Configfiles/tests <<FAMILY
#!/bin/bash
$in_family
for f in tests/*.bash; do
    [ -e "\$f" ] || continue
    echo "TESTSRC += \${f##*/}"
done
FAMILY
        chmod +x Configfiles/tests

        cat >src/top.c++ <<'SOURCE'
int main(void) { return 0; }
SOURCE

        cat >tests/first.bash <<'SOURCE'
exit 0
SOURCE
    )
}

# A test the enumeration has not been told about yet.  Its name is
# what the assertions look for: a makefile that names it was written
# after it existed, and one that does not was not.
add_second() {
    cat >"$1/tests/second.bash" <<'SOURCE'
exit 0
SOURCE
}

##############################################################################
# The line in the containing Configfile                                      #
##############################################################################
tree containing containing
(cd containing && $PTEST_BINARY $PCONFIGURE_ARGS && make $MAKE_ARGS)

# The directory is a prerequisite of the reconfigure rule, through the
# same $(wildcard) every other name goes through -- so a CONFIG_DEPS
# naming something that is not there yet is mentionable rather than a
# hard error, exactly like a Configfile.local.
grep -q '\$(wildcard tests)' containing/Makefile

# It enumerated what was there, and only that.
grep -q 'first.bash' containing/Makefile
if grep -q 'second.bash' containing/Makefile
then
    exit 1
fi

# A second make settles.  This is the assertion that fails if a
# directory prerequisite is left permanently newer than the Makefile:
# that is a recipe make would run on every single invocation, forever.
(cd containing && make $MAKE_ARGS) > containing/second.log 2>&1
cat containing/second.log
if grep -q "^PCONFIGURE$" containing/second.log
then
    exit 1
fi

# The whole point: a test file appears, and a plain "make" notices --
# because the DIRECTORY changed, not because any watched file did.
sleep 1
add_second containing
(cd containing && make $MAKE_ARGS) > containing/third.log 2>&1
cat containing/third.log
grep -q "^PCONFIGURE$" containing/third.log
grep -q 'second.bash' containing/Makefile

##############################################################################
# The line printed by the executable Configfile                              #
##############################################################################
# Same claim, other spelling.  A family that enumerates a directory
# can declare that directory itself, which keeps the two next to each
# other where they cannot drift apart.
tree printed printed
(cd printed && $PTEST_BINARY $PCONFIGURE_ARGS && make $MAKE_ARGS)

grep -q '\$(wildcard tests)' printed/Makefile
grep -q 'first.bash' printed/Makefile

sleep 1
add_second printed
(cd printed && make $MAKE_ARGS) > printed/third.log 2>&1
cat printed/third.log
grep -q "^PCONFIGURE$" printed/third.log
grep -q 'second.bash' printed/Makefile

##############################################################################
# Without it, which is what makes the two above measurements           #
##############################################################################
# The same tree and the same edit with the CONFIG_DEPS line left out.
# It must NOT reconfigure, and the new test must NOT reach the
# makefile -- otherwise something else was noticing the change and
# neither half above proves anything about this command.
tree none none
(cd none && $PTEST_BINARY $PCONFIGURE_ARGS && make $MAKE_ARGS)

if grep -q '\$(wildcard tests)' none/Makefile
then
    exit 1
fi

sleep 1
add_second none
(cd none && make $MAKE_ARGS) > none/third.log 2>&1
cat none/third.log
if grep -q "^PCONFIGURE$" none/third.log
then
    exit 1
fi
if grep -q 'second.bash' none/Makefile
then
    exit 1
fi

exit 0
