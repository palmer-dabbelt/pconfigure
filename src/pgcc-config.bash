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
    dumpversion="$($program -dumpversion | cut -d'.' -f1-2)"
    match="false"

    if [[ "$(echo "$dumpversion" | cut -d '.' -f 1)" != "4" ]]
    then
        echo "OSX doesn't have sort -V, so we only support gcc-4"
        exit 1
    fi

    case "$test"
    in
        "gt")
            first="$(echo -e "$dumpversion\n$version" | sort -k2 -t. -g | head -n1)"
            if [[ "$first" == "$version" ]]
            then
                echo "$flag"
            fi
            exit 0
        ;;

        "lt")
            first="$(echo -e "$dumpversion\n$version" | sort -k2 -t. -g | tail -n1)"
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
