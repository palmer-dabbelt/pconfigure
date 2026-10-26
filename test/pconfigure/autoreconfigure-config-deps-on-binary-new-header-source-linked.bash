#include "harness_start.bash"

# A program that is its own CONFIG_DEPS is linked while make is
# remaking the makefiles it includes, which is before it has read what
# they now say.  An edit that has the program's source include a
# header with a source behind it rewrites that source's fragment to
# pull in the new one's, and the fragment make already read said
# nothing of it.  So the link ran with the edited object and without
# the one it now calls -- an undefined reference -- and since the new
# fragment is still missing whenever the next make starts, every make
# after that failed the same way.

export PATH="$(dirname "$PTEST_BINARY"):$PATH"

mkdir -p src

cat >Configfile <<'EOF'
AUTORECONFIGURE  = true
LANGUAGES       += c
CONFIG_DEPS     += bin/main
BINARIES        += main
SOURCES         += main.c
EOF

echo 'int main(void) { return 0; }' > src/main.c
echo 'int util(void);' > src/util.h
echo 'int util(void) { return 0; }' > src/util.c

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
make $MAKE_ARGS
test -x bin/main

sleep 1
printf '#include "util.h"\nint main(void) { return util(); }\n' > src/main.c

make $MAKE_ARGS > second.log 2>&1 || { cat second.log; exit 1; }
cat second.log
bin/main

make $MAKE_ARGS > third.log 2>&1 || { cat third.log; exit 1; }
cat third.log
grep -q "Nothing to be done" third.log

exit 0
