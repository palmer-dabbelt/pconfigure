#include "harness_start.bash"

# The shape "make -R" really arrives in: a parent build that drives
# this one with a recursive make and has "-rR" in its MAKEFLAGS, the
# way Linux's kbuild does, so the child inherits it without anybody
# typing it.  Its recipes name ${CC}, which make no longer defines,
# and the rebuild after an edit used to exit 0 having ignored the
# failed compile and left the old program in place.

mkdir -p proj/src

cat >proj/Configfile <<'EOF'
LANGUAGES += c

BINARIES  += answer
SOURCES   += answer.c
EOF

cat >proj/src/answer.c <<'EOF'
int main(void) { return 1; }
EOF

cat >Makefile <<'EOF'
MAKEFLAGS += -rR
.PHONY: all
all:
	$(MAKE) -C proj
EOF

(cd proj && $PTEST_BINARY $PCONFIGURE_ARGS)
make $MAKE_ARGS
set +e
./proj/bin/answer
status="$?"
set -e
test "$status" = 1

sleep 1
cat >proj/src/answer.c <<'EOF'
int main(void) { return 2; }
EOF

make $MAKE_ARGS > make.out 2>&1 || { cat make.out; exit 1; }
cat make.out
if grep -q "(ignored)" make.out
then
    echo "make ignored a failed recipe under the parent's -R" >&2
    exit 1
fi

set +e
./proj/bin/answer
status="$?"
set -e
test "$status" = 2
