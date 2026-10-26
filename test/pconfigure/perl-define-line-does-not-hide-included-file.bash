#include "harness_start.bash"

# pperlc reads its "#ifdef"s the way pbashc does: against the "-D"s
# it was given, with a "#define" line no more than a Perl comment.  So
# the "#ifndef QUIET" here is taken and extra.pl is pasted in, while
# the dependency scan took the "#define" for real, skipped the branch
# and left extra.pl off the prerequisites.  An edit to extra.pl then
# never reached bin/app.

mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES   += perl

BINARIES    += app
SOURCES     += app.pl
EOF

cat >src/app.pl <<'EOF'
#!/usr/bin/perl
#define QUIET
#ifndef QUIET
#include "extra.pl"
#endif
print "main\n";
EOF
echo 'print "extra-one\n";' > src/extra.pl

$PTEST_BINARY $PCONFIGURE_ARGS
cat Makefile
make $MAKE_ARGS
./bin/app | grep -qx extra-one

sleep 1
echo 'print "extra-two\n";' > src/extra.pl
make $MAKE_ARGS
./bin/app
./bin/app | grep -qx extra-two
