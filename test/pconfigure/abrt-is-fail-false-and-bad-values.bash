#include "harness_start.bash"

# ABRT_IS_FAIL takes "true" or "false" and nothing else.  Saying
# "false" is the same as not saying anything: no flag on the report
# recipes, and an abort stays an EROR.  Anything else is refused at
# the line that said it, since "yes" or "1" read as a boolean by one
# person and as nonsense by the parser is a project whose crashes get
# scored some third way nobody chose.

mkdir -p src test/t

cat >Configfile <<'EOF'
ABRT_IS_FAIL = false

LANGUAGES += bash

BINARIES += t
SOURCES  += t.bash
TESTSRC  += aborts.bash
EOF

cat >src/t.bash <<'EOF'
echo "Success"
EOF

cat >test/t/aborts.bash <<'EOF'
kill -ABRT $$
EOF

$PTEST_BINARY $PCONFIGURE_ARGS
if grep -q -- "--abrt-is-fail" Makefile
then
    exit 1
fi
printf 'check\n' > expected
diff expected obj/check-dirs

make $MAKE_ARGS
if make $MAKE_ARGS report > report.out 2>&1
then
    exit 1
fi
cat report.out
grep -q "EROR	t/aborts.bash" report.out
grep -q "^NEROR	1$" report.out

for value in yes 1 TRUE
do
    sed -i "s/^ABRT_IS_FAIL = .*/ABRT_IS_FAIL = $value/" Configfile
    if $PTEST_BINARY $PCONFIGURE_ARGS > bad.out 2>&1
    then
        exit 1
    fi
    cat bad.out
    grep -q "Configfile:1" bad.out
    grep -q "'$value' is not 'true' or 'false'" bad.out
done

exit 0
