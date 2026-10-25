#include "harness_start.bash"

# A subproject configured from the top and configured on its own is
# promised, by the manual, to share what it builds: the two runs
# "agree about which files those paths name, so the objects, libraries
# and binaries they build are shared rather than duplicated".  An
# object's name is a hash of its compile line, though, and the compile
# line is spelled from where the run stood: "-Isub/include" and
# "sub/src/tool.c" from the top, "-Iinclude" and "src/tool.c" from
# inside.  The link line is the same story with "-Lsub/lib".  So the
# two builds compiled into different objects and linked into
# different directories, and the first make on the other side did the
# whole build over again.  The include directory and the library are
# here so that each kind of path on the two lines gets a say.
mkdir -p sub/src sub/include

cat >Configfile <<'EOF'
SUBPROJECTS += sub
EOF

cat >sub/Configfile <<'EOF'
LANGUAGES   += c
COMPILEOPTS += -Iinclude

LIBRARIES   += libpart.so
SOURCES     += part.c

BINARIES    += tool
DEPLIBS     += part
SOURCES     += tool.c
EOF

echo 'int part(void);' > sub/include/part.h
cat >sub/src/part.c <<'EOF'
#include "part.h"
int part(void) { return 0; }
EOF
cat >sub/src/tool.c <<'EOF'
#include "part.h"
int main(void) { return part(); }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
(cd sub && $PTEST_BINARY $PCONFIGURE_ARGS)

make $MAKE_ARGS
test -x sub/bin/tool

# Everything the top just built is what the subproject's own build
# would have built, so there is nothing left for it to do.
(cd sub && make $MAKE_ARGS) > inside.out 2>&1
cat inside.out
if grep -q "^CC	\|^LD	\|^CP	" inside.out
then
    exit 1
fi

# And one object for each source, whichever side built it.
for source in part.c tool.c
do
    ls sub/obj/src/$source
    test "$(ls sub/obj/src/$source | grep -c '\.o$')" = "1"
done

exit 0
