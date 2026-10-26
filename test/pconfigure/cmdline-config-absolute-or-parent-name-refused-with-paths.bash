#include "harness_start.bash"

# --config takes a suffix, not a path: "--config /etc/x" is looked for
# as Configfiles//etc/x and Configfile./etc/x, and "--config ../x" as
# Configfiles/../x and Configfile.../x.  Both spellings name a file that
# really exists here, relative to where pconfigure runs, so a refusal
# shows the argument was read as a suffix rather than opened as a path.
# The refusal names both paths it looked at, so somebody who passed a
# path can see what happened, and nothing is written.
mkdir elsewhere
echo 'LANGUAGES += c' > elsewhere/conf
mkdir top
echo 'LANGUAGES += c' > top/Configfile

status=0
$PTEST_BINARY --config "$PWD/elsewhere/conf" > out 2>&1 || status=$?
cat out
test "$status" -eq 134
grep -qF "args:1 '--config $PWD/elsewhere/conf'" out
grep -qF "Configfiles/$PWD/elsewhere/conf" out
grep -qF "Configfile.$PWD/elsewhere/conf" out
test ! -e Makefile

# The parent-relative name is run from top/, where ../elsewhere/conf is
# the file above.  A Configfiles/ directory is there too, so that the
# kernel could resolve Configfiles/../elsewhere/conf if pconfigure ever
# normalised it: it resolves to top/elsewhere/conf, which doesn't exist,
# and the refusal must still name the suffix as written.
mkdir top/Configfiles
status=0
(cd top && $PTEST_BINARY --config ../elsewhere/conf) > out 2>&1 || status=$?
cat out
test "$status" -eq 134
grep -qF "args:1 '--config ../elsewhere/conf'" out
grep -qF "Configfiles/../elsewhere/conf" out
grep -qF "Configfile.../elsewhere/conf" out
test "$(ls top)" = "$(printf 'Configfile\nConfigfiles')"
test -z "$(ls top/Configfiles)"
