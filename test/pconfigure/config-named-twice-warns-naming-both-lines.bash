#include "harness_start.bash"

# Naming the same CONFIG twice reads the file twice, so every target in
# it is declared twice.  The only thing that used to be said about it
# was that "Configfiles/extra:1" had already been asked for on
# "Configfiles/extra:1" -- a line duplicating itself -- which never
# mentioned the second CONFIG line, the only thing that needs changing.
#
# The file is still read the second time: a CONFIG is the manual's
# #include, and one holding nothing but options can be meant to land
# under two different targets.  What changes is that the repeat is said
# about, at the CONFIG line that repeated it and naming the one before.
mkdir -p src Configfiles
echo 'int main(void) { return 0; }' > src/main.c

cat >Configfiles/extra <<'EOF2'
BINARIES    += main
SOURCES     += main.c
EOF2

cat >Configfile <<'EOF2'
LANGUAGES   += c
CONFIG      += extra
CONFIG      += extra
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS >out 2>&1
cat out
grep -q "Configfile:3 'CONFIG += extra'" out
grep -q "warning: .*Configfiles/extra.* was already read" out
grep -q "Configfile:2 'CONFIG += extra'" out
make $MAKE_ARGS
./bin/main

# A CONFIG naming one of the Configfiles every project reads anyway is
# the same repeat, with no earlier CONFIG to name.
cat >Configfile <<'EOF2'
LANGUAGES   += c
BINARIES    += main
SOURCES     += main.c
EOF2
cat >Configfile.local <<'EOF2'
LANGUAGES   += c
EOF2
cat >Configfiles/main <<'EOF2'
CONFIG      += local
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS >out 2>&1
cat out
grep -q "Configfiles/main:1 'CONFIG += local'" out
grep -q "warning: .*Configfile.local.* was already read" out

# A CONFIG of one of those files that comes before its turn -- from
# Configfile.local, which is read before Configfiles/main -- reads it
# early, and then it is read again in its own place.  The CONFIG is the
# line to blame, and the CONFIG inside main is not: it used to be the
# only line named, as a repeat of itself.
cat >Configfiles/main <<'EOF2'
CONFIG      += extra
EOF2
cat >Configfiles/extra <<'EOF2'
LANGUAGES   += c
COMPILEOPTS += -DEXTRA
EOF2
cat >Configfile.local <<'EOF2'
LANGUAGES   += c
CONFIG      += main
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS >out 2>&1
cat out
grep -q "Configfile.local:2 'CONFIG += main'" out
grep -q "warning: .*Configfiles/main.* every project reads anyway" out
test "$(grep -c "warning:" out)" = 1

# A "--config" is read before any of them, so "--config main" is the
# same repeat, said about at the option.
rm -f Configfile.local
$PTEST_BINARY $PCONFIGURE_ARGS --config main >out 2>&1
cat out
grep -q "args:1 '--config main'" out
grep -q "warning: .*Configfiles/main.* every project reads anyway" out
test "$(grep -c "warning:" out)" = 1
