#include "harness_start.bash"
#pconfigure TESTDEPS += bin/pdeps

# The Perl twin of the BASH case: pperlc pastes an "#include" in the
# same way, and under AUTORECONFIGURE a file a script starts including
# after the configure has to be watched by the build, the same as a
# header a C source starts including is.
export PATH="$(dirname "$PTEST_BINARY"):$PATH"

mkdir -p src

cat >Configfile <<EOF
AUTORECONFIGURE = true

LANGUAGES += perl

BINARIES  += tool
SOURCES   += tool.pl
EOF

cat >src/tool.pl <<'EOF'
#!/usr/bin/perl
print "plain\n";
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/tool)" = "plain"

sleep 2
cat >src/lib.pl <<'EOF'
print "first\n";
EOF
cat >src/tool.pl <<'EOF'
#!/usr/bin/perl
#include "lib.pl"
EOF
make $MAKE_ARGS
test "$(./bin/tool)" = "first"

sleep 2
cat >src/lib.pl <<'EOF'
print "second\n";
EOF
make $MAKE_ARGS
test "$(./bin/tool)" = "second"

exit 0
