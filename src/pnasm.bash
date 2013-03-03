input=""
output=""
args=""

while [[ "$1" != "" ]]
do
    if [[ "$1" == "-c" ]]
    then
	input="$2"
	shift
	shift
    elif [[ "$1" == "-o" ]]
    then
	output="$2"
	shift
	shift
    else
	args="$args $1"
	shift
    fi
done

nasm $args "$input" -o "$output"
