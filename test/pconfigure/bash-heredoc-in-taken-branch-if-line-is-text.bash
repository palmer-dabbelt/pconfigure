#include "harness_start.bash"

# A heredoc written inside an "#ifdef" that is taken is a heredoc like
# any other: the "#if" in the C file it writes is text, and neither
# pbashc nor pconfigure's scan refuses it.
mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += bash
COMPILEOPTS += -DGEN_C

BINARIES  += tool
SOURCES   += tool.bash
EOF

cat >src/tool.bash <<'EOF'
#ifdef GEN_C
cat <<'END'
#if 0
int unused;
#endif
END
#endif
echo tool
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
printf '%s\n' '#if 0' 'int unused;' '#endif' tool >want
./bin/tool >got
diff -u want got
