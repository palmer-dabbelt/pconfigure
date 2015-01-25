set -ex

out="$($PTEST_BINARY "$INPUT" "$DELIMS")"

echo "$out"
echo "$GOLD"

if [[ "$out" != "$GOLD" ]]
then
    exit 1
fi

exit 0
