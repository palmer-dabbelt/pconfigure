#include "harness_start.bash"

# A ';' on a rule line ends the prerequisites and starts the rule's
# recipe.  A --deps path with one in it was pasted onto the rule line
# as written, so "src/a;touch PWNED" handed make the prerequisite
# "src/a" and a recipe of "touch PWNED", which replaced the GENERATE
# recipe outright -- whatever a script printed after a ';' was run by
# make as a shell command, in place of the script.  make has no
# spelling for a ';' that belongs to a file name, not even inside a
# $(wildcard ...), so such a path is refused: at configure time naming
# the GENERATE line, and during the build when the script's live
# answer starts printing one.

mkdir -p src

cat >Configfile <<EOF
LANGUAGES += c
GENERATE  += gen.h
BINARIES  += app
SOURCES   += app.c
EOF

# The part before the ';' exists, so that a make that did read the line
# wrongly would get as far as running the recipe it was handed rather
# than stopping on a missing "src/a".
echo 0 > src/a
echo 1 > src/base.txt
echo 4 > 'src/a;touch PWNED'

cat >src/app.c <<'EOF'
#include "gen.h"
#include <stdio.h>
int main(void) { printf("%d\n", V); return 0; }
EOF

# Both kinds of line, at configure time.
for line in 'src/a;touch PWNED' '?src/a;touch PWNED'
do
    cat >src/gen.h.proc <<EOF
#!/bin/sh
case "\$1" in
--deps)     echo '$line' ;;
--generate) echo "#define V 1" ;;
esac
EOF
    chmod +x src/gen.h.proc

    if $PTEST_BINARY $PCONFIGURE_ARGS >configure.out 2>&1
    then
        cat configure.out
        exit 1
    fi
    cat configure.out
    grep -q "^./Configfile:2 'GENERATE += gen.h'$" configure.out
    grep -qF "'src/gen.h.proc --deps' printed a path with a ';' in it" configure.out
    grep -qF "src/a;touch PWNED" configure.out
    test ! -e Makefile
    test ! -e PWNED
done

# And during the build: the script's answer is fine when pconfigure
# asks and grows a ';' once a marker appears, which is the route by
# which an answer reaches the fragment and nothing else.
cat >src/gen.h.proc <<'EOF'
#!/bin/sh
case "$1" in
--deps)     echo 'src/base.txt'
            if test -f src/mark
            then echo 'src/a;touch PWNED'
            fi ;;
--generate) echo "#define V $(cat src/base.txt)" ;;
esac
EOF
chmod +x src/gen.h.proc

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/app)" = "1"

sleep 2
touch src/mark
if make $MAKE_ARGS >make.out 2>&1
then
    cat make.out
    exit 1
fi
cat make.out
grep -qF "'src/gen.h.proc --deps' printed a path with a ';' in it" make.out
test ! -e PWNED
grep -qxF 'obj/proc/gen.h: src/base.txt' obj/proc/gen.h.d
test ! -e obj/proc/gen.h.d.raw

exit 0
