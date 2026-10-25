#include "harness_start.bash"

# A BASH target is one script in and one script out: pbashc is handed
# a single input with "-i" and that file is the whole program.  A
# second SOURCES line used to be accepted, written down as a
# prerequisite of the script -- so editing it rebuilt the script --
# and then never handed to pbashc, so the program ran without it and
# nothing ever said so.  Now the second line is refused by number, and
# the message says how two files are made into one script: the first
# includes the second.
#
# Every fatal error here ends in abort(), so the exit status alone
# says nothing about which one this was; the message is what's
# checked.  The second source is not on the line after the first, so
# a message naming the wrong line can't pass.
mkdir -p src

cat >Configfile <<'EOF2'
LANGUAGES += bash

BINARIES  += tool
SOURCES   += tool.bash
COMPILEOPTS += -DUNUSED
SOURCES   += more.bash
EOF2

cat >src/tool.bash <<'EOF2'
echo tool
EOF2

cat >src/more.bash <<'EOF2'
echo more
EOF2

if $PTEST_BINARY $PCONFIGURE_ARGS > pconfigure.out 2>&1
then
    cat pconfigure.out
    exit 1
fi
cat pconfigure.out
test ! -e Makefile

grep -q "Configfile:6 'SOURCES += more.bash'" pconfigure.out
grep -q "'tool' is one script made from one source" pconfigure.out
grep -q "already has 'tool.bash' from \./Configfile:4" pconfigure.out
grep -q "write '#include \"more.bash\"' in tool.bash" pconfigure.out
