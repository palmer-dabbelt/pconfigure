#include "harness_start.bash"

# A "--generate" that fails has to leave no target at all.  The rule
# used to be a raw redirect -- "script --generate > out" -- which is the
# one rule in this family written that way, and a redirect creates the
# file before the script has said a word.  So a script that printed half
# its answer and then died left a truncated file carrying an mtime newer
# than every prerequisite it has, and the next make called that up to
# date: the build goes green over a header with half a declaration in
# it, and the only evidence is in the scrollback of the make that
# failed.  The configure-time run makes it worse rather than better,
# because it generates only when the target is missing, so a truncated
# file from a failed configure is a file no later pconfigure
# reconsiders either.
#
# The shape is the one makefile.c++ keeps for the check reports: write
# to a temporary, move it into place, and remove both on failure, so
# that the target exists if and only if the last run that wrote it
# succeeded.  Absence is then the one state a reader cannot misread.
#
# The script is broken by an optional input arriving rather than by
# editing the script, because that gives one mutation that both
# re-triggers the rule and makes it fail -- and because it leaves the
# configure-time run intact, which has to succeed or there is no build
# to break.

mkdir -p src

cat >Configfile <<EOF
LANGUAGES += c

GENERATE  += gen.h

BINARIES  += app
SOURCES   += app.c
EOF

# It prints a usable line first and then dies, which is the whole
# point: a script that fails before printing anything would leave an
# empty file, and an empty file is at least obviously wrong.  A file
# with a plausible first line in it is the one that gets compiled.
cat >src/gen.h.proc <<'EOF'
#!/bin/bash
case "$1" in
--deps)     echo "?src/break" ;;
--generate) echo "#define ANSWER 1"
            if test -f src/break
            then
                echo "#define HALF_WRITTEN"
                exit 1
            fi ;;
esac
EOF
chmod +x src/gen.h.proc

cat >src/app.c <<'EOF'
  #include "gen.h"
  #include <stdio.h>
int main(void) { printf("%d\n", ANSWER); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

timeout 60 make $MAKE_ARGS > first.out 2>&1 || { cat first.out; exit 1; }
cat first.out
test "$(./bin/app)" = "1"

##############################################################################
# Now the script fails                                                       #
##############################################################################
sleep 2
touch src/break

if timeout 60 make $MAKE_ARGS > second.out 2>&1
then
    cat second.out
    exit 1
fi
cat second.out

# It really got as far as running the script, rather than failing
# somewhere earlier and proving nothing.
grep -q "^GEN	gen.h$" second.out

# And there is nothing left behind: no target, and no temporary either.
if test -e obj/proc/gen.h
then
    exit 1
fi
if test -e obj/proc/gen.h.tmp
then
    exit 1
fi

##############################################################################
# The next make retries rather than believing a file                          #
##############################################################################
# This is the assertion the raw redirect fails: with a truncated target
# sitting there newer than its prerequisites, this make prints "Nothing
# to be done" and exits 0.
if timeout 60 make $MAKE_ARGS > third.out 2>&1
then
    cat third.out
    exit 1
fi
cat third.out
grep -q "^GEN	gen.h$" third.out

if grep -q "Nothing to be done" third.out
then
    exit 1
fi

if test -e obj/proc/gen.h
then
    exit 1
fi

# Nothing downstream was built out of a file that does not exist.
if test -e bin/app
then
    # It is still the binary from the first, successful build; what
    # must not have happened is a recompile against a half-written
    # header.
    if grep -q "^CC	app.c$" third.out
    then
        exit 1
    fi
fi

##############################################################################
# And it recovers once the script works again                                #
##############################################################################
sleep 2
rm src/break

timeout 60 make $MAKE_ARGS > fourth.out 2>&1 || { cat fourth.out; exit 1; }
cat fourth.out
grep -q "^GEN	gen.h$" fourth.out
grep -q "define ANSWER 1" obj/proc/gen.h

if grep -q "HALF_WRITTEN" obj/proc/gen.h
then
    exit 1
fi

test "$(./bin/app)" = "1"

# And the recipe really is the write-a-temporary-and-move shape, rather
# than something that happened to pass the measurements above.  Checked
# here rather than before the build so that a regression reads as the
# truncated file it leaves behind rather than as a grep that missed.
grep -q 'obj/proc/gen.h.tmp && mv obj/proc/gen.h.tmp obj/proc/gen.h || (rm -f obj/proc/gen.h.tmp obj/proc/gen.h; exit 1)$' Makefile

timeout 60 make $MAKE_ARGS > fifth.out 2>&1 || { cat fifth.out; exit 1; }
cat fifth.out
grep -q "Nothing to be done" fifth.out

exit 0
