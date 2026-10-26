#include "harness_start.bash"

# Every file a configure leaves in the object directory for the build to
# read -- each link's link-inputs, each script's, test's and header
# copy's recipe-inputs, a GENERATE's output -- has a rule that writes it
# back when it goes missing.  The check bookkeeping and a GENERATE's
# --deps context and recipe record aren't read by the build, so nothing
# writes them back, but deleting one still has to leave "make" and "make
# check" working.
# The tests that delete the whole directory show the files come back
# together; this deletes them one at a time, without AUTORECONFIGURE, so
# a file whose rule only works alongside the others being rewritten too
# has nowhere to hide.

mkdir -p src test/main

cat >Configfile <<'EOC'
LANGUAGES       += c
LANGUAGES       += bash
LANGUAGES       += h
GENERATE        += gen.h
LIBRARIES       += libfoo.so
SOURCES         += foo.c
BINARIES        += main
DEPLIBS         += foo
SOURCES         += main.c
TESTSRC         += t.bash
TESTSRC         += ct.c
BINARIES        += script
SOURCES         += script.bash
HEADERS         += foo.h
SOURCES         += foo.h
EOC

cat >src/gen.h.proc <<'EOS'
#!/bin/bash
case "$1" in
--deps)     ;;
--generate) echo "#define G 0" ;;
esac
EOS
chmod +x src/gen.h.proc

echo 'int foo(void);' > src/foo.h
printf '#include "foo.h"\nint foo(void) { return 0; }\n' > src/foo.c
printf '#include "foo.h"\n#include "gen.h"\nint main(void) { return foo() + G; }\n' > src/main.c
echo 'echo hi' > src/script.bash
echo 'exit 0' > test/main/t.bash
echo 'int main(void) { return 0; }' > test/main/ct.c

$PTEST_BINARY $PCONFIGURE_ARGS
find obj -type f | sort > configure-files
cat configure-files

# The loop below is only as good as the list it walks, so make sure
# every kind of file it means to cover is on it: a configure that
# stopped writing one of them would otherwise pass by having less to
# delete.
grep -qx 'obj/bin/main/[0-9]*/link-inputs' configure-files
grep -qx 'obj/lib/libfoo.so/[0-9]*/link-inputs' configure-files
grep -qx 'obj/obj/check/main/ct.c/[0-9]*/link-inputs' configure-files
grep -qx 'obj/bin/script.recipe-inputs' configure-files
grep -qx 'obj/check/main/t.bash.recipe-inputs' configure-files
grep -qx 'obj/include/foo.h.recipe-inputs' configure-files
grep -qx 'obj/proc/gen.h' configure-files
grep -qx 'obj/proc/gen.h.d-context' configure-files

while read -r file
do
    $PTEST_BINARY $PCONFIGURE_ARGS
    make $MAKE_ARGS > before.log 2>&1 || { cat before.log; exit 1; }
    make $MAKE_ARGS check > before.log 2>&1 || { cat before.log; exit 1; }

    rm -f "$file"
    echo "deleted $file"
    make $MAKE_ARGS > after.log 2>&1 || { cat after.log; exit 1; }
    make $MAKE_ARGS check > after.log 2>&1 || { cat after.log; exit 1; }

    # Every one the build reads is back.  The check-* records are not
    # read by the build: the scope has an empty rule on purpose, so a
    # missing one counts as changed and the next report scores
    # everything, and check-dirs and check-stamp are read by a bare ptest
    # run rather than by make, so nothing in the Makefile has them as a
    # prerequisite to write back.  A GENERATE's .d-context is the
    # configure's own record of how its --deps fragment was made, read by
    # the next configure and not by the build, and so is the record of the
    # recipe that wrote its output: that one is left off the rule's
    # prerequisites on purpose, so that a new script giving the old answer
    # doesn't leave an output make wants to rewrite on every build, and a
    # missing one just means the next configure has nothing to compare.
    case "$file" in
    obj/check-*|*.d-context|obj/proc/*.recipe-inputs) ;;
    *)           test -e "$file" ;;
    esac
done < configure-files
