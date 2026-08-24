#include "harness_start.bash"

# AUTODEPS = false is about what gets *linked*: a target that says it
# doesn't want the sources behind its headers dragged in and built
# alongside it.  It was also turning off the header prerequisites,
# which is a different thing entirely and one nobody would ask for --
# a source whose headers aren't prerequisites doesn't get rebuilt when
# one of them changes, so what comes out is an object compiled against
# declarations that have since moved.
mkdir -p src

cat >Configfile <<EOF
LANGUAGES += c++

BINARIES  += app
AUTODEPS   = false
SOURCES   += app.c++
EOF

# The value the program prints lives in a header, so the only way to
# print the new one is to have been recompiled since it changed.
cat >src/value.h++ <<'EOF'
#define VALUE 1
EOF

# A header with a source next to it, which is what AUTODEPS = false is
# actually for: with it on, "extra.c++" gets compiled and linked into
# whatever included "extra.h++".
cat >src/extra.h++ <<'EOF'
int extra(void);
EOF

cat >src/extra.c++ <<'EOF'
int extra(void) { return 7; }
EOF

cat >src/app.c++ <<'EOF'
  #include "value.h++"
  #include "extra.h++"
  #include <cstdio>

int main(void) { printf("%d\n", VALUE); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

# The header the source includes is a prerequisite of the object built
# from it, which is what makes "make" rebuild when it changes.
grep -q "^obj/src/app.c++/.*\.o:.* src/value.h++" Makefile
grep -q "^obj/src/app.c++/.*\.o:.* src/extra.h++" Makefile

# The source behind that second header is not built and not linked,
# which is the thing AUTODEPS = false was asked for.
if grep -q "obj/src/extra.c++" Makefile
then
    exit 1
fi

make $MAKE_ARGS
test "$(./bin/app)" = "1"

# Changing the header rebuilds what included it.  This is the whole
# bug: with the prerequisite missing, "make" has nothing to notice and
# the program keeps printing the old value.
sleep 2
cat >src/value.h++ <<'EOF'
#define VALUE 2
EOF

make $MAKE_ARGS
test "$(./bin/app)" = "2"

##############################################################################
# The same project with AUTODEPS left alone                                  #
##############################################################################
# The header prerequisites are the same ones either way.  What changes
# is that the source behind "extra.h++" is now built and linked in,
# which is the half AUTODEPS = false turns off.
mkdir -p $tempdir/on/src
cd $tempdir/on

cat >Configfile <<EOF
LANGUAGES += c++

BINARIES  += app
SOURCES   += app.c++
EOF

cp $tempdir/src/value.h++ src/value.h++
cp $tempdir/src/extra.h++ src/extra.h++
cp $tempdir/src/extra.c++ src/extra.c++

cat >src/app.c++ <<'EOF'
  #include "value.h++"
  #include "extra.h++"
  #include <cstdio>

int main(void) { printf("%d\n", VALUE + extra()); return 0; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile

grep -q "^obj/src/app.c++/.*\.o:.* src/value.h++" Makefile
grep -q "obj/src/extra.c++" Makefile

make $MAKE_ARGS
test "$(./bin/app)" = "9"

exit 0
