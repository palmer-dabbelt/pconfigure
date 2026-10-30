#include "harness_start.bash"

# The Perl twin of the bash case: pperlc pastes an "#include" from
# whichever "-I" the target names, and the compiled script is written
# under its own name, so the only thing in its rule that changes when
# the options do is the recipe pperlc shares with pbashc.  Moving the
# "-I" used to leave the old file pasted in.
mkdir -p src one two

cat >src/tool.pl <<'EOF'
#!/usr/bin/perl
#include "which.pl"
EOF

cat >one/which.pl <<'EOF'
print "one\n";
EOF

cat >two/which.pl <<'EOF'
print "two\n";
EOF

cat >Configfile <<EOF
LANGUAGES   += perl

BINARIES    += tool
COMPILEOPTS += -Ione
SOURCES     += tool.pl
EOF

sleep 2

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/tool)" = "one"

sleep 2
sed -i.bak 's/-Ione/-Itwo/' Configfile

$PTEST_BINARY $PCONFIGURE_ARGS

make $MAKE_ARGS
test "$(./bin/tool)" = "two"

exit 0
