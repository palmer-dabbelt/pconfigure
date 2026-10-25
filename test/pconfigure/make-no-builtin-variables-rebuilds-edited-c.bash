#include "harness_start.bash"

# The C recipes are spelled "${CC} -x c ..." and "${CC} ${LDFLAGS}
# ...", and nothing used to define CC but make itself.  "make -R"
# (--no-builtin-variables) takes make's away, and so does any parent
# with -R in its MAKEFLAGS.  With CC empty the expanded recipe line
# starts with "-x", and make reads a leading '-' on an expanded line
# as "ignore errors": the compile failed, make printed "(ignored)",
# nothing relinked, and make exited 0 with the old program still in
# bin/.  The generated Makefile has to name a compiler of its own for
# when make won't.

mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += c

BINARIES  += answer
SOURCES   += answer.c
EOF

cat >src/answer.c <<'EOF'
int main(void) { return 1; }
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
set +e
./bin/answer
status="$?"
set -e
test "$status" = 1

sleep 1
cat >src/answer.c <<'EOF'
int main(void) { return 2; }
EOF

make $MAKE_ARGS -R > make.out 2>&1 || { cat make.out; exit 1; }
cat make.out
if grep -q "(ignored)" make.out
then
    echo "make ignored a failed recipe under -R" >&2
    exit 1
fi

set +e
./bin/answer
status="$?"
set -e
test "$status" = 2

# The default is only a default: a CC given on the command line is
# still the compiler that runs, -R or not.  The wrapper leaves a mark
# so that "it built" can't be the system cc having been used instead.
cat >mycc <<EOF
#!/bin/bash
touch $(pwd)/mycc.ran
exec cc "\$@"
EOF
chmod +x mycc

sleep 1
cat >src/answer.c <<'EOF'
int main(void) { return 3; }
EOF

make $MAKE_ARGS -R CC=$(pwd)/mycc
test -e mycc.ran

set +e
./bin/answer
status="$?"
set -e
test "$status" = 3
