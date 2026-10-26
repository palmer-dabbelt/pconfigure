#include "harness_start.bash"

# The other side of refusing a '--configure-arg' whose quoting the
# shell can't read: quoting it can read has to keep working, since
# being able to write it is the reason the option is raw.  These are
# the shapes a reader that only counted quote characters would get
# wrong -- a quote escaped outside quotes, a double quote escaped
# inside them, a single quote inside double quotes, and a backslash
# inside single quotes, where it escapes nothing at all.
mkdir -p sub
echo 'project(sub NONE)' > sub/CMakeLists.txt

cat >Configfile <<'EOF2'
BUILD_SYSTEMS += cmake
SUBPROJECTS   += sub
CONFIGUREOPTS += --configure-arg -DA=it\'s
CONFIGUREOPTS += --configure-arg "-DB=say \"hi\""
CONFIGUREOPTS += --configure-arg "-DC=it's"
CONFIGUREOPTS += --configure-arg '-DD=C:\'
EOF2

$PTEST_BINARY $PCONFIGURE_ARGS

grep -qF -- "-DA=it\\'s" Makefile
grep -qF -- '"-DB=say \"hi\""' Makefile
grep -qF -- "\"-DC=it's\"" Makefile
grep -qF -- "'-DD=C:\\'" Makefile

exit 0
