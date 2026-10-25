#include "harness_start.bash"

# Under AUTORECONFIGURE a subproject whose object directory was deleted
# gets its Makefile back from a pconfigure run make starts by itself.
# That run rewrites every Makefile in the tree, the top one included,
# so it has to be the configuration that was asked for: a tree
# configured with "--config extra" that drops the targets
# Configfiles/extra declared because somebody cleared out a
# subproject's objects has changed shape behind their back.

export PATH="$(dirname "$PTEST_BINARY"):$PATH"

mkdir -p src sub/src Configfiles

cat >Configfile <<'EOF'
AUTORECONFIGURE  = true
SUBPROJECTS     += sub
LANGUAGES       += c
BINARIES        += main
SOURCES         += main.c
EOF

cat >Configfiles/extra <<'EOF'
LANGUAGES       += c
BINARIES        += extra
SOURCES         += extra.c
EOF

cat >sub/Configfile <<'EOF'
LANGUAGES       += c
BINARIES        += subbin
SOURCES         += sub.c
EOF

for f in src/main.c src/extra.c sub/src/sub.c
do
    echo 'int main(void) { return 0; }' > "$f"
done

$PTEST_BINARY $PCONFIGURE_ARGS --config extra
make $MAKE_ARGS
test -x bin/extra
grep -q '^bin/extra:' Makefile

rm -rf sub/obj
make $MAKE_ARGS > second.log 2>&1
cat second.log
grep -q "^PCONFIGURE$" second.log
test -e sub/obj/Makefile.sub

grep -q '^bin/extra:' Makefile

exit 0
