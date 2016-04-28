input=""
output=""

while [[ "$1" != "" ]]
do
    case "$1" in
    "-i") input="$2";;
    "-o") output="$2";;
    *) exit 1;;
    esac

    shift
    shift
done

cp "$input" "$output"
