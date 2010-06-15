input_paths = Array.new
output_path = nil

index = 0
while (index < ARGV.size)
	if (ARGV[index] == "-o")
		index = index + 1
		output_path = ARGV[index]
	else
		input_paths.push(ARGV[index])
	end
	
	index = index + 1
end

output = File.new(output_path, "w")
output.puts("#!/bin/bash")

input_paths.each{|input_path|
	if (input_path != nil)
		input = File.new(input_path, "r")
		
		output.puts("# pbashc: #{input_path}")
		while (read = input.gets)
			output.puts(read)
		end
		
		input.close
	end
}

output.close

`chmod +x #{output_path}`
