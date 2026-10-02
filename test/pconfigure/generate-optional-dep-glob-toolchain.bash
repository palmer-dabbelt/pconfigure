#include "harness_start.bash"

# The incident, written down in miniature.  A fixture script needed an
# AArch64 cross compiler that buildroot builds later in the same tree,
# and it could not name the compiler for two reasons at once: the file
# was not there when pconfigure ran, and neither was the directory it
# would land in, so there was nothing on disk for a glob to expand and
# nothing for a directory watch to hold on to either.  The script
# therefore printed nothing about it, the fixture was generated empty
# and correct, buildroot built the compiler four days later, and the
# empty fixture kept its fresh mtime.  472 of 479 tests skipped for
# three days.
#
# What this pins past generate-optional-dep-arrives.bash: the path is a
# glob pattern rather than a filename, which is how a script names a
# toolchain whose shape it knows and whose version it does not, and
# neither the pattern nor any part of its directory exists at configure
# time.  "$(wildcard)" has to tolerate a pattern matching nothing in a
# directory that does not exist, and then has to match the file the day
# both of them appear.

mkdir -p src

cat >Configfile <<EOF
LANGUAGES += c

GENERATE  += gen.h

BINARIES  += app
SOURCES   += app.c
EOF

# The shape the real fixture scripts use: ask whether a compiler is
# there, generate one answer or the other, and tell pconfigure about
# the pattern rather than about whatever it happened to match.
cat >src/gen.h.proc <<'EOF'
#!/bin/bash
cc=$(ls obj/toolchain/bin/aarch64-*linux*-gcc 2>/dev/null | head -n1)
case "$1" in
--deps)     echo "?obj/toolchain/bin/aarch64-*linux*-gcc" ;;
--generate) if test -n "$cc"
            then echo "#define HAVE_CROSS_CC 1"
            else echo "#define HAVE_CROSS_CC 0"
            fi ;;
esac
EOF
chmod +x src/gen.h.proc

cat >src/app.c <<'EOF'
  #include "gen.h"
  #include <stdio.h>
int main(void) { printf("%d\n", HAVE_CROSS_CC); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

timeout 60 make $MAKE_ARGS > first.out 2>&1 || { cat first.out; exit 1; }
cat first.out

if grep -q "No rule to make target" first.out
then
    exit 1
fi

# No compiler, so the honest answer, and the build settles on it.
test "$(./bin/app)" = "0"

# And the pattern reached the rule as a pattern, with make's glob
# characters intact -- rewriting them would be pconfigure deciding which
# compiler the script meant.  This is checked after the build rather
# than before it so that a regression shows up as the build failing,
# which is what actually went wrong, rather than as a grep that did not
# match.
grep -qxF 'obj/proc/gen.h: src/gen.h.proc $(foreach f,$(wildcard obj/toolchain/bin/aarch64-*linux*-gcc),$(if $(realpath $(f)),$(f),))' Makefile
timeout 60 make $MAKE_ARGS > settled.out 2>&1 || { cat settled.out; exit 1; }
cat settled.out
grep -q "Nothing to be done" settled.out

##############################################################################
# Four days later, buildroot finishes                                        #
##############################################################################
sleep 2
mkdir -p obj/toolchain/bin
touch obj/toolchain/bin/aarch64-buildroot-linux-gnu-gcc
chmod +x obj/toolchain/bin/aarch64-buildroot-linux-gnu-gcc

timeout 60 make $MAKE_ARGS > second.out 2>&1 || { cat second.out; exit 1; }
cat second.out

# This is the measurement the incident is about: the very next plain
# make, no reconfigure asked for and none run, notices a compiler that
# did not exist when the dependency graph was written down.
if grep -q "^PCONFIGURE$" second.out
then
    exit 1
fi

grep -q "^GEN	gen.h$" second.out
grep -q "define HAVE_CROSS_CC 1" obj/proc/gen.h
test "$(./bin/app)" = "1"

timeout 60 make $MAKE_ARGS > third.out 2>&1 || { cat third.out; exit 1; }
cat third.out
grep -q "Nothing to be done" third.out

##############################################################################
# A second compiler in the same directory                                    #
##############################################################################
# The pattern is expanded by make on every run, so the set it names can
# grow without the script's answer changing a character.  A build that
# needed the "--deps" text to change to notice this would be back to a
# cache keyed on the wrong thing.
sleep 2
touch obj/toolchain/bin/aarch64-buildroot-linux-musl-gcc

timeout 60 make $MAKE_ARGS > fourth.out 2>&1 || { cat fourth.out; exit 1; }
cat fourth.out
grep -q "^GEN	gen.h$" fourth.out

timeout 60 make $MAKE_ARGS > fifth.out 2>&1 || { cat fifth.out; exit 1; }
cat fifth.out
grep -q "Nothing to be done" fifth.out

exit 0
