#include "harness_start.bash"

# Two BINARIES that come out in one place but are built from different
# sources are two different rules for one file, which pconfigure cannot
# write.  Without STRICT that is only a warning by the time the targets
# are checked, so the run goes on to the rules themselves and stops
# there -- and it used to stop with exit status 134 and nothing else,
# since the one sentence it had to say went to stdout just before an
# abort() that never flushed it.  Whatever ends the run, it has to say
# why, and on the stream an error is looked for on.

mkdir -p src

cat >Configfile <<EOF
LANGUAGES += c

BINARIES  += hello
SOURCES   += a.c

BINARIES  += hello
SOURCES   += b.c
EOF

echo 'int main(void) { return 0; }' > src/a.c
echo 'int main(void) { return 1; }' > src/b.c

if $PTEST_BINARY $PCONFIGURE_ARGS >configure.stdout 2>configure.stderr
then
    cat configure.stdout configure.stderr
    exit 1
fi
cat configure.stdout configure.stderr

grep -qF "Mismatched recipe for targets with same name" configure.stderr
grep -qF "Configfile:6 'BINARIES += hello'" configure.stderr

exit 0
