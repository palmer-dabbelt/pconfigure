if [[ "$1" == "" || "$2" == "" ]]
then
    cat <<EOF
pgcc-config <program> <version> [test] [flag]

  If [test] and [flag] are passed, then flag is returned IFF the test
    passes on `program -dumpversion`.
  Otherwise, a patch version is found that matches the supplied
    version.
EOF
    exit 1
fi

program="$1"
version="$2"
test="$3"
flag="$4"

if [[ "$test" != "" && "$flag" != "" ]]
then
    dumpversion="$($program -dumpversion)"
    match="false"

    case "$test"
    in
        "gt")
            first="$(echo -e "$dumpversion\n$version" | sort -V | head -n1)"
            if [[ "$first" == "$version" ]]
            then
                echo "$flag"
            fi
            exit 0
        ;;

        "lt")
            first="$(echo -e "$dumpversion\n$version" | sort -V | tail -n1)"
            if [[ "$first" == "$version" ]]
            then
                echo "$flag"
            fi
            exit 0
        ;;
    esac

    echo "Unsupported test $test" >&2
    exit 1
fi

for x in $(seq 9 -1 0)
do
    if [[ "$(which "$program"-"$version"."$x" 2>/dev/null)" != "" ]]
    then
	echo "$program"-"$version"."$x"
	exit 0
    fi
done

echo "\${CC}"
exit 1
