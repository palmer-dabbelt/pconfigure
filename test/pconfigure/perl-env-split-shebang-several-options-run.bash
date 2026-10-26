#include "harness_start.bash"

# The Perl side of "#!/usr/bin/env -S perl -w -l": env splits the
# options and perl gets "-w" and "-l" as two.  On pperlc's own
# "#!/usr/bin/perl -w -l" line the kernel passes them to perl as one
# argument, "-w -l", which works only because perl reads the switches
# on its "#!" line again for itself.  Both have to survive: "-l" is
# what puts a newline after each print.
mkdir -p src

cat >Configfile <<'EOF'
LANGUAGES += perl

BINARIES  += tool
SOURCES   += tool.pl
EOF

cat >src/tool.pl <<'EOF'
#!/usr/bin/env -S perl -w -l
print "one";
print "two";
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
make $MAKE_ARGS
test "$(./bin/tool)" = "one
two"
